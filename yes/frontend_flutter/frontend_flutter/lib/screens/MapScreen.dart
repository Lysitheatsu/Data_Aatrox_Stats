import 'dart:math' as math;
import 'package:flutter/material.dart' hide Card, Icon, SearchBar;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter/physics.dart';
import 'package:share_plus/share_plus.dart';
import '../components/index.dart';
import '../theme/index.dart';
import '../theme/ThemeProvider.dart';
import '../map/types.dart';
import '../map/EllyMap.dart'
  if (dart.library.html) '../map/EllyMap.web.dart';
import '../api/client.dart';
import '../theme/icons.dart';
import '../hooks/useCurrentLocation.dart';
import '../hooks/useLiveLocation.dart';
import '../lib/navigation.dart';
import '../data/AppDataProvider.dart';
import '../lib/nearbyCategories.dart';

/**
 * Module 1 — Maps Intelligence (Home).
 *
 * Layout: a full-screen map fills the background. The header + search bar
 * float at the top, map controls / weather tile / SOS float over the map, and
 * the contextual tiles are grouped in a bottom sheet.
 *
 * Searching for a place and getting a route both go through the /maps
 * endpoints on our backend.
 */

class MapScreen extends HookWidget {
  final ValueChanged<String>? onNavigateTab;
  final GeoLocation? focusLocation;

  const MapScreen({super.key, this.onNavigateTab, this.focusLocation});

  @override
  Widget build(BuildContext context) {
    final mapTheme = useMapTheme(context);
    final colors = mapTheme.colors;
    final styles = mapTheme.styles;
    final data = useAppData(context);
    final navigationRoute = ModalRoute.of(context);

    void navigateTab(String route) {
      if (onNavigateTab != null) {
        onNavigateTab!(route);
        return;
      }
      Navigator.of(context).pushNamed(route);
    }

    final selectedPerson = useState<LiveLocation?>(null);
    final personSheetProgress = useAnimationController(
      duration: const Duration(milliseconds: 220),
      initialValue: 1,
    );
    final liveFocus = useState<GeoLocation?>(null);
    final liveLocations = useMemoized(() => data.connections.expand<LiveLocation>((person) =>
      person.status == 'connected' && person.isLive && person.location != null
        ? [LiveLocation(id: person.id, name: person.name, location: person.location!, lastUpdated: person.lastUpdated)]
        : []).toList(), [data.connections]);
    final windowHeight = MediaQuery.sizeOf(context).height;
    // where you are, or Melbourne CBD if you said no
    final current = useCurrentLocation();
    final currentLocation = current.location;
    final locationStatus = current.status;
    final query = useState('');
    final results = useState<List<GeoLocation>>([]);
    final destinationPersonId = useState<String?>(null);
    final destination = useState<GeoLocation?>(null);
    final routes = useState<List<RouteOption>>([]);
    final chosenRoute = useState(0);
    final mode = useState<TravelMode>('driving');
    final routeOrigin = useState<GeoLocation>(currentLocation);
    final showDirections = useState(false);
    // which step you're on while navigating, null means not navigating
    final navStep = useState<int?>(null);
    final isNavigating = navStep.value != null;
    // only watch the GPS while actually navigating, it eats battery
    final livePosition = useLiveLocation(isNavigating);
    // true once you've wandered off the route
    final offRoute = useState(false);
    // true while you're clicking through turns yourself. stops the camera
    // snapping back to your dot, which is what happens on a laptop where the
    // location never changes.
    final previewing = useState(false);
    // where we last took a bearing from, and the bearing itself
    final bearingAnchorRef = useRef<GeoLocation?>(null);
    final travelBearing = useState<double?>(null);
    final lastPositionRef = useRef<GeoLocation?>(null);

    LiveLocation? navigationContact;
    if (destinationPersonId.value != null) {
      for (final person in liveLocations) {
        if (person.id == destinationPersonId.value) {
          navigationContact = person;
          break;
        }
      }
    } else if (isNavigating && destination.value != null) {
      for (final person in liveLocations) {
        if (sameLocation(person.location, destination.value!)) {
          navigationContact = person;
          break;
        }
      }
    }

    final visibleLiveLocations = useMemoized(() {
      if (navigationContact != null) return [navigationContact!];
      return isNavigating || destinationPersonId.value != null ? <LiveLocation>[] : liveLocations;
    }, [navigationContact, isNavigating, destinationPersonId.value, liveLocations]);
    final route = chosenRoute.value < routes.value.length ? routes.value[chosenRoute.value] : null;
    final busy = useState(false);
    final error = useState<String?>(null);
    final weather = useState<({ String temp, String aqi })?>(null);
    // roughly what the petrol costs, once we know the distance
    final fuel = useState<FuelEstimate?>(null);
    // tolls, roadworks and charging stops on the route
    final roadAlerts = useState<({
      List<String> tolls,
      List<String> works,
      ChargingPlan? charging,
    })?>(null);
    final isSheetExpanded = useState(true);
    // bumped by the navigate button to pull the map back to where you are
    final recenterSignal = useState(0);
    final showMapLayers = useState(false);
    final mapType = useState<MapType>('default');
    final showEllySuggests = useState(false);
    // which category chip is on, and what it found nearby
    final nearbyCategory = useState<NearbyCategory?>(null);
    final nearbyPlaces = useState<List<NearbyPlace>>([]);
    final nearbyBusy = useState(false);
    final sheetProgress = useAnimationController(
      duration: const Duration(milliseconds: 220),
      initialValue: 1,
    );
    final dragStartProgress = useRef(1.0);
    const collapsedSheetHeight = 44.0;
    final expandedSheetHeight = math.max(collapsedSheetHeight, (windowHeight * 0.52).round()).toDouble();
    final sheetTravel = math.max(1.0, expandedSheetHeight - collapsedSheetHeight).toDouble();

    void animateSheet(bool expanded) {
      isSheetExpanded.value = expanded;
      sheetProgress.animateWith(SpringSimulation(
        const SpringDescription(
          damping: 22,
          stiffness: 220,
          mass: 0.8,
        ),
        sheetProgress.value,
        expanded ? 1 : 0,
        0,
      ));
    }

    void showPersonMessage(String message) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Live sharing'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }

    void selectLiveLocation(LiveLocation person) {
      personSheetProgress.stop();
      personSheetProgress.value = 1;
      selectedPerson.value = LiveLocation(
        id: person.id,
        name: person.name,
        location: person.location,
        lastUpdated: person.lastUpdated,
      );
      liveFocus.value = GeoLocation(
        label: person.location.label,
        address: person.location.address,
        latitude: person.location.latitude,
        longitude: person.location.longitude,
      );
      animateSheet(true);
    }

    useEffect(() {
      if (selectedPerson.value == null) return null;
      personSheetProgress.animateWith(SpringSimulation(
        const SpringDescription(
          damping: 24,
          stiffness: 220,
          mass: 0.85,
        ),
        personSheetProgress.value,
        0,
        0,
      ));
      return null;
    }, [personSheetProgress, selectedPerson.value]);

    void dismissLivePerson() {
      personSheetProgress.animateTo(
        1,
        duration: const Duration(milliseconds: 220),
        curve: Curves.linear,
      ).whenCompleteOrCancel(() => selectedPerson.value = null);
    }

    final personSheetDrag = useRef(0.0);

    void personSheetPanUpdate(DragUpdateDetails gesture) {
      if (gesture.delta.dy > 0) personSheetDrag.value += gesture.delta.dy;
    }

    void personSheetPanEnd(DragEndDetails gesture) {
      if (personSheetDrag.value > 40) dismissLivePerson();
      personSheetDrag.value = 0;
    }

    final sheetDragStart = useRef(0.0);
    final sheetDragDy = useRef(0.0);

    void sheetPanStart(DragStartDetails gesture) {
      sheetProgress.stop();
      dragStartProgress.value = sheetProgress.value;
      sheetDragStart.value = gesture.globalPosition.dy;
      sheetDragDy.value = 0;
    }

    void sheetPanUpdate(DragUpdateDetails gesture) {
      sheetDragDy.value = gesture.globalPosition.dy - sheetDragStart.value;
      final nextProgress = math.max(
        0,
        math.min(1, dragStartProgress.value - sheetDragDy.value / sheetTravel),
      ).toDouble();
      sheetProgress.value = nextProgress;
    }

    void sheetPanEnd(DragEndDetails gesture) {
      final velocity = gesture.primaryVelocity ?? 0;
      final hasClearFlick = velocity.abs() >= 150;
      final hasClearPull = sheetDragDy.value.abs() >= 12;
      final shouldExpand = hasClearFlick
        ? velocity < 0
        : hasClearPull
          ? sheetDragDy.value < 0
          : dragStartProgress.value >= 0.5;
      animateSheet(shouldExpand);
    }

    void sheetPanTerminate() {
      animateSheet(sheetProgress.value >= 0.5);
    }

    // search for whatever's been typed in
    Future<void> runSearch() async {
      if (query.value.trim().isEmpty) return;
      busy.value = true;
      error.value = null;
      routes.value = [];
      destination.value = null;
      destinationPersonId.value = null;
      showDirections.value = false;
      navStep.value = null;
      try {
        final found = await api.searchPlaces(query.value, 5, currentLocation.latitude, currentLocation.longitude);
        results.value = found;
        if (found.isEmpty) error.value = 'No places found for that.';
      } catch (_) {
        error.value = "Couldn't reach the map service.";
      } finally {
        busy.value = false;
      }
    }

    // work out how to get there
    // tap a chip to find those places around you, tap it again to clear
    Future<void> chooseCategory(NearbyCategory key) async {
      if (nearbyCategory.value == key) {
        nearbyCategory.value = null;
        nearbyPlaces.value = [];
        return;
      }
      nearbyCategory.value = key;
      nearbyBusy.value = true;
      nearbyPlaces.value = [];
      try {
        nearbyPlaces.value = await api.nearby(
          key,
          currentLocation.latitude,
          currentLocation.longitude,
          2000,
        );
      } catch (_) {
        nearbyPlaces.value = [];
      } finally {
        nearbyBusy.value = false;
      }
    }

    Future<void> planTo(GeoLocation place, TravelMode travelMode, [GeoLocation? origin]) async {
      final routeOriginValue = origin ?? currentLocation;
      busy.value = true;
      error.value = null;
      routeOrigin.value = routeOriginValue;
      try {
        final planned = await api.planRoutes(routeOriginValue, place, travelMode);
        routes.value = planned.options;
        chosenRoute.value = 0;
        if (planned.options.isEmpty) {
          error.value = 'No route to that place.';
        }
        // the sheet used to collapse here so you could see the route, but the
        // search bar lives in the sheet now, so closing it hides everything
      } catch (reason) {
        if (reason is ApiError && reason.status == 422) {
          error.value = 'No $travelMode route connects these locations.';
        } else if (reason is ApiError) {
          error.value = 'Route service error (${reason.status}).';
        } else {
          error.value = "Couldn't reach the route service.";
        }
      } finally {
        busy.value = false;
      }
    }

    // show a health service from the Emergency screen on the map
    final navigationArguments = navigationRoute?.settings.arguments;
    final routeFocusLocation = navigationArguments is Map<String, dynamic>
      ? navigationArguments['focusLocation'] as GeoLocation?
      : null;
    final focusLocation = this.focusLocation ?? routeFocusLocation;

    useEffect(() {
      if (focusLocation == null) return null;
      destination.value = focusLocation;
      destinationPersonId.value = null;
      results.value = [];
      query.value = focusLocation.label ?? '';
      routes.value = [];
      chosenRoute.value = 0;
      showDirections.value = false;
      navStep.value = null;
      liveFocus.value = null;
      error.value = null;
      planTo(focusLocation, mode.value, currentLocation);
      return null;
    }, [focusLocation]);

    // pick one of the search results
    Future<void> chooseDestination(GeoLocation place, [String? personId]) async {
      destinationPersonId.value = personId;
      destination.value = place;
      results.value = [];
      query.value = place.label ?? '';
      showDirections.value = false;
      navStep.value = null;
      await planTo(place, mode.value, currentLocation);
    }

    // the x on the route panel: forget the whole search
    void clearSearch() {
      query.value = '';
      results.value = [];
      destination.value = null;
      destinationPersonId.value = null;
      routes.value = [];
      chosenRoute.value = 0;
      showDirections.value = false;
      navStep.value = null;
      error.value = null;
      // planning a route collapsed the sheet, put it back
      animateSheet(true);
    }

    // plan again from where you are now, for when you've gone off route
    // pressing Back/Next moves the card and flies the map to that turn
    void previewStep(int index) {
      previewing.value = true;
      navStep.value = index;
    }

    Future<void> rerouteFromHere() async {
      if (destination.value == null) return;
      final from = livePosition?.location ?? currentLocation;
      offRoute.value = false;
      navStep.value = 0;
      await planTo(destination.value!, mode.value, from);
    }

    // switching mode re-plans the same trip
    Future<void> changeMode(TravelMode next) async {
      mode.value = next;
      showDirections.value = false;
      navStep.value = null;
      if (destination.value != null) await planTo(destination.value!, next, routeOrigin.value);
    }

    // real weather instead of the hardcoded 28 degrees
    useEffect(() {
      Future<void> loadJourneyInfo() async {
        final target = destination.value ?? currentLocation;
        try {
          final info = await api.journeyInfo(currentLocation, target, route?.distance_km, route?.geometry);
          // weather_summary looks like "Clear, 8°C", we just want the number
          final temp = info.weather_summary.split(',').last.trim();
          weather.value = (
            temp: temp,
            aqi: info.air_quality_index == null ? '—' : info.air_quality_index.toString(),
          );
          fuel.value = info.fuel;
          roadAlerts.value = (
            tolls: info.toll_roads,
            works: info.construction,
            charging: info.charging,
          );
        } catch (_) {
          weather.value = null;
        }
      }
      loadJourneyInfo();
      // runs again when the real location turns up
      // needs the distance too, it arrives after the route is planned
      return null;
    }, [destination.value, currentLocation, route?.distance_km]);

    // move to the next turn once you've reached this one, and notice if you've
    // gone the wrong way
    useEffect(() {
      if (livePosition == null || navStep.value == null || route == null) return null;
      final here = livePosition.location;

      // if you've actually moved, you're driving, so stop previewing and let the
      // camera follow you again
      final previous = lastPositionRef.value;
      if (previous != null && distanceM(previous.latitude, previous.longitude, here.latitude, here.longitude) > 10) {
        previewing.value = false;
      }

      // check the turn we're heading towards, not the one we're standing on.
      // step 0 is "start here" so you're always at it, which would skip it.
      final nextIndex = navStep.value! + 1;
      final nextStep = nextIndex < route.steps.length ? route.steps[nextIndex] : null;
      if (nextStep != null && hasReachedStep(here, nextStep)) {
        navStep.value = nextIndex;
      }

      offRoute.value = isOffRoute(here, route.geometry);
      lastPositionRef.value = here;
      return null;
    }, [livePosition, navStep.value, route]);

    // work out which way you're facing from how you've moved.
    //
    // we don't compare to the last reading, walking only moves you a metre or so
    // between them and the gps noise is bigger than that. instead we keep an
    // anchor and only take a new bearing once you're properly away from it.
    useEffect(() {
      if (livePosition == null) {
        // navigation stopped, start fresh next time
        bearingAnchorRef.value = null;
        travelBearing.value = null;
        return null;
      }
      final here = livePosition.location;
      final anchor = bearingAnchorRef.value;
      if (anchor == null) {
        bearingAnchorRef.value = here;
        return null;
      }
      final moved = distanceM(anchor.latitude, anchor.longitude, here.latitude, here.longitude);
      if (moved >= BEARING_MIN_MOVE_M) {
        travelBearing.value = bearingBetween(anchor, here);
        bearingAnchorRef.value = here;
      }
      return null;
    }, [livePosition]);

    // the line ahead of you. shrinks as you travel so you only see what's left.
    final drawnRoute = useMemoized(() {
      if (route == null) return null;
      if (livePosition == null || navStep.value == null) return route.geometry;
      return remainingRoute(route.geometry, livePosition.location);
    }, [route, livePosition, navStep.value]);

    // which way to point the map and the arrow
    final followBearing = useMemoized(() {
      if (livePosition == null) return null;
      // how you've moved beats the phone's compass. browsers hand back 0 rather
      // than null when they don't know, which points you north by mistake.
      if (travelBearing.value != null) return travelBearing.value;
      final fromPhone = livePosition.heading;
      return fromPhone != null && fromPhone.isFinite ? fromPhone : null;
    }, [livePosition, travelBearing.value]);

    // everything the turn card needs. navStep is the turn you last passed, so
    // the one you're actually driving towards is the one after it.
    final guidance = useMemoized(() {
      if (navStep.value == null || route == null) return null;

      final last = route.steps.length - 1;
      final aheadIndex = math.min(navStep.value! + 1, last);
      if (aheadIndex < 0 || aheadIndex >= route.steps.length) return null;
      final ahead = route.steps[aheadIndex];

      // live distance if we know where you are, otherwise fall back to how long
      // the step is so it still shows something sensible on a desktop
      final live = livePosition != null ? distanceToStep(livePosition.location, ahead) : null;
      final metresToTurn = live ?? ahead.distance_m;

      final left = remainingDistanceM(route.steps, aheadIndex);
      final total = remainingDistanceM(route.steps, 0);

      return Guidance(
        instruction: ahead.instruction,
        icon: turnIcon(ahead.instruction),
        metresToTurn: metresToTurn,
        // where the turn is, so the map can fly to it
        location: ahead.location,
        // where this turn sits in the list, for the preview buttons
        index: aheadIndex,
        count: route.steps.length,
        isLast: aheadIndex == last,
        // the turn after this one, shown small as a heads up
        then: aheadIndex + 1 < route.steps.length ? route.steps[aheadIndex + 1] : null,
        arrived: aheadIndex == last && metresToTurn <= ARRIVED_AT_TURN_M,
        remainingM: left,
        // scale the trip time by how much of it is left
        remainingMin: total > 0 ? (route.eta_minutes * left) / total : 0,
      );
    }, [navStep.value, route, livePosition]);

    return ColoredBox(
      color: styles.root.backgroundColor,
      child: Stack(
        children: [
          // Full-screen MapLibre map, themed from the app's design tokens.
          Positioned.fill(
            child: EllyMap(
              focus: destination.value,
              showFocusMarker: destinationPersonId.value == null && navigationContact == null,
              liveLocations: visibleLiveLocations,
              liveFocus: liveFocus.value,
              onSelectLiveLocation: selectLiveLocation,
              origin: livePosition?.location ?? currentLocation,
              heading: followBearing,
              routeGeometry: drawnRoute,
              followStep: guidance?.location,
              liveFollow:
                livePosition != null && !previewing.value
                  ? LiveFollow(location: livePosition.location, bearing: followBearing)
                  : null,
              recenterSignal: recenterSignal.value,
              bottomInset: selectedPerson.value != null
                ? expandedSheetHeight
                : isSheetExpanded.value
                  ? expandedSheetHeight
                  : collapsedSheetHeight,
              mapType: mapType.value,
            ),
          ),

          // add ?debug=1 to the url to see what the phone's gps is actually
          // reporting. handy for working out why the arrow isn't showing.
          if (DEBUG_GPS)
            Positioned(
              top: styles.debugBox.top,
              left: styles.debugBox.left,
              child: IgnorePointer(
                child: Container(
                  padding: styles.debugBox.padding,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(styles.debugBox.borderRadius),
                    color: styles.debugBox.backgroundColor,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('navigating: $isNavigating', style: styles.debugText),
                      Text(
                        'fix: ${livePosition != null ? '${livePosition.location.latitude.toStringAsFixed(5)}, ${livePosition.location.longitude.toStringAsFixed(5)}' : 'none'}',
                        style: styles.debugText,
                      ),
                      Text('phone heading: ${livePosition?.heading}', style: styles.debugText),
                      Text('phone speed: ${livePosition?.speed}', style: styles.debugText),
                      Text('travel bearing: ${travelBearing.value}', style: styles.debugText),
                      Text('arrow angle: $followBearing', style: styles.debugText),
                      Text('arrow shows: ${followBearing != null}', style: styles.debugText),
                    ],
                  ),
                ),
              ),
            ),

          Positioned.fill(
            child: SafeArea(
              left: false,
              right: false,
              bottom: false,
              child: Column(
                children: [
                  // Header remains clear while search lives in the lower journey sheet.
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: styles.top.paddingHorizontal),
                    child: const Header(logo: true, showMenu: true, showBell: true, bellDot: true, showAvatar: true),
                  ),

                  // Middle: floating controls over the live map
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned(
                          right: styles.controls.right,
                          top: styles.controls.top,
                          child: Column(
                            spacing: styles.controls.gap,
                            children: [
                              MapControl(
                                icon: 'layers',
                                label: 'Map layers',
                                onPress: () => showMapLayers.value = !showMapLayers.value,
                              ),
                              // One control for "where am I", rather than a crosshair and an
                              // arrow that would both mean the same thing.
                              MapControl(
                                icon: 'tabMap',
                                label: 'Navigate back to your location',
                                onPress: () => recenterSignal.value += 1,
                              ),
                            ],
                          ),
                        ),

                        if (showMapLayers.value)
                          Positioned(
                            right: styles.layersMenu.right,
                            top: styles.layersMenu.top,
                            child: Container(
                              width: styles.layersMenu.width,
                              padding: styles.layersMenu.padding,
                              decoration: BoxDecoration(
                                color: styles.layersMenu.backgroundColor,
                                borderRadius: BorderRadius.circular(styles.layersMenu.borderRadius),
                                border: Border.all(width: 1, color: styles.layersMenu.borderColor),
                                boxShadow: styles.layersMenu.boxShadow,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.only(bottom: styles.layersTitle.marginBottom),
                                    child: Text('Map type', style: styles.layersTitle.textStyle),
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            mapType.value = 'default';
                                            showMapLayers.value = false;
                                          },
                                          child: Column(
                                            spacing: styles.layerItem.gap,
                                            children: [
                                              Container(
                                                height: styles.layerPreview.height,
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(styles.layerPreview.borderRadius),
                                                  border: Border.all(
                                                    width: mapType.value == 'default' ? styles.layerPreviewSelected.borderWidth : 1,
                                                    color: mapType.value == 'default' ? styles.layerPreviewSelected.borderColor : styles.layerPreview.borderColor,
                                                  ),
                                                  color: styles.layerPreview.backgroundColor,
                                                ),
                                                alignment: Alignment.center,
                                                child: Icon(name: 'tabMap', size: 24, color: colors.primary),
                                              ),
                                              Text(
                                                'Default',
                                                textAlign: TextAlign.center,
                                                style: mapType.value == 'default'
                                                  ? styles.layerLabel.copyWith(
                                                      color: styles.layerLabelSelected.color,
                                                      fontWeight: styles.layerLabelSelected.fontWeight,
                                                    )
                                                  : styles.layerLabel,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: styles.layersRow.gap),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            mapType.value = 'satellite';
                                            showMapLayers.value = false;
                                          },
                                          child: Column(
                                            spacing: styles.layerItem.gap,
                                            children: [
                                              Container(
                                                height: styles.layerPreview.height,
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(styles.layerPreview.borderRadius),
                                                  border: Border.all(
                                                    width: mapType.value == 'satellite' ? styles.layerPreviewSelected.borderWidth : 1,
                                                    color: mapType.value == 'satellite' ? styles.layerPreviewSelected.borderColor : styles.layerPreview.borderColor,
                                                  ),
                                                  color: styles.layerPreview.backgroundColor,
                                                ),
                                                alignment: Alignment.center,
                                                child: Icon(name: 'layers', size: 24, color: colors.text),
                                              ),
                                              Text(
                                                'Satellite',
                                                textAlign: TextAlign.center,
                                                style: mapType.value == 'satellite'
                                                  ? styles.layerLabel.copyWith(
                                                      color: styles.layerLabelSelected.color,
                                                      fontWeight: styles.layerLabelSelected.fontWeight,
                                                    )
                                                  : styles.layerLabel,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                        Positioned(
                          right: styles.ellySuggestButton.right,
                          top: styles.ellySuggestButton.top,
                          child: Semantics(
                            button: true,
                            label: 'ELLY Suggests',
                            child: GestureDetector(
                              onTap: () => showEllySuggests.value = !showEllySuggests.value,
                              child: Container(
                                width: styles.ellySuggestButton.width,
                                height: styles.ellySuggestButton.height,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(styles.ellySuggestButton.borderRadius),
                                  color: styles.ellySuggestButton.backgroundColor,
                                  boxShadow: styles.ellySuggestButton.boxShadow,
                                ),
                                alignment: Alignment.center,
                                child: Icon(name: 'elly', size: 20, color: colors.elly),
                              ),
                            ),
                          ),
                        ),

                        if (showEllySuggests.value)
                          Positioned(
                            right: styles.ellySuggestPopup.right,
                            top: styles.ellySuggestPopup.top,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: math.min(
                                  styles.ellySuggestPopup.width,
                                  MediaQuery.sizeOf(context).width * styles.ellySuggestPopup.maxWidth,
                                ),
                              ),
                              child: Container(
                                padding: styles.ellySuggestPopup.padding,
                                decoration: BoxDecoration(
                                  color: styles.ellySuggestPopup.backgroundColor,
                                  borderRadius: BorderRadius.circular(styles.ellySuggestPopup.borderRadius),
                                  border: Border.all(width: 1, color: styles.ellySuggestPopup.borderColor),
                                  boxShadow: styles.ellySuggestPopup.boxShadow,
                                ),
                                child: EllySuggestsCard(),
                              ),
                            ),
                          ),

                        Positioned(
                          left: styles.weatherChip.left,
                          bottom: styles.weatherChip.bottom,
                          child: Container(
                            padding: styles.weatherChip.padding,
                            decoration: BoxDecoration(
                              color: styles.weatherChip.backgroundColor,
                              borderRadius: BorderRadius.circular(styles.weatherChip.borderRadius),
                              boxShadow: styles.weatherChip.boxShadow,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              spacing: styles.weatherChip.gap,
                              children: [
                                Icon(name: 'weather', size: 18, color: colors.warning),
                                Text(weather.value?.temp ?? '—', style: styles.weatherTemp),
                                Container(
                                  width: styles.aqiDot.width,
                                  height: styles.aqiDot.height,
                                  margin: EdgeInsets.symmetric(horizontal: styles.aqiDot.marginHorizontal),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: styles.aqiDot.backgroundColor,
                                  ),
                                ),
                                Text('AQI ${weather.value?.aqi ?? '—'}', style: styles.weatherAqi),
                              ],
                            ),
                          ),
                        ),

                        Positioned(
                          right: styles.sosWrap.right,
                          bottom: styles.sosWrap.bottom,
                          child: Semantics(
                            button: true,
                            label: 'Open SOS and emergency',
                            child: GestureDetector(
                              onTap: () => navigateTab('Emergency'),
                              child: SizedBox(
                                width: styles.sosWrap.width,
                                height: styles.sosWrap.height,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SosGlow(),
                                    Container(
                                      width: styles.sos.width,
                                      height: styles.sos.height,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: styles.sos.backgroundColor,
                                        boxShadow: styles.sos.boxShadow,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text('SOS', style: styles.sosText),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  AnimatedBuilder(
                    animation: sheetProgress,
                    builder: (context, child) {
                      final animatedSheetHeight =
                        collapsedSheetHeight + (expandedSheetHeight - collapsedSheetHeight) * sheetProgress.value;

                      return Container(
                        height: animatedSheetHeight,
                        decoration: BoxDecoration(
                          color: styles.sheet.backgroundColor,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(styles.sheet.borderTopLeftRadius),
                            topRight: Radius.circular(styles.sheet.borderTopRightRadius),
                          ),
                          boxShadow: styles.sheet.boxShadow,
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: Column(
                          children: [
                            GestureDetector(
                              onVerticalDragStart: sheetPanStart,
                              onVerticalDragUpdate: sheetPanUpdate,
                              onVerticalDragEnd: sheetPanEnd,
                              onVerticalDragCancel: sheetPanTerminate,
                              child: SizedBox(
                                height: styles.handleButton.height,
                                child: Semantics(
                                  button: true,
                                  label: isSheetExpanded.value ? 'Collapse journey panel' : 'Expand journey panel',
                                  hint: 'Tap, or drag vertically, to resize the panel',
                                  child: GestureDetector(
                                    onTap: () => animateSheet(!isSheetExpanded.value),
                                    child: Center(
                                      child: Container(
                                        width: styles.handle.width,
                                        height: styles.handle.height,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(styles.handle.borderRadius),
                                          color: styles.handle.backgroundColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                physics: isSheetExpanded.value
                                  ? null
                                  : const NeverScrollableScrollPhysics(),
                                padding: styles.sheetContent.padding,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  spacing: styles.sheetContent.gap,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      spacing: styles.searchDock.gap,
                                      children: [
                                        SearchBar(
                                          placeholder: 'Where do you want to go?',
                                          value: query.value,
                                          onChangeText: (value) {
                                            query.value = value;
                                            if (error.value != null) error.value = null;
                                          },
                                          onSubmit: runSearch,
                                        ),
                                        SearchResults(
                                          busy: busy.value, error: error.value, results: results.value, routes: routes.value, chosenRoute: chosenRoute.value,
                                          onChooseRoute: (index) => chosenRoute.value = index, mode: mode.value, onChangeMode: changeMode, destination: destination.value,
                                          onChoose: chooseDestination, locationStatus: locationStatus, navStep: navStep.value,
                                          guidance: guidance,
                                          offRoute: offRoute.value,
                                          onReroute: rerouteFromHere,
                                          onStartNavigation: () => navStep.value = 0, onStopNavigation: () => navStep.value = null, onStepChange: previewStep,
                                          showDirections: showDirections.value, onToggleDirections: () => showDirections.value = !showDirections.value, onClear: clearSearch,
                                          fuel: fuel.value,
                                          onSave: () {
                                            if (destination.value == null) return;
                                            data.toggleFavourite((
                                              label: destination.value!.label,
                                              latitude: destination.value!.latitude,
                                              longitude: destination.value!.longitude,
                                            ));
                                          },
                                          onShare: () {
                                            if (destination.value == null) return;
                                            final place = destination.value!;
                                            SharePlus.instance.share(ShareParams(
                                              text: 'Meet me at ${place.label ?? 'this location'}: https://www.openstreetmap.org/?mlat=${place.latitude}&mlon=${place.longitude}',
                                            ));
                                          },
                                        ),
                                      ],
                                    ),
                                    if (destination.value == null)
                                      CategoryChips(selected: nearbyCategory.value, busy: nearbyBusy.value, onChoose: chooseCategory),
                                    if (nearbyCategory.value != null && nearbyPlaces.value.isNotEmpty)
                                      NearbyCard(
                                        category: nearbyCategory.value!,
                                        places: nearbyPlaces.value,
                                        onChoose: (place) => chooseDestination(place.location),
                                      ),
                                    SavedPlacesCard(onChoose: chooseDestination),
                                    if (showDirections.value && route != null && route.steps.isNotEmpty)
                                      DirectionsCard(route: route),
                                    if (route != null && roadAlerts.value != null)
                                      RoadAlertsCard(alerts: roadAlerts.value!),
                                    UpcomingCard(onNavigate: chooseDestination),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          if (selectedPerson.value != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: expandedSheetHeight,
              child: AnimatedBuilder(
                animation: personSheetProgress,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, personSheetProgress.value * expandedSheetHeight),
                  child: GestureDetector(
                    onVerticalDragUpdate: personSheetPanUpdate,
                    onVerticalDragEnd: personSheetPanEnd,
                    child: Container(
                      padding: styles.personSheet.padding,
                      decoration: BoxDecoration(
                        color: styles.personSheet.backgroundColor,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(styles.personSheet.borderTopLeftRadius),
                          topRight: Radius.circular(styles.personSheet.borderTopRightRadius),
                        ),
                        boxShadow: styles.personSheet.boxShadow,
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            height: styles.personSheetHandle.height,
                            child: Center(
                              child: Container(
                                width: styles.handle.width,
                                height: styles.handle.height,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(styles.handle.borderRadius),
                                  color: styles.handle.backgroundColor,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.only(bottom: spacing.lg),
                              child: LivePersonMenu(
                                person: selectedPerson.value!,
                                onClose: dismissLivePerson,
                                onNavigate: () {
                                  final person = selectedPerson.value!;
                                  selectedPerson.value = null;
                                  liveFocus.value = null;
                                  chooseDestination(
                                    GeoLocation(
                                      label: person.name,
                                      address: person.location.address,
                                      latitude: person.location.latitude,
                                      longitude: person.location.longitude,
                                    ),
                                    person.id,
                                  );
                                },
                                onMessage: () => showPersonMessage(
                                  'Messaging ${selectedPerson.value!.name} will be available when your contacts are connected.',
                                ),
                                onSos: () {
                                  selectedPerson.value = null;
                                  navigateTab('Emergency');
                                },
                                onShareBack: () {
                                  selectedPerson.value = null;
                                  navigateTab('Connections');
                                },
                                onSafeArrival: () => showPersonMessage(
                                  'Safe-arrival alerts for ${selectedPerson.value!.name} are coming soon.',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// what we show vs what the api calls it
const Map<TravelMode, String> MODE_LABELS = {
  'driving': 'Drive',
  'walking': 'Walk',
  'cycling': 'Cycle',
};
final MODES = MODE_LABELS.keys.toList();

/** Shows the raw gps readings when the url has ?debug=1 on it. */
final DEBUG_GPS =
  Uri.base.queryParameters['debug'] == '1';

/** What the turn card shows. Worked out in MapScreen from the live position. */
class Guidance {
  final String instruction;
  final IconName icon;
  final double metresToTurn;
  final List<double>? location;
  final int index;
  final int count;
  final bool isLast;
  final RouteStep? then;
  final bool arrived;
  final double remainingM;
  final double remainingMin;

  const Guidance({
    required this.instruction,
    required this.icon,
    required this.metresToTurn,
    required this.location,
    required this.index,
    required this.count,
    required this.isLast,
    required this.then,
    required this.arrived,
    required this.remainingM,
    required this.remainingMin,
  });
}

/** Under the search bar: results first, then the route once you've picked one. */
Widget SearchResults({
  required bool busy,
  required String? error,
  required List<GeoLocation> results,
  required List<RouteOption> routes,
  required int chosenRoute,
  required ValueChanged<int> onChooseRoute,
  required TravelMode mode,
  required Future<void> Function(TravelMode) onChangeMode,
  required GeoLocation? destination,
  required Future<void> Function(GeoLocation, [String?]) onChoose,
  required LocationStatus locationStatus,
  required FuelEstimate? fuel,
  required int? navStep,
  required Guidance? guidance,
  required bool offRoute,
  required Future<void> Function() onReroute,
  required ValueChanged<int> onStepChange,
  required VoidCallback onStartNavigation,
  required VoidCallback onStopNavigation,
  required bool showDirections,
  required VoidCallback onToggleDirections,
  /** Drops the destination, the route and the typed query. */
  required VoidCallback onClear,
  required VoidCallback onSave,
  required VoidCallback onShare,
}) {
  return Builder(
    builder: (context) {
      final mapTheme = useMapTheme(context);
      final colors = mapTheme.colors;
      final styles = mapTheme.styles;

      if (busy) {
        return Container(
          margin: EdgeInsets.only(top: styles.dropdown.marginTop),
          padding: styles.dropdown.padding,
          decoration: BoxDecoration(
            color: styles.dropdown.backgroundColor,
            borderRadius: BorderRadius.circular(styles.dropdown.borderRadius),
            border: Border.all(width: 1, color: styles.dropdown.borderColor),
            boxShadow: styles.dropdown.boxShadow,
          ),
          child: Center(child: CircularProgressIndicator(color: colors.primary)),
        );
      }

      if (error != null) {
        return Container(
          margin: EdgeInsets.only(top: styles.dropdown.marginTop),
          padding: styles.dropdown.padding,
          decoration: BoxDecoration(
            color: styles.dropdown.backgroundColor,
            borderRadius: BorderRadius.circular(styles.dropdown.borderRadius),
            border: Border.all(width: 1, color: styles.dropdown.borderColor),
            boxShadow: styles.dropdown.boxShadow,
          ),
          child: Text(error, style: styles.dropdownError),
        );
      }

      if (results.isNotEmpty) {
        return Container(
          margin: EdgeInsets.only(top: styles.dropdown.marginTop),
          padding: styles.dropdown.padding,
          decoration: BoxDecoration(
            color: styles.dropdown.backgroundColor,
            borderRadius: BorderRadius.circular(styles.dropdown.borderRadius),
            border: Border.all(width: 1, color: styles.dropdown.borderColor),
            boxShadow: styles.dropdown.boxShadow,
          ),
          child: Column(
            spacing: styles.dropdown.gap,
            children: results.map((place) =>
              GestureDetector(
                onTap: () => onChoose(place),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: styles.resultRow.paddingVertical),
                  child: Row(
                    children: [
                      Icon(name: 'tabMap', size: 16, color: colors.textMuted),
                      SizedBox(width: styles.resultRow.gap),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(place.label ?? 'Unnamed place', style: styles.resultText, maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (place.address != null)
                              Padding(
                                padding: EdgeInsets.only(top: styles.resultAddress.marginTop),
                                child: Text(place.address!, style: styles.resultAddress.textStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ).toList(),
          ),
        );
      }

      final route = chosenRoute < routes.length ? routes[chosenRoute] : null;
      if (route == null || destination == null) return const SizedBox.shrink();

      // while navigating we show the next turn, like waze. no buttons to press,
      // it moves on by itself as you drive.
      if (navStep != null && guidance != null) {
        return Container(
          margin: EdgeInsets.only(top: styles.dropdown.marginTop),
          padding: styles.dropdown.padding,
          decoration: BoxDecoration(
            color: styles.dropdown.backgroundColor,
            borderRadius: BorderRadius.circular(styles.dropdown.borderRadius),
            border: Border.all(width: 1, color: styles.dropdown.borderColor),
            boxShadow: styles.dropdown.boxShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: styles.dropdown.gap,
            children: [
              Row(
                children: [
                  Container(
                    width: styles.turnArrow.width,
                    height: styles.turnArrow.height,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(styles.turnArrow.borderRadius),
                      color: styles.turnArrow.backgroundColor,
                    ),
                    alignment: Alignment.center,
                    child: Icon(name: guidance.icon, size: 30, color: colors.surface),
                  ),
                  SizedBox(width: styles.turnCard.gap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          guidance.arrived ? 'Arriving' : formatDistance(guidance.metresToTurn),
                          style: styles.turnDistance,
                        ),
                        Padding(
                          padding: EdgeInsets.only(top: styles.turnInstruction.marginTop),
                          child: Text(guidance.instruction, style: styles.turnInstruction.textStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (guidance.then != null)
                Container(
                  margin: EdgeInsets.only(top: styles.thenRow.marginTop),
                  padding: EdgeInsets.only(top: styles.thenRow.paddingTop),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(width: 1, color: styles.thenRow.borderTopColor)),
                  ),
                  child: Row(
                    children: [
                      Icon(name: turnIcon(guidance.then!.instruction), size: 14, color: colors.textMuted),
                      SizedBox(width: styles.thenRow.gap),
                      Expanded(
                        child: Text('then ${guidance.then!.instruction}', style: styles.thenText, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),

              if (offRoute)
                GestureDetector(
                  onTap: onReroute,
                  child: Container(
                    margin: EdgeInsets.only(top: styles.offRouteBanner.marginTop),
                    padding: styles.offRouteBanner.padding,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(styles.offRouteBanner.borderRadius),
                      color: styles.offRouteBanner.backgroundColor,
                    ),
                    child: Text("You've gone off the route. Tap to redo it from here.", style: styles.offRouteText),
                  ),
                ),

              // how much of the trip is left
              Padding(
                padding: EdgeInsets.only(top: styles.tripLeftRow.marginTop),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${formatDistance(guidance.remainingM)} · ${formatTravelDuration(guidance.remainingMin)} left',
                        style: styles.tripLeftText,
                      ),
                    ),
                    GestureDetector(
                      onTap: onStopNavigation,
                      child: Container(
                        padding: styles.endButton.padding,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(styles.endButton.borderRadius),
                          border: Border.all(width: 1, color: styles.endButton.borderColor),
                        ),
                        child: Text('End', style: styles.endButtonText),
                      ),
                    ),
                  ],
                ),
              ),

              // it moves on by itself while you're driving, but on a laptop nothing
              // moves, so these let you step through the turns to look ahead
              Container(
                margin: EdgeInsets.only(top: styles.previewRow.marginTop),
                padding: EdgeInsets.only(top: styles.previewRow.paddingTop),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(width: 1, color: styles.previewRow.borderTopColor)),
                ),
                child: Row(
                  children: [
                    Opacity(
                      opacity: navStep == 0 ? styles.previewButtonOff.opacity : 1,
                      child: GestureDetector(
                        onTap: navStep == 0 ? null : () => onStepChange(math.max(0, navStep - 1)),
                        child: Container(
                          padding: styles.previewButton.padding,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(styles.previewButton.borderRadius),
                            border: Border.all(width: 1, color: styles.previewButton.borderColor),
                          ),
                          child: Text('Back', style: styles.previewButtonText),
                        ),
                      ),
                    ),
                    SizedBox(width: styles.previewRow.gap),
                    // step 0 is just "start on X", not a turn, so don't count it
                    Expanded(
                      child: Text(
                        '${guidance.index} of ${guidance.count - 1}',
                        style: styles.previewCount,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(width: styles.previewRow.gap),
                    Opacity(
                      opacity: guidance.isLast ? styles.previewButtonOff.opacity : 1,
                      child: GestureDetector(
                        onTap: guidance.isLast ? null : () => onStepChange(guidance.index),
                        child: Container(
                          padding: styles.previewButton.padding,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(styles.previewButton.borderRadius),
                            border: Border.all(width: 1, color: styles.previewButton.borderColor),
                          ),
                          child: Text('Next', style: styles.previewButtonText),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      return Container(
        margin: EdgeInsets.only(top: styles.dropdown.marginTop),
        padding: styles.dropdown.padding,
        decoration: BoxDecoration(
          color: styles.dropdown.backgroundColor,
          borderRadius: BorderRadius.circular(styles.dropdown.borderRadius),
          border: Border.all(width: 1, color: styles.dropdown.borderColor),
          boxShadow: styles.dropdown.boxShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: styles.dropdown.gap,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(destination.label ?? '', style: styles.routeTo, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                SizedBox(width: styles.panelHeader.gap),
                CloseButton(onPress: onClear),
              ],
            ),

            // drive / walk / cycle
            Padding(
              padding: EdgeInsets.only(top: styles.modeRow.marginTop),
              child: SegmentedControl(
                segments: MODES.map((m) => MODE_LABELS[m]!).toList(),
                value: MODE_LABELS[mode]!,
                onChange: (label) {
                  TravelMode? picked;
                  for (final item in MODES) {
                    if (MODE_LABELS[item] == label) picked = item;
                  }
                  if (picked != null && picked != mode) onChangeMode(picked);
                },
              ),
            ),

            if (locationStatus == 'fallback')
              Padding(
                padding: EdgeInsets.only(top: styles.fromNote.marginTop),
                child: Text('From Melbourne CBD — location unavailable', style: styles.fromNote.textStyle),
              ),

            Padding(
              padding: EdgeInsets.only(top: styles.routeRow.marginTop),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: styles.routeRow.gap,
                children: [
                  Text(
                    '${route.eta_is_estimated ? 'about ' : ''}${formatTravelDuration(route.eta_minutes)}',
                    style: styles.routeEta,
                  ),
                  Text('${route.distance_km} km', style: styles.routeDistance),
                  // ~ because it's an estimate
                  if (fuel != null && mode == 'driving')
                    Text('~\$${fuel.cost.toStringAsFixed(2)} fuel', style: styles.routeFuel),
                ],
              ),
            ),

            // the other routes OSRM found, if there are any
            if (routes.length > 1)
              Padding(
                padding: EdgeInsets.only(top: styles.altRow.marginTop),
                child: Wrap(
                  spacing: styles.altRow.gap,
                  runSpacing: styles.altRow.gap,
                  children: routes.asMap().entries.map((entry) {
                    final index = entry.key;
                    final option = entry.value;
                    final on = index == chosenRoute;
                    return GestureDetector(
                      onTap: () => onChooseRoute(index),
                      child: Container(
                        padding: styles.altChip.padding,
                        decoration: BoxDecoration(
                          color: on ? styles.altChipOn.backgroundColor : null,
                          borderRadius: BorderRadius.circular(styles.altChip.borderRadius),
                          border: Border.all(
                            width: 1,
                            color: on ? styles.altChipOn.borderColor : styles.altChip.borderColor,
                          ),
                        ),
                        child: Text(
                          '${option.summary} · ${formatTravelDuration(option.eta_minutes)}',
                          style: on
                            ? styles.altText.copyWith(color: styles.altTextOn.color, fontWeight: styles.altTextOn.fontWeight)
                            : styles.altText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

            if (route.steps.isNotEmpty) ...[
              GestureDetector(
                onTap: onStartNavigation,
                child: Container(
                  margin: EdgeInsets.only(top: styles.startButton.marginTop),
                  padding: styles.startButton.padding,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(styles.startButton.borderRadius),
                    color: styles.startButton.backgroundColor,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(name: 'tabMap', size: 16, color: colors.onAccent),
                      SizedBox(width: styles.startButton.gap),
                      Text('Start navigation', style: styles.startButtonText),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: onToggleDirections,
                child: Padding(
                  padding: EdgeInsets.only(top: styles.directionsToggle.marginTop),
                  child: Text(
                    showDirections ? 'Hide directions' : 'Show all ${route.steps.length} steps',
                    style: styles.directionsToggleText,
                  ),
                ),
              ),
            ],

            Padding(
              padding: EdgeInsets.only(top: styles.routeActions.marginTop),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: onSave,
                      child: Container(
                        padding: styles.secondaryAction.padding,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(styles.secondaryAction.borderRadius),
                          border: Border.all(width: 1, color: styles.secondaryAction.borderColor),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(name: 'star', size: 15, color: colors.primary),
                            SizedBox(width: styles.secondaryAction.gap),
                            Text('Save', style: styles.secondaryActionText),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: styles.routeActions.gap),
                  Expanded(
                    child: GestureDetector(
                      onTap: onShare,
                      child: Container(
                        padding: styles.secondaryAction.padding,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(styles.secondaryAction.borderRadius),
                          border: Border.all(width: 1, color: styles.secondaryAction.borderColor),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(name: 'liveShare', size: 15, color: colors.primary),
                            SizedBox(width: styles.secondaryAction.gap),
                            Text('Share route', style: styles.secondaryActionText),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

/**
 * The list of turns.
 *
 * Lives in the bottom sheet because the weather chip and SOS button were
 * covering it when it was up in the dropdown.
 */
Widget DirectionsCard({ required RouteOption route }) {
  return Builder(
    builder: (context) {
      final styles = useMapTheme(context).styles;
      return Card(
        children: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(title: 'Directions'),
            ...route.steps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              return Container(
                padding: EdgeInsets.symmetric(vertical: styles.stepRow.paddingVertical),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(width: 1, color: styles.stepRow.borderTopColor)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: styles.stepNumber.width,
                      child: Text('${index + 1}', style: styles.stepNumber.textStyle, textAlign: TextAlign.right),
                    ),
                    SizedBox(width: styles.stepRow.gap),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(step.instruction, style: styles.stepText),
                          if (step.distance_m > 0)
                            Padding(
                              padding: EdgeInsets.only(top: styles.stepDistance.marginTop),
                              child: Text(formatDistance(step.distance_m), style: styles.stepDistance.textStyle),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      );
    },
  );
}

/** 850 -> "850 m", 1400 -> "1.4 km" */
String formatDistance(double metres) {
  if (metres < 1000) {
    final value = metres == metres.roundToDouble() ? metres.toInt().toString() : metres.toString();
    return '$value m';
  }
  return '${(metres / 1000).toStringAsFixed(1)} km';
}

String formatTravelDuration(num totalMinutes) {
  if (!totalMinutes.isFinite) return '—';
  final roundedMinutes = math.max(0, totalMinutes.round());
  final days = roundedMinutes ~/ 1440;
  final hours = (roundedMinutes % 1440) ~/ 60;
  final minutes = roundedMinutes % 60;
  final parts = <String>[];
  if (days != 0) parts.add('$days ${days == 1 ? 'day' : 'days'}');
  if (hours != 0) parts.add('$hours hr');
  if (minutes != 0 || parts.isEmpty) parts.add('$minutes min');
  return parts.join(' ');
}

bool sameLocation(GeoLocation left, GeoLocation right) {
  return left.latitude == right.latitude && left.longitude == right.longitude;
}

/** The x in the corner of the route panel — backs you out of the search. */
Widget CloseButton({ required VoidCallback onPress }) {
  return Builder(
    builder: (context) {
      final mapTheme = useMapTheme(context);
      final colors = mapTheme.colors;
      final styles = mapTheme.styles;
      return Semantics(
        button: true,
        label: 'Clear search',
        child: GestureDetector(
          onTap: onPress,
          child: Container(
            width: styles.closeButton.width,
            height: styles.closeButton.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(styles.closeButton.borderRadius),
              color: styles.closeButton.backgroundColor,
            ),
            alignment: Alignment.center,
            child: Icon(name: 'close', size: 16, color: colors.textMuted),
          ),
        ),
      );
    },
  );
}

Widget MapControl({
  required IconName icon,
  /** Read out by screen readers. Only needed on the ones you can press. */
  String? label,
  VoidCallback? onPress,
}) {
  return Builder(
    builder: (context) {
      final mapTheme = useMapTheme(context);
      final colors = mapTheme.colors;
      final styles = mapTheme.styles;
      final glyph = Icon(name: icon, size: 18, color: colors.text);

      // the ones we haven't wired up yet stay decoration rather than pretending
      // to be buttons
      if (onPress == null) {
        return Container(
          width: styles.control.width,
          height: styles.control.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(styles.control.borderRadius),
            color: styles.control.backgroundColor,
            boxShadow: styles.control.boxShadow,
          ),
          alignment: Alignment.center,
          child: glyph,
        );
      }

      return Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onPress,
          child: Container(
            width: styles.control.width,
            height: styles.control.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(styles.control.borderRadius),
              color: styles.control.backgroundColor,
              boxShadow: styles.control.boxShadow,
            ),
            alignment: Alignment.center,
            child: glyph,
          ),
        ),
      );
    },
  );
}

/**
 * The halo behind the SOS button.
 *
 * It used to be one flat disc at 35% opacity, which stopped dead and left a
 * hard ring in the middle of the glow. React Native has no cross-platform
 * radial gradient and a single halo doesn't justify pulling in
 * react-native-svg, so this stacks evenly spaced circles at a low uniform
 * opacity: each one composites onto the last, so the red builds up towards
 * the button and fades out to nothing at the edge.
 */
Widget SosGlow() {
  return Builder(
    builder: (context) {
      final colors = useAppTheme(context).colors;
      final tint = withAlpha(colors.emergency, SOS_GLOW_STEP_ALPHA);
      return SizedBox(
        width: SOS_GLOW_SIZE,
        height: SOS_GLOW_SIZE,
        child: Stack(
          alignment: Alignment.center,
          children: SOS_GLOW_RINGS.map((size) =>
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size / 2),
                color: tint,
              ),
            ),
          ).toList(),
        ),
      );
    },
  );
}

/** Tolls, roadworks and charging stops. Hidden if there are none. */
Widget RoadAlertsCard({
  required ({
    List<String> tolls,
    List<String> works,
    ChargingPlan? charging,
  }) alerts,
}) {
  return Builder(
    builder: (context) {
      final mapTheme = useMapTheme(context);
      final colors = mapTheme.colors;
      final styles = mapTheme.styles;
      final needsCharging = (alerts.charging?.stops_needed ?? 0) > 0;
      if (alerts.tolls.isEmpty && alerts.works.isEmpty && !needsCharging) return const SizedBox.shrink();

      return Card(
        children: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(title: 'On your route'),

            if (alerts.tolls.isNotEmpty)
              Container(
                padding: EdgeInsets.symmetric(vertical: styles.alertRow.paddingVertical),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(width: 1, color: styles.alertRow.borderTopColor)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(name: 'car', size: 16, color: colors.warning),
                    SizedBox(width: styles.alertRow.gap),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Toll roads', style: styles.alertTitle),
                          Padding(
                            padding: EdgeInsets.only(top: styles.alertBody.marginTop),
                            child: Text(alerts.tolls.take(3).join(', '), style: styles.alertBody.textStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            if (alerts.works.isNotEmpty)
              Container(
                padding: EdgeInsets.symmetric(vertical: styles.alertRow.paddingVertical),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(width: 1, color: styles.alertRow.borderTopColor)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(name: 'traffic', size: 16, color: colors.warning),
                    SizedBox(width: styles.alertRow.gap),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Roadworks', style: styles.alertTitle),
                          Padding(
                            padding: EdgeInsets.only(top: styles.alertBody.marginTop),
                            child: Text(alerts.works.take(3).join(', '), style: styles.alertBody.textStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            if (needsCharging && alerts.charging != null)
              Container(
                padding: EdgeInsets.symmetric(vertical: styles.alertRow.paddingVertical),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(width: 1, color: styles.alertRow.borderTopColor)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(name: 'charging', size: 16, color: colors.success),
                    SizedBox(width: styles.alertRow.gap),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${alerts.charging!.stops_needed} charging stop${alerts.charging!.stops_needed > 1 ? 's' : ''} needed',
                            style: styles.alertTitle,
                          ),
                          Padding(
                            padding: EdgeInsets.only(top: styles.alertBody.marginTop),
                            child: Text(
                              alerts.charging!.chargers.isNotEmpty
                                ? alerts.charging!.chargers.take(2).map((c) => c.name).join(', ')
                                : 'Based on ${alerts.charging!.assumed_range_km} km range',
                              style: styles.alertBody.textStyle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
}

/** The row of Food / Hospitals / Pharmacies chips under the search bar. */
Widget CategoryChips({
  required NearbyCategory? selected,
  required bool busy,
  required ValueChanged<NearbyCategory> onChoose,
}) {
  return Builder(
    builder: (context) {
      final mapTheme = useMapTheme(context);
      final colors = mapTheme.colors;
      final styles = mapTheme.styles;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: EdgeInsets.only(right: styles.chipRow.paddingRight),
          child: Row(
            spacing: styles.chipRow.gap,
            children: NEARBY_CATEGORIES.map((cat) {
              final on = selected == cat.key;
              return GestureDetector(
                onTap: () => onChoose(cat.key),
                child: Container(
                  padding: styles.categoryChip.padding,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(styles.categoryChip.borderRadius),
                    border: Border.all(width: 1, color: on ? cat.colour : styles.categoryChip.borderColor),
                    color: on ? cat.colour : styles.categoryChip.backgroundColor,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (on && busy)
                        SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2, color: colors.onAccent),
                        )
                      else
                        Icon(name: cat.icon, size: 15, color: on ? colors.onAccent : cat.colour),
                      SizedBox(width: styles.categoryChip.gap),
                      Text(
                        cat.label,
                        style: on
                          ? styles.categoryChipText.copyWith(color: styles.categoryChipTextOn.color)
                          : styles.categoryChipText,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      );
    },
  );
}

/** What we found nearby, listed in the sheet. */
Widget NearbyCard({
  required NearbyCategory category,
  required List<NearbyPlace> places,
  required ValueChanged<NearbyPlace> onChoose,
}) {
  return Builder(
    builder: (context) {
      final styles = useMapTheme(context).styles;
      final info = categoryInfo(category);
      return Card(
        children: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(title: '${info.label} nearby'),
            ...places.take(8).map((place) =>
              GestureDetector(
                onTap: () => onChoose(place),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: styles.nearbyRow.paddingVertical),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(width: 1, color: styles.nearbyRow.borderTopColor)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: styles.nearbyDot.width,
                        height: styles.nearbyDot.height,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(styles.nearbyDot.width / 2),
                          color: info.colour,
                        ),
                      ),
                      SizedBox(width: styles.nearbyRow.gap),
                      Expanded(
                        child: Text(place.name, style: styles.nearbyName, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      Text('${place.distance_km} km', style: styles.nearbyDistance),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget SavedPlacesCard({ required ValueChanged<GeoLocation> onChoose }) {
  return Builder(
    builder: (context) {
      final mapTheme = useMapTheme(context);
      final colors = mapTheme.colors;
      final styles = mapTheme.styles;
      final data = useAppData(context);
      final places = data.profile.savedPlaces.where((place) => place.kind != 'recent').take(4).toList();
      return Card(
        children: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(title: 'Saved Places'),
            Wrap(
              spacing: styles.savedRow.gap,
              runSpacing: styles.savedRow.gap,
              children: places.map((place) =>
                GestureDetector(
                  onTap: () => onChoose(place),
                  child: Container(
                    padding: styles.savedChip.padding,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(styles.savedChip.borderRadius),
                      color: styles.savedChip.backgroundColor,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          name: place.kind == 'home' ? 'home' : place.kind == 'work' ? 'work' : 'star',
                          size: 16,
                          color: colors.primary,
                        ),
                        SizedBox(width: styles.savedChip.gap),
                        Text(place.label ?? '', style: styles.savedText, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
              ).toList(),
            ),
          ],
        ),
      );
    },
  );
}

Widget UpcomingCard({ required ValueChanged<GeoLocation> onNavigate }) {
  return HookBuilder(
    builder: (context) {
      final styles = useMapTheme(context).styles;
      final data = useAppData(context);
      final showAll = useState(false);
      final events = showAll.value ? data.profile.calendarEvents : data.profile.calendarEvents.take(1).toList();

      void toggleShowAll() {
        showAll.value = !showAll.value;
      }

      if (events.isEmpty) return const SizedBox.shrink();
      return AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: Card(
          children: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(title: 'Upcoming', action: showAll.value ? 'Show Less' : 'View All', onAction: toggleShowAll),
              ...events.map((event) {
                final when = DateTime.parse(event.startsAt).toLocal();
                final formatted = MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(when));
                final timeBig = formatted.replaceAll(RegExp(r'\s?(am|pm)', caseSensitive: false), '');
                final timeAmpm = formatted.replaceAll(RegExp(r'[0-9:\s]'), '');
                return Padding(
                  padding: EdgeInsets.only(top: styles.upcomingEvent.marginTop),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: styles.timeBox.padding,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(styles.timeBox.borderRadius),
                              color: styles.timeBox.backgroundColor,
                            ),
                            child: Column(
                              children: [
                                Text(timeBig, style: styles.timeBig),
                                Text(timeAmpm, style: styles.timeAmpm),
                              ],
                            ),
                          ),
                          SizedBox(width: styles.upcomingRow.gap),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(event.title, style: styles.apptName),
                                Padding(
                                  padding: EdgeInsets.only(top: styles.apptMeta.marginTop),
                                  child: Text(
                                    '${event.subtitle} · remind ${event.reminderMinutes} min before',
                                    style: styles.apptMeta.textStyle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: spacing.sm),
                        child: SizedBox(
                          width: double.infinity,
                          child: Button(
                            label: 'Start Navigation',
                            icon: 'tabMap',
                            size: 'sm',
                            onPress: () => onNavigate(event.location),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      );
    },
  );
}

const SOS_SIZE = 44.0;
/** Gap between the screen edge and the button, halo aside. */
const SOS_MARGIN = 22.0;
const SOS_GLOW_SIZE = 64.0;
/** Enough steps that the falloff reads as smooth rather than banded. */
const SOS_GLOW_STEPS = 12;
const SOS_GLOW_STEP_ALPHA = 0.055;
/** Ring diameters, outside in, stopping just shy of the button. */
final SOS_GLOW_RINGS = List<double>.generate(
  SOS_GLOW_STEPS,
  (ring) =>
    SOS_GLOW_SIZE - (ring * (SOS_GLOW_SIZE - (SOS_SIZE + 4))) / (SOS_GLOW_STEPS - 1),
);

Widget LiveSharingCard({ required ValueChanged<LiveLocation> onSelect }) {
  return HookBuilder(
    builder: (context) {
      final mapTheme = useMapTheme(context);
      final colors = mapTheme.colors;
      final styles = mapTheme.styles;
      final data = useAppData(context);
      final showAll = useState(false);
      final live = data.connections.where((person) => person.status == 'connected' && person.isLive).toList();
      final visibleLive = showAll.value ? live : live.take(3).toList();

      void toggleShowAll() {
        showAll.value = !showAll.value;
      }

      return AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: Card(
          children: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(title: 'Live Sharing', action: showAll.value ? 'Show Less' : 'View All', onAction: toggleShowAll),
              Padding(
                padding: EdgeInsets.only(top: styles.avatarRow.marginTop),
                child: Wrap(
                  spacing: styles.avatarRow.columnGap,
                  runSpacing: styles.avatarRow.rowGap,
                  children: [
                    ...visibleLive.map((person) =>
                      GestureDetector(
                        onTap: person.location == null
                          ? null
                          : () => onSelect(LiveLocation(
                              id: person.id,
                              name: person.name,
                              location: person.location!,
                              lastUpdated: person.lastUpdated,
                            )),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Avatar(name: person.name, size: 44, ring: colors.live, dot: colors.live),
                            const SizedBox(height: 3),
                            Text(person.name, style: styles.avatarName),
                            Text('Live', style: styles.avatarLive),
                          ],
                        ),
                      ),
                    ),
                    if (!showAll.value && live.length > 3)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: styles.morePeople.width,
                            height: styles.morePeople.height,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(styles.morePeople.width / 2),
                              color: styles.morePeople.backgroundColor,
                            ),
                            alignment: Alignment.center,
                            child: Text('+${live.length - 3}', style: styles.moreText),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget LivePersonMenu({
  required LiveLocation person,
  required VoidCallback onClose,
  required VoidCallback onNavigate,
  required VoidCallback onMessage,
  required VoidCallback onSos,
  required VoidCallback onShareBack,
  required VoidCallback onSafeArrival,
}) {
  return Builder(
    builder: (context) {
      final mapTheme = useMapTheme(context);
      final colors = mapTheme.colors;
      final styles = mapTheme.styles;
      final actions = [
        (label: 'Navigate to person', detail: 'Get directions from your current location', icon: 'tabMap', onPress: onNavigate, danger: false),
        (label: 'Send message', detail: 'Let them know you are checking in', icon: 'send', onPress: onMessage, danger: false),
        (label: 'SOS', detail: 'Send your location to your emergency circle', icon: 'sos', onPress: onSos, danger: true),
        (label: 'Share my location', detail: 'Give them live access to your location', icon: 'liveShare', onPress: onShareBack, danger: false),
        (label: 'Set safe arrival', detail: 'Get an alert when you reach your destination', icon: 'safeArrival', onPress: onSafeArrival, danger: false),
      ];
      var swipeDistance = 0.0;

      return GestureDetector(
        onVerticalDragUpdate: (gesture) {
          if (gesture.delta.dy > 0) swipeDistance += gesture.delta.dy;
        },
        onVerticalDragEnd: (gesture) {
          if (swipeDistance > 40) onClose();
          swipeDistance = 0;
        },
        child: Card(
          children: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Avatar(name: person.name, size: 42, ring: colors.live, dot: colors.live),
                  SizedBox(width: styles.personMenuHeader.gap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(person.name, style: styles.personMenuName),
                        Padding(
                          padding: EdgeInsets.only(top: styles.personMenuMeta.marginTop),
                          child: Text('Live location · ${person.lastUpdated}', style: styles.personMenuMeta.textStyle),
                        ),
                      ],
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Close person actions',
                    hint: 'Swipe down to return to the map menu',
                    child: GestureDetector(
                      onTap: onClose,
                      child: Container(
                        width: styles.closeButton.width,
                        height: styles.closeButton.height,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(styles.closeButton.borderRadius),
                          color: styles.closeButton.backgroundColor,
                        ),
                        alignment: Alignment.center,
                        child: Text('×', style: styles.chevron),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsets.only(top: styles.personLocation.marginTop),
                child: Text(person.location.label ?? 'Shared location', style: styles.personLocation.textStyle),
              ),
              Padding(
                padding: EdgeInsets.only(top: styles.swipeHint.marginTop),
                child: Text('Swipe down to close', style: styles.swipeHint.textStyle, textAlign: TextAlign.center),
              ),
              Padding(
                padding: EdgeInsets.only(top: styles.personActions.marginTop),
                child: Column(
                  children: actions.map((action) =>
                    Semantics(
                      button: true,
                      label: action.label,
                      child: GestureDetector(
                        onTap: action.onPress,
                        child: Container(
                          constraints: BoxConstraints(minHeight: styles.personAction.minHeight),
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(width: 1, color: styles.personAction.borderTopColor)),
                          ),
                          child: Row(
                            children: [
                              Icon(name: action.icon, size: 19, color: action.danger ? colors.emergency : colors.primary),
                              SizedBox(width: styles.personAction.gap),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      action.label,
                                      style: action.danger
                                        ? styles.personActionLabel.copyWith(color: colors.emergency)
                                        : styles.personActionLabel,
                                    ),
                                    Padding(
                                      padding: EdgeInsets.only(top: styles.personActionDetail.marginTop),
                                      child: Text(action.detail, style: styles.personActionDetail.textStyle),
                                    ),
                                  ],
                                ),
                              ),
                              Text('›', style: styles.chevron),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ).toList(),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget EllySuggestsCard() {
  return Builder(
    builder: (context) {
      final mapTheme = useMapTheme(context);
      final colors = mapTheme.colors;
      final styles = mapTheme.styles;
      final data = useAppData(context);
      final suggestion = data.suggestions.isNotEmpty ? data.suggestions[0] : null;
      return Card(
        style: BoxDecoration(
          color: colors.card,
          border: Border.all(width: 1, color: colors.elly),
        ),
        children: Row(
          children: [
            IconChip(icon: 'elly', color: colors.elly),
            SizedBox(width: styles.suggestRow.gap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ELLY Suggests', style: styles.suggestTitle),
                  Padding(
                    padding: EdgeInsets.only(top: styles.suggestBody.marginTop),
                    child: Text(
                      suggestion?.detail ?? 'No new travel suggestions.',
                      style: styles.suggestBody.textStyle,
                    ),
                  ),
                ],
              ),
            ),
            Text('›', style: styles.chevron),
          ],
        ),
      );
    },
  );
}

({ ThemeColors colors, bool isDark, dynamic styles }) useMapTheme(BuildContext context) {
  final theme = useAppTheme(context);
  final colors = theme.colors;
  final isDark = theme.isDark;
  final styles = createStyles(colors, isDark);
  return (colors: colors, isDark: isDark, styles: styles);
}

dynamic createStyles(ThemeColors colors, bool isDark) {
  final upperShadow = cardShadow(colors, isDark).map((shadow) => BoxShadow(
    color: shadow.color,
    offset: const Offset(0, -4),
    blurRadius: shadow.blurRadius,
    spreadRadius: shadow.spreadRadius,
  )).toList();

  return (
  dropdown: (
    marginTop: spacing.sm,
    backgroundColor: colors.card,
    borderRadius: radius.md,
    borderColor: colors.border,
    padding: EdgeInsets.symmetric(vertical: spacing.sm, horizontal: spacing.md),
    gap: spacing.xs,
    boxShadow: cardShadow(colors, isDark),
  ),
  dropdownError: TextStyle(fontSize: fontSize.sm, color: colors.textMuted),
  resultRow: (
    gap: spacing.sm,
    paddingVertical: spacing.sm,
  ),
  resultInfo: (flex: 1,),
  resultText: TextStyle(fontSize: fontSize.md, color: colors.text),
  resultAddress: (textStyle: TextStyle(fontSize: fontSize.sm, color: colors.textMuted), marginTop: 2.0),
  routeTo: TextStyle(fontSize: fontSize.md, fontWeight: FontWeight.w700, color: colors.text),
  panelHeader: (gap: spacing.sm,),
  closeButton: (
    width: 28.0,
    height: 28.0,
    borderRadius: 14.0,
    backgroundColor: colors.surfaceAlt,
  ),
  pressed: (opacity: 0.6,),
  routeRow: (
    gap: spacing.sm,
    marginTop: spacing.xs,
  ),
  routeEta: TextStyle(fontSize: fontSize.lg, fontWeight: FontWeight.w700, color: colors.primary),
  routeDistance: TextStyle(fontSize: fontSize.sm, color: colors.textMuted),
  routeFuel: TextStyle(fontSize: fontSize.sm, color: colors.textFaint),
  routeSummary: TextStyle(fontSize: fontSize.sm, color: colors.textFaint),

  modeRow: (marginTop: spacing.sm,),
  startButton: (
    gap: spacing.sm,
    marginTop: spacing.sm,
    padding: EdgeInsets.symmetric(vertical: spacing.sm + 2),
    borderRadius: radius.pill,
    backgroundColor: colors.primary,
  ),
  startButtonText: TextStyle(color: colors.onAccent, fontSize: fontSize.md, fontWeight: FontWeight.w700),
  // the big "500 m / turn left" card
  turnCard: (gap: spacing.md,),
  turnArrow: (
    width: 52.0,
    height: 52.0,
    borderRadius: radius.md,
    backgroundColor: colors.primary,
  ),
  turnWords: (flex: 1,),
  turnDistance: TextStyle(fontSize: fontSize.xxl, fontWeight: FontWeight.w800, color: colors.text),
  turnInstruction: (textStyle: TextStyle(fontSize: fontSize.md, color: colors.textMuted), marginTop: 2.0),
  thenRow: (
    gap: spacing.xs,
    marginTop: spacing.sm,
    paddingTop: spacing.sm,
    borderTopColor: colors.border,
  ),
  thenText: TextStyle(fontSize: fontSize.sm, color: colors.textMuted),
  tripLeftRow: (marginTop: spacing.md,),
  tripLeftText: TextStyle(fontSize: fontSize.sm, fontWeight: FontWeight.w600, color: colors.text),
  endButton: (
    padding: EdgeInsets.symmetric(vertical: spacing.xs + 2, horizontal: spacing.lg),
    borderRadius: radius.pill,
    borderColor: colors.border,
  ),
  endButtonText: TextStyle(fontSize: fontSize.sm, fontWeight: FontWeight.w600, color: colors.emergency),
  // small "look ahead" controls, quieter than the turn card above them
  previewRow: (
    gap: spacing.sm,
    marginTop: spacing.sm,
    paddingTop: spacing.sm,
    borderTopColor: colors.border,
  ),
  previewButton: (
    padding: EdgeInsets.symmetric(vertical: spacing.xs, horizontal: spacing.md),
    borderRadius: radius.pill,
    borderColor: colors.border,
  ),
  debugBox: (
    top: 8.0,
    left: 8.0,
    padding: const EdgeInsets.all(8),
    borderRadius: 8.0,
    backgroundColor: const Color.fromRGBO(0, 0, 0, 0.78),
  ),
  debugText: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
  previewButtonOff: (opacity: 0.35,),
  previewButtonText: TextStyle(fontSize: fontSize.xs, fontWeight: FontWeight.w600, color: colors.textMuted),
  previewCount: TextStyle(fontSize: fontSize.xs, color: colors.textFaint),
  offRouteBanner: (
    marginTop: spacing.sm,
    padding: EdgeInsets.all(spacing.sm),
    borderRadius: radius.md,
    backgroundColor: withAlpha(colors.warning, 0.15),
  ),
  offRouteText: TextStyle(fontSize: fontSize.sm, color: colors.text),
  fromNote: (textStyle: TextStyle(fontSize: fontSize.xs, color: colors.textMuted), marginTop: spacing.xs),
  altRow: (
    gap: spacing.xs,
    marginTop: spacing.sm,
  ),
  altChip: (
    padding: EdgeInsets.symmetric(vertical: spacing.xs, horizontal: spacing.sm),
    borderRadius: radius.pill,
    borderColor: colors.border,
  ),
  altChipOn: (
    backgroundColor: withAlpha(colors.primary, 0.12),
    borderColor: colors.primary,
  ),
  altText: TextStyle(fontSize: fontSize.xs, color: colors.textMuted),
  altTextOn: TextStyle(color: colors.primary, fontWeight: FontWeight.w700),
  directionsToggle: (marginTop: spacing.sm,),
  directionsToggleText: TextStyle(
    fontSize: fontSize.sm,
    color: colors.primary,
    fontWeight: FontWeight.w600,
  ),
  routeActions: (gap: spacing.sm, marginTop: spacing.sm),
  secondaryAction: (
    gap: spacing.xs,
    padding: EdgeInsets.symmetric(vertical: spacing.sm),
    borderColor: colors.border,
    borderRadius: radius.pill,
  ),
  secondaryActionText: TextStyle(color: colors.primary, fontSize: fontSize.sm, fontWeight: FontWeight.w700),
  stepRow: (
    gap: spacing.sm,
    paddingVertical: spacing.sm,
    borderTopColor: colors.border,
  ),
  stepNumber: (
    textStyle: TextStyle(fontSize: fontSize.xs, color: colors.textFaint),
    width: 18.0,
  ),
  stepText: TextStyle(fontSize: fontSize.sm, color: colors.text),
  stepDistance: (textStyle: TextStyle(fontSize: fontSize.xs, color: colors.textMuted), marginTop: 2.0),
  root: (flex: 1, backgroundColor: colors.mapBackdrop),
  overlay: (flex: 1,),
  top: (paddingHorizontal: spacing.md, gap: spacing.md),
  mapArea: (flex: 1,),
  controls: (right: spacing.md, top: spacing.md, gap: spacing.sm),
  control: (
    width: 40.0,
    height: 40.0,
    borderRadius: radius.md,
    backgroundColor: colors.card,
    boxShadow: cardShadow(colors, isDark),
  ),
  layersMenu: (
    right: spacing.md,
    top: spacing.md + 48,
    width: 220.0,
    backgroundColor: colors.card,
    borderRadius: radius.lg,
    borderColor: colors.border,
    padding: EdgeInsets.all(spacing.md),
    boxShadow: cardShadow(colors, isDark),
  ),
  layersTitle: (
    textStyle: TextStyle(fontSize: fontSize.md, fontWeight: FontWeight.w700, color: colors.text),
    marginBottom: spacing.md,
  ),
  layersRow: (gap: spacing.md,),
  layerItem: (flex: 1, gap: spacing.xs),
  layerPreview: (
    height: 64.0,
    borderRadius: radius.md,
    borderColor: colors.border,
    backgroundColor: colors.surfaceAlt,
  ),
  layerPreviewSelected: (
    borderWidth: 2.0,
    borderColor: colors.primary,
  ),
  layerLabel: TextStyle(fontSize: fontSize.sm, fontWeight: FontWeight.w600, color: colors.textMuted),
  layerLabelSelected: TextStyle(color: colors.primary, fontWeight: FontWeight.w700),
  weatherChip: (
    left: spacing.md,
    bottom: spacing.md,
    gap: spacing.xs,
    backgroundColor: colors.card,
    borderRadius: radius.pill,
    padding: EdgeInsets.symmetric(vertical: 8, horizontal: spacing.md),
    boxShadow: cardShadow(colors, isDark),
  ),
  weatherTemp: TextStyle(fontSize: fontSize.md, fontWeight: FontWeight.w700, color: colors.text),
  aqiDot: (width: 6.0, height: 6.0, backgroundColor: colors.success, marginHorizontal: 3.0),
  weatherAqi: TextStyle(fontSize: fontSize.sm, color: colors.textMuted, fontWeight: FontWeight.w600),

  sosWrap: (
    // Sized to the halo rather than the button so Android can't clip the
    // outer rings, then pulled out by the overhang to leave the button
    // itself exactly where it was.
    right: SOS_MARGIN - (SOS_GLOW_SIZE - SOS_SIZE) / 2,
    bottom: SOS_MARGIN - (SOS_GLOW_SIZE - SOS_SIZE) / 2,
    width: SOS_GLOW_SIZE,
    height: SOS_GLOW_SIZE,
  ),
  sos: (
    width: SOS_SIZE,
    height: SOS_SIZE,
    backgroundColor: colors.emergency,
    // The rings above carry the glow now, so this is pulled back to a soft
    // lift under the button rather than a second halo on top of the first.
    boxShadow: [
      BoxShadow(
        color: withAlpha(colors.emergency, 0.3),
        offset: Offset.zero,
        blurRadius: 8,
      ),
    ],
  ),
  sosText: TextStyle(color: colors.onAccent, fontWeight: FontWeight.w800, fontSize: fontSize.sm),

  sheet: (
    backgroundColor: colors.background,
    borderTopLeftRadius: radius.lg + 4,
    borderTopRightRadius: radius.lg + 4,
    boxShadow: upperShadow,
  ),
  personSheet: (
    backgroundColor: colors.background,
    borderTopLeftRadius: radius.lg + 4,
    borderTopRightRadius: radius.lg + 4,
    padding: EdgeInsets.only(top: spacing.xs, left: spacing.md, right: spacing.md),
    boxShadow: upperShadow,
  ),
  personSheetHandle: (height: 28.0,),
  personMenuHeader: (gap: spacing.sm,),
  personMenuTitle: (flex: 1,),
  personMenuName: TextStyle(fontSize: fontSize.md, fontWeight: FontWeight.w800, color: colors.text),
  personMenuMeta: (textStyle: TextStyle(fontSize: fontSize.xs, color: colors.live), marginTop: 2.0),
  swipeHint: (textStyle: TextStyle(fontSize: fontSize.xs, color: colors.textFaint), marginTop: spacing.sm),
  personActions: (marginTop: spacing.sm,),
  personAction: (
    gap: spacing.md,
    minHeight: 52.0,
    borderTopColor: colors.border,
  ),
  personActionText: (flex: 1,),
  personActionLabel: TextStyle(fontSize: fontSize.md, fontWeight: FontWeight.w700, color: colors.text),
  personActionDetail: (textStyle: TextStyle(fontSize: fontSize.xs, color: colors.textMuted), marginTop: 2.0),
  personLocation: (textStyle: TextStyle(fontSize: fontSize.sm, color: colors.textMuted), marginTop: spacing.sm),
  handleButton: (height: 28.0,),
  handlePressable: (flex: 1,),
  handle: (
    width: 40.0,
    height: 5.0,
    borderRadius: 3.0,
    backgroundColor: colors.borderStrong,
  ),
  sheetContent: (
    padding: EdgeInsets.only(left: spacing.md, right: spacing.md, bottom: spacing.lg),
    gap: spacing.md,
  ),

  chipRow: (gap: spacing.xs, paddingRight: spacing.md),
  categoryChip: (
    gap: spacing.xs,
    padding: EdgeInsets.symmetric(vertical: spacing.xs + 2, horizontal: spacing.sm + 2),
    borderRadius: radius.pill,
    borderColor: colors.border,
    backgroundColor: colors.card,
  ),
  categoryChipText: TextStyle(fontSize: fontSize.sm, color: colors.text, fontWeight: FontWeight.w600),
  categoryChipTextOn: TextStyle(color: colors.onAccent),
  nearbyRow: (
    gap: spacing.sm,
    paddingVertical: spacing.sm,
    borderTopColor: colors.border,
  ),
  nearbyDot: (width: 10.0, height: 10.0),
  nearbyName: TextStyle(fontSize: fontSize.md, color: colors.text),
  nearbyDistance: TextStyle(fontSize: fontSize.sm, color: colors.textMuted),
  alertRow: (
    gap: spacing.sm,
    paddingVertical: spacing.sm,
    borderTopColor: colors.border,
  ),
  alertTitle: TextStyle(fontSize: fontSize.sm, fontWeight: FontWeight.w600, color: colors.text),
  alertBody: (textStyle: TextStyle(fontSize: fontSize.xs, color: colors.textMuted), marginTop: 2.0),
  searchDock: (gap: spacing.xs,),
  savedRow: (gap: spacing.sm,),
  savedChip: (
    gap: spacing.xs,
    maxWidth: 0.48,
    backgroundColor: colors.surfaceAlt,
    borderRadius: radius.pill,
    padding: EdgeInsets.symmetric(vertical: spacing.sm, horizontal: spacing.md),
  ),
  savedText: TextStyle(color: colors.text, fontSize: fontSize.sm, fontWeight: FontWeight.w600),

  upcomingRow: (gap: spacing.md,),
  timeBox: (
    backgroundColor: withAlpha(colors.primary, 0.1),
    borderRadius: radius.md,
    padding: EdgeInsets.symmetric(vertical: spacing.sm, horizontal: spacing.md),
  ),
  timeBig: TextStyle(fontSize: fontSize.lg, fontWeight: FontWeight.w800, color: colors.primary),
  timeAmpm: TextStyle(fontSize: fontSize.xs, fontWeight: FontWeight.w700, color: colors.primary),
  apptName: TextStyle(fontSize: fontSize.md, fontWeight: FontWeight.w700, color: colors.text),
  apptMeta: (textStyle: TextStyle(fontSize: fontSize.sm, color: colors.textMuted), marginTop: 2.0),

  avatarRow: (columnGap: spacing.xl, rowGap: spacing.md, marginTop: spacing.xs),
  avatarItem: (gap: 3.0,),
  upcomingEvent: (marginTop: spacing.sm,),
  avatarName: TextStyle(fontSize: fontSize.xs + 1, fontWeight: FontWeight.w600, color: colors.text),
  avatarLive: TextStyle(fontSize: fontSize.xs, color: colors.live, fontWeight: FontWeight.w700),
  morePeople: (width: 44.0, height: 44.0, backgroundColor: colors.surfaceAlt),
  moreText: TextStyle(fontSize: fontSize.md, fontWeight: FontWeight.w700, color: colors.textMuted),

  ellySuggestButton: (right: spacing.md, top: spacing.md + 96, width: 40.0, height: 40.0, borderRadius: radius.md, backgroundColor: colors.card, boxShadow: cardShadow(colors, isDark)),
  ellySuggestPopup: (right: spacing.md + 48, top: spacing.md + 96, width: 360.0, maxWidth: 0.70, backgroundColor: colors.card, borderRadius: radius.lg, borderColor: colors.border, padding: EdgeInsets.all(spacing.md), boxShadow: cardShadow(colors, isDark)),

  suggestRow: (gap: spacing.md,),
  suggestTitle: TextStyle(fontSize: fontSize.md, fontWeight: FontWeight.w700, color: colors.elly),
  suggestBody: (textStyle: TextStyle(fontSize: fontSize.sm, color: colors.text, height: 18 / fontSize.sm), marginTop: 2.0),
  chevron: TextStyle(fontSize: 24, color: colors.textFaint),
  );
}