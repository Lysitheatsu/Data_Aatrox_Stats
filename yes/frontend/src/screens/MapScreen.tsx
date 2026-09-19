import React, { useEffect, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  Platform,
  Animated,
  LayoutAnimation,
  PanResponder,
  Pressable,
  Share,
  ScrollView,
  StyleSheet,
  Text,
  useWindowDimensions,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import {
  Header,
  SearchBar,
  Card,
  SectionHeader,
  Button,
  Avatar,
  IconChip,
  Icon,
  SegmentedControl,
} from '@/components';
import { cardShadow, fontSize, radius, spacing, withAlpha, type ThemeColors } from '@/theme';
import { useAppTheme } from '@/theme/ThemeProvider';
import type { LiveLocation } from '@/map/types';
import { EllyMap } from '@/map/EllyMap';
import { ApiError, api, type GeoLocation, type RouteOption, type RouteStep, type TravelMode } from '@/api/client';
import type { IconName } from '@/theme/icons';
import { useCurrentLocation, type LocationStatus } from '@/hooks/useCurrentLocation';
import { useLiveLocation } from '@/hooks/useLiveLocation';
import {
  bearingBetween,
  distanceM,
  distanceToStep,
  hasReachedStep,
  isOffRoute,
  remainingDistanceM,
  remainingRoute,
  turnIcon,
  ARRIVED_AT_TURN_M,
  BEARING_MIN_MOVE_M,
} from '@/lib/navigation';
import { useAppData } from '@/data/AppDataProvider';
import { NEARBY_CATEGORIES, categoryInfo } from '@/lib/nearbyCategories';
import type { ChargingPlan, FuelEstimate, NearbyCategory, NearbyPlace } from '@/api/client';
import { useNavigation, useRoute } from '@react-navigation/native';

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

export function MapScreen(): React.JSX.Element {
  const { colors, styles } = useMapTheme();
  const data = useAppData();
  const navigation = useNavigation<any>();
  const navigationRoute = useRoute<any>();
  const [selectedPerson, setSelectedPerson] = useState<LiveLocation | null>(null);
  const personSheetProgress = React.useRef(new Animated.Value(1)).current;
  const [liveFocus, setLiveFocus] = useState<GeoLocation | null>(null);
  const liveLocations = React.useMemo(() => data.connections.flatMap((person): LiveLocation[] =>
    person.status === 'connected' && person.isLive && person.location
      ? [{ id: person.id, name: person.name, location: person.location, lastUpdated: person.lastUpdated }]
      : []), [data.connections]);
  const { height: windowHeight } = useWindowDimensions();
  // where you are, or Melbourne CBD if you said no
  const { location: currentLocation, status: locationStatus } = useCurrentLocation();
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<GeoLocation[]>([]);
  const [destinationPersonId, setDestinationPersonId] = useState<string | null>(null);
  const [destination, setDestination] = useState<GeoLocation | null>(null);
  const [routes, setRoutes] = useState<RouteOption[]>([]);
  const [chosenRoute, setChosenRoute] = useState(0);
  const [mode, setMode] = useState<TravelMode>('driving');
  const [routeOrigin, setRouteOrigin] = useState<GeoLocation>(currentLocation);
  const [showDirections, setShowDirections] = useState(false);
  // which step you're on while navigating, null means not navigating
  const [navStep, setNavStep] = useState<number | null>(null);
  const isNavigating = navStep !== null;
  // only watch the GPS while actually navigating, it eats battery
  const livePosition = useLiveLocation(isNavigating);
  // true once you've wandered off the route
  const [offRoute, setOffRoute] = useState(false);
  // true while you're clicking through turns yourself. stops the camera
  // snapping back to your dot, which is what happens on a laptop where the
  // location never changes.
  const [previewing, setPreviewing] = useState(false);
  // where we last took a bearing from, and the bearing itself
  const bearingAnchorRef = React.useRef<GeoLocation | null>(null);
  const [travelBearing, setTravelBearing] = useState<number | null>(null);
  const lastPositionRef = React.useRef<GeoLocation | null>(null);
  const navigationContact = destinationPersonId
    ? liveLocations.find((person) => person.id === destinationPersonId)
    : isNavigating && destination
      ? liveLocations.find((person) => sameLocation(person.location, destination))
      : undefined;
  const visibleLiveLocations = React.useMemo(() => {
    if (navigationContact) return [navigationContact];
    return isNavigating || destinationPersonId ? [] : liveLocations;
  }, [navigationContact, isNavigating, destinationPersonId, liveLocations]);
  const route = routes[chosenRoute] ?? null;
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [weather, setWeather] = useState<{ temp: string; aqi: string } | null>(null);
  // roughly what the petrol costs, once we know the distance
  const [fuel, setFuel] = useState<FuelEstimate | null>(null);
  // tolls, roadworks and charging stops on the route
  const [roadAlerts, setRoadAlerts] = useState<{
    tolls: string[];
    works: string[];
    charging: ChargingPlan | null;
  } | null>(null);
  const [isSheetExpanded, setIsSheetExpanded] = useState(true);
  // bumped by the navigate button to pull the map back to where you are
  const [recenterSignal, setRecenterSignal] = useState(0);
  const [showMapLayers, setShowMapLayers] = useState(false);
  const [mapType, setMapType] = useState<'default' | 'satellite'>('default');
  const [showEllySuggests, setShowEllySuggests] = useState(false);
  // which category chip is on, and what it found nearby
  const [nearbyCategory, setNearbyCategory] = useState<NearbyCategory | null>(null);
  const [nearbyPlaces, setNearbyPlaces] = useState<NearbyPlace[]>([]);
  const [nearbyBusy, setNearbyBusy] = useState(false);
  const sheetProgress = React.useRef(new Animated.Value(1)).current;
  const dragStartProgress = React.useRef(1);
  const collapsedSheetHeight = 44;
  const expandedSheetHeight = Math.max(collapsedSheetHeight, Math.round(windowHeight * 0.52));
  const sheetTravel = Math.max(1, expandedSheetHeight - collapsedSheetHeight);

  const animateSheet = React.useCallback(
    (expanded: boolean) => {
      setIsSheetExpanded(expanded);
      Animated.spring(sheetProgress, {
        toValue: expanded ? 1 : 0,
        damping: 22,
        stiffness: 220,
        mass: 0.8,
        useNativeDriver: false,
      }).start();
    },
    [sheetProgress],
  );

  const showPersonMessage = (message: string) => {
    if (Platform.OS === 'web') window.alert(message);
    else Alert.alert('Live sharing', message);
  };

  const selectLiveLocation = React.useCallback((person: LiveLocation) => {
    personSheetProgress.stopAnimation();
    personSheetProgress.setValue(1);
    setSelectedPerson({ ...person });
    setLiveFocus({ ...person.location });
    animateSheet(true);
  }, [animateSheet, personSheetProgress]);

  useEffect(() => {
    if (!selectedPerson) return;
    Animated.spring(personSheetProgress, {
      toValue: 0,
      damping: 24,
      stiffness: 220,
      mass: 0.85,
      useNativeDriver: true,
    }).start();
  }, [personSheetProgress, selectedPerson]);

  const dismissLivePerson = React.useCallback(() => {
    Animated.timing(personSheetProgress, {
      toValue: 1,
      duration: 220,
      useNativeDriver: true,
    }).start(({ finished }) => { if (finished) setSelectedPerson(null); });
  }, [personSheetProgress]);

  const personSheetPanResponder = React.useMemo(() => PanResponder.create({
    onMoveShouldSetPanResponderCapture: (_event, gesture) => gesture.dy > 6 && Math.abs(gesture.dy) > Math.abs(gesture.dx),
    onMoveShouldSetPanResponder: (_event, gesture) => gesture.dy > 10,
    onPanResponderRelease: (_event, gesture) => {
      if (gesture.dy > 40) dismissLivePerson();
    },
  }), [dismissLivePerson]);

  const sheetPanResponder = React.useMemo(
    () =>
      PanResponder.create({
        onMoveShouldSetPanResponderCapture: (_event, gesture) => Math.abs(gesture.dy) > 4,
        onMoveShouldSetPanResponder: (_event, gesture) => Math.abs(gesture.dy) > 4,
        onPanResponderGrant: () => {
          sheetProgress.stopAnimation((value) => {
            dragStartProgress.current = value;
          });
        },
        onPanResponderMove: (_event, gesture) => {
          const nextProgress = Math.max(
            0,
            Math.min(1, dragStartProgress.current - gesture.dy / sheetTravel),
          );
          sheetProgress.setValue(nextProgress);
        },
        onPanResponderRelease: (_event, gesture) => {
          sheetProgress.stopAnimation(() => {
            const hasClearFlick = Math.abs(gesture.vy) >= 0.15;
            const hasClearPull = Math.abs(gesture.dy) >= 12;
            const shouldExpand = hasClearFlick
              ? gesture.vy < 0
              : hasClearPull
                ? gesture.dy < 0
                : dragStartProgress.current >= 0.5;
            animateSheet(shouldExpand);
          });
        },
        onPanResponderTerminate: () => {
          sheetProgress.stopAnimation((value) => animateSheet(value >= 0.5));
        },
      }),
    [animateSheet, sheetProgress, sheetTravel],
  );

  const animatedSheetHeight = sheetProgress.interpolate({
    inputRange: [0, 1],
    outputRange: [collapsedSheetHeight, expandedSheetHeight],
    extrapolate: 'clamp',
  });

  // search for whatever's been typed in
  const runSearch = async () => {
    if (!query.trim()) return;
    setBusy(true);
    setError(null);
    setRoutes([]);
    setDestination(null);
    setDestinationPersonId(null);
    setShowDirections(false);
    setNavStep(null);
    try {
      const found = await api.searchPlaces(query, 5, currentLocation.latitude, currentLocation.longitude);
      setResults(found);
      if (found.length === 0) setError('No places found for that.');
    } catch {
      setError("Couldn't reach the map service.");
    } finally {
      setBusy(false);
    }
  };

  // work out how to get there
  // tap a chip to find those places around you, tap it again to clear
  const chooseCategory = async (key: NearbyCategory) => {
    if (nearbyCategory === key) {
      setNearbyCategory(null);
      setNearbyPlaces([]);
      return;
    }
    setNearbyCategory(key);
    setNearbyBusy(true);
    setNearbyPlaces([]);
    try {
      setNearbyPlaces(
        await api.nearby(key, currentLocation.latitude, currentLocation.longitude, 2000),
      );
    } catch {
      setNearbyPlaces([]);
    } finally {
      setNearbyBusy(false);
    }
  };

  const planTo = async (place: GeoLocation, travelMode: TravelMode, origin = currentLocation) => {
    setBusy(true);
    setError(null);
    setRouteOrigin(origin);
    try {
      const planned = await api.planRoutes(origin, place, travelMode);
      setRoutes(planned.options);
      setChosenRoute(0);
      if (planned.options.length === 0) {
        setError('No route to that place.');
      }
      // the sheet used to collapse here so you could see the route, but the
      // search bar lives in the sheet now, so closing it hides everything
    } catch (reason) {
      if (reason instanceof ApiError && reason.status === 422) {
        setError(`No ${travelMode} route connects these locations.`);
      } else if (reason instanceof ApiError) {
        setError(`Route service error (${reason.status}).`);
      } else {
        setError("Couldn't reach the route service.");
      }
    } finally {
      setBusy(false);
    }
  };

  // show a health service from the Emergency screen on the map
  useEffect(() => {
    const focusLocation = navigationRoute.params?.focusLocation;
    if (!focusLocation) return;
    setDestination(focusLocation);
    setDestinationPersonId(null);
    setResults([]);
    setQuery(focusLocation.label ?? '');
    setRoutes([]);
    setChosenRoute(0);
    setShowDirections(false);
    setNavStep(null);
    setLiveFocus(null);
    setError(null);
    void planTo(focusLocation, mode, currentLocation);
    navigation.setParams({
      focusLocation: undefined,
    });
  }, [navigationRoute.params?.focusLocation]);

  // pick one of the search results
  const chooseDestination = async (place: GeoLocation, personId: string | null = null) => {
    setDestinationPersonId(personId);
    setDestination(place);
    setResults([]);
    setQuery(place.label ?? '');
    setShowDirections(false);
    setNavStep(null);
    await planTo(place, mode, currentLocation);
  };

  // the x on the route panel: forget the whole search
  const clearSearch = () => {
    setQuery('');
    setResults([]);
    setDestination(null);
    setDestinationPersonId(null);
    setRoutes([]);
    setChosenRoute(0);
    setShowDirections(false);
    setNavStep(null);
    setError(null);
    // planning a route collapsed the sheet, put it back
    animateSheet(true);
  };

  // plan again from where you are now, for when you've gone off route
  // pressing Back/Next moves the card and flies the map to that turn
  const previewStep = (index: number) => {
    setPreviewing(true);
    setNavStep(index);
  };

  const rerouteFromHere = async () => {
    if (!destination) return;
    const from = livePosition?.location ?? currentLocation;
    setOffRoute(false);
    setNavStep(0);
    await planTo(destination, mode, from);
  };

  // switching mode re-plans the same trip
  const changeMode = async (next: TravelMode) => {
    setMode(next);
    setShowDirections(false);
    setNavStep(null);
    if (destination) await planTo(destination, next, routeOrigin);
  };

  // real weather instead of the hardcoded 28 degrees
  useEffect(() => {
    const target = destination ?? currentLocation;
    api
      .journeyInfo(currentLocation, target, route?.distance_km, route?.geometry)
      .then((info) => {
        // weather_summary looks like "Clear, 8°C", we just want the number
        const temp = info.weather_summary.split(',').pop()?.trim() ?? '—';
        setWeather({
          temp,
          aqi: info.air_quality_index === null ? '—' : String(info.air_quality_index),
        });
        setFuel(info.fuel);
        setRoadAlerts({
          tolls: info.toll_roads ?? [],
          works: info.construction ?? [],
          charging: info.charging,
        });
      })
      .catch(() => setWeather(null));
    // runs again when the real location turns up
    // needs the distance too, it arrives after the route is planned
  }, [destination, currentLocation, route?.distance_km]);

  // move to the next turn once you've reached this one, and notice if you've
  // gone the wrong way
  useEffect(() => {
    if (!livePosition || navStep === null || !route) return;
    const here = livePosition.location;

    // if you've actually moved, you're driving, so stop previewing and let the
    // camera follow you again
    const previous = lastPositionRef.current;
    if (previous && distanceM(previous.latitude, previous.longitude, here.latitude, here.longitude) > 10) {
      setPreviewing(false);
    }

    // check the turn we're heading towards, not the one we're standing on.
    // step 0 is "start here" so you're always at it, which would skip it.
    const nextIndex = navStep + 1;
    const nextStep = route.steps[nextIndex];
    if (nextStep && hasReachedStep(here, nextStep)) {
      setNavStep(nextIndex);
    }

    setOffRoute(isOffRoute(here, route.geometry));
    lastPositionRef.current = here;
  }, [livePosition, navStep, route]);

  // work out which way you're facing from how you've moved.
  //
  // we don't compare to the last reading, walking only moves you a metre or so
  // between them and the gps noise is bigger than that. instead we keep an
  // anchor and only take a new bearing once you're properly away from it.
  useEffect(() => {
    if (!livePosition) {
      // navigation stopped, start fresh next time
      bearingAnchorRef.current = null;
      setTravelBearing(null);
      return;
    }
    const here = livePosition.location;
    const anchor = bearingAnchorRef.current;
    if (!anchor) {
      bearingAnchorRef.current = here;
      return;
    }
    const moved = distanceM(anchor.latitude, anchor.longitude, here.latitude, here.longitude);
    if (moved >= BEARING_MIN_MOVE_M) {
      setTravelBearing(bearingBetween(anchor, here));
      bearingAnchorRef.current = here;
    }
  }, [livePosition]);

  // the line ahead of you. shrinks as you travel so you only see what's left.
  const drawnRoute = React.useMemo(() => {
    if (!route) return undefined;
    if (!livePosition || navStep === null) return route.geometry;
    return remainingRoute(route.geometry, livePosition.location);
  }, [route, livePosition, navStep]);

  // which way to point the map and the arrow
  const followBearing = React.useMemo(() => {
    if (!livePosition) return null;
    // how you've moved beats the phone's compass. browsers hand back 0 rather
    // than null when they don't know, which points you north by mistake.
    if (travelBearing !== null) return travelBearing;
    const fromPhone = livePosition.heading;
    return fromPhone !== null && Number.isFinite(fromPhone) ? fromPhone : null;
  }, [livePosition, travelBearing]);

  // everything the turn card needs. navStep is the turn you last passed, so
  // the one you're actually driving towards is the one after it.
  const guidance = React.useMemo(() => {
    if (navStep === null || !route) return null;

    const last = route.steps.length - 1;
    const aheadIndex = Math.min(navStep + 1, last);
    const ahead = route.steps[aheadIndex];
    if (!ahead) return null;

    // live distance if we know where you are, otherwise fall back to how long
    // the step is so it still shows something sensible on a desktop
    const live = livePosition ? distanceToStep(livePosition.location, ahead) : null;
    const metresToTurn = live ?? ahead.distance_m;

    const left = remainingDistanceM(route.steps, aheadIndex);
    const total = remainingDistanceM(route.steps, 0);

    return {
      instruction: ahead.instruction,
      icon: turnIcon(ahead.instruction),
      metresToTurn,
      // where the turn is, so the map can fly to it
      location: ahead.location ?? null,
      // where this turn sits in the list, for the preview buttons
      index: aheadIndex,
      count: route.steps.length,
      isLast: aheadIndex === last,
      // the turn after this one, shown small as a heads up
      then: route.steps[aheadIndex + 1] ?? null,
      arrived: aheadIndex === last && metresToTurn <= ARRIVED_AT_TURN_M,
      remainingM: left,
      // scale the trip time by how much of it is left
      remainingMin: total > 0 ? (route.eta_minutes * left) / total : 0,
    };
  }, [navStep, route, livePosition]);

  return (
    <View style={styles.root}>
      {/* Full-screen MapLibre map, themed from the app's design tokens. */}
      <EllyMap
        focus={destination}
        showFocusMarker={!destinationPersonId && !navigationContact}
        liveLocations={visibleLiveLocations}
        liveFocus={liveFocus}
        onSelectLiveLocation={selectLiveLocation}
        origin={livePosition?.location ?? currentLocation}
        heading={followBearing}
        routeGeometry={drawnRoute}
        followStep={guidance?.location ?? null}
        liveFollow={
          livePosition && !previewing
            ? { location: livePosition.location, bearing: followBearing }
            : null
        }
        recenterSignal={recenterSignal}
        bottomInset={selectedPerson ? expandedSheetHeight : isSheetExpanded ? expandedSheetHeight : collapsedSheetHeight}
        mapType={mapType}
      />

      {/* add ?debug=1 to the url to see what the phone's gps is actually
          reporting. handy for working out why the arrow isn't showing. */}
      {DEBUG_GPS ? (
        <View style={styles.debugBox} pointerEvents="none">
          <Text style={styles.debugText}>navigating: {String(isNavigating)}</Text>
          <Text style={styles.debugText}>
            fix: {livePosition ? `${livePosition.location.latitude.toFixed(5)}, ${livePosition.location.longitude.toFixed(5)}` : 'none'}
          </Text>
          <Text style={styles.debugText}>phone heading: {String(livePosition?.heading)}</Text>
          <Text style={styles.debugText}>phone speed: {String(livePosition?.speed)}</Text>
          <Text style={styles.debugText}>travel bearing: {String(travelBearing)}</Text>
          <Text style={styles.debugText}>arrow angle: {String(followBearing)}</Text>
          <Text style={styles.debugText}>arrow shows: {String(followBearing !== null)}</Text>
        </View>
      ) : null}

      <SafeAreaView style={styles.overlay} edges={['top']} pointerEvents="box-none">
        {/* Header remains clear while search lives in the lower journey sheet. */}
        <View style={styles.top} pointerEvents="auto">
          <Header logo showMenu showBell bellDot showAvatar />
        </View>

        {/* Middle: floating controls over the live map */}
        <View style={styles.mapArea} pointerEvents="box-none">
          <View style={styles.controls}>
            <MapControl
              icon="layers"
              label="Map layers"
              onPress={() => setShowMapLayers((open) => !open)}
            />
            {/* One control for "where am I", rather than a crosshair and an
                arrow that would both mean the same thing. */}
            <MapControl
              icon="tabMap"
              label="Navigate back to your location"
              onPress={() => setRecenterSignal((count) => count + 1)}
            />
          </View>

          {showMapLayers ? (
            <View style={styles.layersMenu}>
              <Text style={styles.layersTitle}>Map type</Text>
              <View style={styles.layersRow}>
                <Pressable
                  accessibilityRole="button"
                  accessibilityLabel="Default map"
                  onPress={() => {
                    setMapType('default');
                    setShowMapLayers(false);
                  }}
                  style={styles.layerItem}
                >
                  <View style={[
                    styles.layerPreview,
                    mapType === 'default' && styles.layerPreviewSelected,
                  ]}>
                    <Icon name="tabMap" size={24} color={colors.primary} />
                  </View>
                  <Text style={[
                    styles.layerLabel,
                    mapType === 'default' && styles.layerLabelSelected,
                  ]}>
                    Default
                  </Text>
                </Pressable>

                <Pressable
                  accessibilityRole="button"
                  accessibilityLabel="Satellite map"
                  onPress={() => {
                    setMapType('satellite');
                    setShowMapLayers(false);
                  }}
                  style={styles.layerItem}
                >
                  <View style={[
                    styles.layerPreview,
                    mapType === 'satellite' && styles.layerPreviewSelected,
                  ]}>
                    <Icon name="layers" size={24} color={colors.text} />
                  </View>
                  <Text style={[
                    styles.layerLabel,
                    mapType === 'satellite' && styles.layerLabelSelected,
                  ]}>
                    Satellite
                  </Text>
                </Pressable>
              </View>
            </View>
          ) : null}

          <Pressable
            accessibilityRole="button"
            accessibilityLabel="ELLY Suggests"
            onPress={() => setShowEllySuggests((open) => !open)}
            style={styles.ellySuggestButton}
          >
            <Icon name="elly" size={20} color={colors.elly} />
          </Pressable>

          {showEllySuggests ? (
            <View style={styles.ellySuggestPopup}>
              <EllySuggestsCard />
            </View>
          ) : null}

          <View style={styles.weatherChip}>
            <Icon name="weather" size={18} color={colors.warning} />
            <Text style={styles.weatherTemp}>{weather?.temp ?? '—'}</Text>
            <View style={styles.aqiDot} />
            <Text style={styles.weatherAqi}>AQI {weather?.aqi ?? '—'}</Text>
          </View>

          <Pressable style={styles.sosWrap} onPress={() => navigation.navigate('Emergency')} accessibilityRole="button" accessibilityLabel="Open SOS and emergency">
            <SosGlow />
            <View style={styles.sos}>
              <Text style={styles.sosText}>SOS</Text>
            </View>
          </Pressable>
        </View>

        <Animated.View
          style={[styles.sheet, { height: animatedSheetHeight }]}
          pointerEvents="auto"
        >
          <View {...sheetPanResponder.panHandlers} style={styles.handleButton}>
            <Pressable
              accessibilityRole="button"
              accessibilityLabel={
                isSheetExpanded ? 'Collapse journey panel' : 'Expand journey panel'
              }
              accessibilityHint="Tap, or drag vertically, to resize the panel"
              accessibilityState={{ expanded: isSheetExpanded }}
              hitSlop={{ top: 8, bottom: 8, left: 16, right: 16 }}
              onPress={() => animateSheet(!isSheetExpanded)}
              style={styles.handlePressable}
            >
              <View style={styles.handle} />
            </Pressable>
          </View>
          <ScrollView
            scrollEnabled={isSheetExpanded}
            showsVerticalScrollIndicator={false}
            contentContainerStyle={styles.sheetContent}
          >
            <View style={styles.searchDock}>
              <SearchBar placeholder="Where do you want to go?" value={query} onChangeText={setQuery} onSubmit={runSearch} />
              <SearchResults
                busy={busy} error={error} results={results} routes={routes} chosenRoute={chosenRoute}
                onChooseRoute={setChosenRoute} mode={mode} onChangeMode={changeMode} destination={destination}
                onChoose={chooseDestination} locationStatus={locationStatus} navStep={navStep}
                guidance={guidance}
                offRoute={offRoute}
                onReroute={rerouteFromHere}
                onStartNavigation={() => setNavStep(0)} onStopNavigation={() => setNavStep(null)} onStepChange={previewStep}
                showDirections={showDirections} onToggleDirections={() => setShowDirections((open) => !open)} onClear={clearSearch}
                fuel={fuel}
                onSave={() => destination && data.toggleFavourite(destination)}
                onShare={() => destination && void Share.share({ message: `Meet me at ${destination.label ?? 'this location'}: https://www.openstreetmap.org/?mlat=${destination.latitude}&mlon=${destination.longitude}` })}
              />
            </View>
            {!destination ? (
              <CategoryChips selected={nearbyCategory} busy={nearbyBusy} onChoose={chooseCategory} />
            ) : null}
            {nearbyCategory && nearbyPlaces.length > 0 ? (
              <NearbyCard
                category={nearbyCategory}
                places={nearbyPlaces}
                onChoose={(place) => chooseDestination(place.location)}
              />
            ) : null}
            <SavedPlacesCard onChoose={chooseDestination} />
            {showDirections && route && route.steps.length > 0 ? (
              <DirectionsCard route={route} />
            ) : null}
            {route && roadAlerts ? <RoadAlertsCard alerts={roadAlerts} /> : null}
            <UpcomingCard onNavigate={chooseDestination} />
          </ScrollView>
        </Animated.View>
        {selectedPerson ? (
          <Animated.View
            {...personSheetPanResponder.panHandlers}
            pointerEvents="auto"
            style={[styles.personSheet, {
              height: expandedSheetHeight,
              transform: [{ translateY: personSheetProgress.interpolate({ inputRange: [0, 1], outputRange: [0, expandedSheetHeight] }) }],
            }]}
          >
            <View style={styles.personSheetHandle}><View style={styles.handle} /></View>
            <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={{ paddingBottom: spacing.lg }}>
              <LivePersonMenu
                person={selectedPerson}
                onClose={dismissLivePerson}
                onNavigate={() => {
                  setSelectedPerson(null);
                  setLiveFocus(null);
                  void chooseDestination({ ...selectedPerson.location, label: selectedPerson.name }, selectedPerson.id);
                }}
                onMessage={() => showPersonMessage(`Messaging ${selectedPerson.name} will be available when your contacts are connected.`)}
                onSos={() => { setSelectedPerson(null); navigation.navigate('Emergency'); }}
                onShareBack={() => { setSelectedPerson(null); navigation.navigate('Connections'); }}
                onSafeArrival={() => showPersonMessage(`Safe-arrival alerts for ${selectedPerson.name} are coming soon.`)}
              />
            </ScrollView>
          </Animated.View>
        ) : null}
      </SafeAreaView>
    </View>
  );
}

// what we show vs what the api calls it
const MODE_LABELS: Record<TravelMode, string> = {
  driving: 'Drive',
  walking: 'Walk',
  cycling: 'Cycle',
};
const MODES = Object.keys(MODE_LABELS) as TravelMode[];

/** Shows the raw gps readings when the url has ?debug=1 on it. */
const DEBUG_GPS =
  typeof window !== 'undefined' && /[?&]debug=1/.test(window.location?.search ?? '');

/** What the turn card shows. Worked out in MapScreen from the live position. */
interface Guidance {
  instruction: string;
  icon: IconName;
  metresToTurn: number;
  location: [number, number] | null;
  index: number;
  count: number;
  isLast: boolean;
  then: RouteStep | null;
  arrived: boolean;
  remainingM: number;
  remainingMin: number;
}

interface SearchResultsProps {
  busy: boolean;
  error: string | null;
  results: GeoLocation[];
  routes: RouteOption[];
  chosenRoute: number;
  onChooseRoute: (index: number) => void;
  mode: TravelMode;
  onChangeMode: (mode: TravelMode) => void;
  destination: GeoLocation | null;
  onChoose: (place: GeoLocation) => void;
  locationStatus: LocationStatus;
  fuel: FuelEstimate | null;
  navStep: number | null;
  guidance: Guidance | null;
  offRoute: boolean;
  onReroute: () => void;
  onStepChange: (index: number) => void;
  onStartNavigation: () => void;
  onStopNavigation: () => void;
  showDirections: boolean;
  onToggleDirections: () => void;
  /** Drops the destination, the route and the typed query. */
  onClear: () => void;
  onSave: () => void;
  onShare: () => void;
}

/** Under the search bar: results first, then the route once you've picked one. */
function SearchResults({
  busy,
  error,
  results,
  routes,
  chosenRoute,
  onChooseRoute,
  mode,
  onChangeMode,
  destination,
  onChoose,
  locationStatus,
  fuel,
  navStep,
  guidance,
  offRoute,
  onReroute,
  onStepChange,
  onStartNavigation,
  onStopNavigation,
  showDirections,
  onToggleDirections,
  onClear,
  onSave,
  onShare,
}: SearchResultsProps): React.JSX.Element | null {
  const { colors, styles } = useMapTheme();

  if (busy) {
    return (
      <View style={styles.dropdown}>
        <ActivityIndicator color={colors.primary} />
      </View>
    );
  }

  if (error) {
    return (
      <View style={styles.dropdown}>
        <Text style={styles.dropdownError}>{error}</Text>
      </View>
    );
  }

  if (results.length > 0) {
    return (
      <View style={styles.dropdown}>
        {results.map((place, index) => (
          <Pressable
            key={`${place.latitude},${place.longitude},${index}`}
            onPress={() => onChoose(place)}
            style={styles.resultRow}
          >
            <Icon name="tabMap" size={16} color={colors.textMuted} />
            <View style={styles.resultInfo}>
              <Text style={styles.resultText} numberOfLines={1}>
                {place.label ?? 'Unnamed place'}
              </Text>
              {place.address ? (
                <Text style={styles.resultAddress} numberOfLines={1}>
                  {place.address}
                </Text>
              ) : null}
            </View>
          </Pressable>
        ))}
      </View>
    );
  }

  const route = routes[chosenRoute];
  if (!route || !destination) return null;

  // while navigating we show the next turn, like waze. no buttons to press,
  // it moves on by itself as you drive.
  if (navStep !== null && guidance) {
    return (
      <View style={styles.dropdown}>
        <View style={styles.turnCard}>
          <View style={styles.turnArrow}>
            <Icon name={guidance.icon} size={30} color={colors.surface} />
          </View>
          <View style={styles.turnWords}>
            <Text style={styles.turnDistance}>
              {guidance.arrived ? 'Arriving' : formatDistance(guidance.metresToTurn)}
            </Text>
            <Text style={styles.turnInstruction} numberOfLines={2}>
              {guidance.instruction}
            </Text>
          </View>
        </View>

        {guidance.then ? (
          <View style={styles.thenRow}>
            <Icon name={turnIcon(guidance.then.instruction)} size={14} color={colors.textMuted} />
            <Text style={styles.thenText} numberOfLines={1}>
              then {guidance.then.instruction}
            </Text>
          </View>
        ) : null}

        {offRoute ? (
          <Pressable onPress={onReroute} style={styles.offRouteBanner}>
            <Text style={styles.offRouteText}>
              You've gone off the route. Tap to redo it from here.
            </Text>
          </Pressable>
        ) : null}

        {/* how much of the trip is left */}
        <View style={styles.tripLeftRow}>
          <Text style={styles.tripLeftText}>
            {formatDistance(guidance.remainingM)} · {formatTravelDuration(guidance.remainingMin)} left
          </Text>
          <Pressable onPress={onStopNavigation} style={styles.endButton}>
            <Text style={styles.endButtonText}>End</Text>
          </Pressable>
        </View>

        {/* it moves on by itself while you're driving, but on a laptop nothing
            moves, so these let you step through the turns to look ahead */}
        <View style={styles.previewRow}>
          <Pressable
            onPress={() => onStepChange(Math.max(0, navStep - 1))}
            disabled={navStep === 0}
            style={[styles.previewButton, navStep === 0 && styles.previewButtonOff]}
          >
            <Text style={styles.previewButtonText}>Back</Text>
          </Pressable>
          {/* step 0 is just "start on X", not a turn, so don't count it */}
          <Text style={styles.previewCount}>
            {guidance.index} of {guidance.count - 1}
          </Text>
          <Pressable
            onPress={() => onStepChange(guidance.index)}
            disabled={guidance.isLast}
            style={[styles.previewButton, guidance.isLast && styles.previewButtonOff]}
          >
            <Text style={styles.previewButtonText}>Next</Text>
          </Pressable>
        </View>
      </View>
    );
  }

  return (
    <View style={styles.dropdown}>
      <View style={styles.panelHeader}>
        <Text style={styles.routeTo} numberOfLines={1}>
          {destination.label}
        </Text>
        <CloseButton onPress={onClear} />
      </View>

      {/* drive / walk / cycle */}
      <View style={styles.modeRow}>
        <SegmentedControl
          segments={MODES.map((m) => MODE_LABELS[m])}
          value={MODE_LABELS[mode]}
          onChange={(label) => {
            const picked = MODES.find((m) => MODE_LABELS[m] === label);
            if (picked && picked !== mode) onChangeMode(picked);
          }}
        />
      </View>

      {locationStatus === 'fallback' ? (
        <Text style={styles.fromNote}>From Melbourne CBD — location unavailable</Text>
      ) : null}

      <View style={styles.routeRow}>
        <Text style={styles.routeEta}>
          {route.eta_is_estimated ? 'about ' : ''}
          {formatTravelDuration(route.eta_minutes)}
        </Text>
        <Text style={styles.routeDistance}>{route.distance_km} km</Text>
        {/* ~ because it's an estimate */}
        {fuel && mode === 'driving' ? (
          <Text style={styles.routeFuel}>~${fuel.cost.toFixed(2)} fuel</Text>
        ) : null}
      </View>

      {/* the other routes OSRM found, if there are any */}
      {routes.length > 1 ? (
        <View style={styles.altRow}>
          {routes.map((option, index) => (
            <Pressable
              key={option.summary}
              onPress={() => onChooseRoute(index)}
              style={[styles.altChip, index === chosenRoute && styles.altChipOn]}
            >
              <Text
                style={[styles.altText, index === chosenRoute && styles.altTextOn]}
                numberOfLines={1}
              >
                {option.summary} · {formatTravelDuration(option.eta_minutes)}
              </Text>
            </Pressable>
          ))}
        </View>
      ) : null}

      {route.steps.length > 0 ? (
        <>
          <Pressable onPress={onStartNavigation} style={styles.startButton}>
            <Icon name="tabMap" size={16} color={colors.onAccent} />
            <Text style={styles.startButtonText}>Start navigation</Text>
          </Pressable>
          <Pressable onPress={onToggleDirections} style={styles.directionsToggle}>
            <Text style={styles.directionsToggleText}>
              {showDirections
                ? 'Hide directions'
                : `Show all ${route.steps.length} steps`}
            </Text>
          </Pressable>
        </>
      ) : null}
      <View style={styles.routeActions}>
        <Pressable onPress={onSave} style={styles.secondaryAction}><Icon name="star" size={15} color={colors.primary} /><Text style={styles.secondaryActionText}>Save</Text></Pressable>
        <Pressable onPress={onShare} style={styles.secondaryAction}><Icon name="liveShare" size={15} color={colors.primary} /><Text style={styles.secondaryActionText}>Share route</Text></Pressable>
      </View>
    </View>
  );
}

/**
 * The list of turns.
 *
 * Lives in the bottom sheet because the weather chip and SOS button were
 * covering it when it was up in the dropdown.
 */
function DirectionsCard({ route }: { route: RouteOption }): React.JSX.Element {
  const { styles } = useMapTheme();
  return (
    <Card>
      <SectionHeader title="Directions" />
      {route.steps.map((step, index) => (
        <View key={`${index}-${step.instruction}`} style={styles.stepRow}>
          <Text style={styles.stepNumber}>{index + 1}</Text>
          <View style={{ flex: 1 }}>
            <Text style={styles.stepText}>{step.instruction}</Text>
            {step.distance_m > 0 ? (
              <Text style={styles.stepDistance}>{formatDistance(step.distance_m)}</Text>
            ) : null}
          </View>
        </View>
      ))}
    </Card>
  );
}

/** 850 -> "850 m", 1400 -> "1.4 km" */
function formatDistance(metres: number): string {
  if (metres < 1000) return `${metres} m`;
  return `${(metres / 1000).toFixed(1)} km`;
}

function formatTravelDuration(totalMinutes: number): string {
  if (!Number.isFinite(totalMinutes)) return '—';
  const roundedMinutes = Math.max(0, Math.round(totalMinutes));
  const days = Math.floor(roundedMinutes / 1440);
  const hours = Math.floor((roundedMinutes % 1440) / 60);
  const minutes = roundedMinutes % 60;
  const parts = [];
  if (days) parts.push(`${days} ${days === 1 ? 'day' : 'days'}`);
  if (hours) parts.push(`${hours} hr`);
  if (minutes || parts.length === 0) parts.push(`${minutes} min`);
  return parts.join(' ');
}

function sameLocation(left: GeoLocation, right: GeoLocation): boolean {
  return left.latitude === right.latitude && left.longitude === right.longitude;
}

/** The x in the corner of the route panel — backs you out of the search. */
function CloseButton({ onPress }: { onPress: () => void }): React.JSX.Element {
  const { colors, styles } = useMapTheme();
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel="Clear search"
      hitSlop={8}
      onPress={onPress}
      style={({ pressed }) => [styles.closeButton, pressed && styles.pressed]}
    >
      <Icon name="close" size={16} color={colors.textMuted} />
    </Pressable>
  );
}

interface MapControlProps {
  icon: React.ComponentProps<typeof Icon>['name'];
  /** Read out by screen readers. Only needed on the ones you can press. */
  label?: string;
  onPress?: () => void;
}

function MapControl({ icon, label, onPress }: MapControlProps): React.JSX.Element {
  const { colors, styles } = useMapTheme();
  const glyph = <Icon name={icon} size={18} color={colors.text} />;

  // the ones we haven't wired up yet stay decoration rather than pretending
  // to be buttons
  if (!onPress) return <View style={styles.control}>{glyph}</View>;

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      onPress={onPress}
      style={({ pressed }) => [styles.control, pressed && styles.pressed]}
    >
      {glyph}
    </Pressable>
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
function SosGlow(): React.JSX.Element {
  const { colors } = useAppTheme();
  const tint = withAlpha(colors.emergency, SOS_GLOW_STEP_ALPHA);
  return (
    <>
      {SOS_GLOW_RINGS.map((size) => (
        <View
          key={size}
          style={{
            position: 'absolute',
            width: size,
            height: size,
            borderRadius: size / 2,
            backgroundColor: tint,
          }}
        />
      ))}
    </>
  );
}

/** Tolls, roadworks and charging stops. Hidden if there are none. */
function RoadAlertsCard({
  alerts,
}: {
  alerts: { tolls: string[]; works: string[]; charging: ChargingPlan | null };
}): React.JSX.Element | null {
  const { colors, styles } = useMapTheme();
  const needsCharging = (alerts.charging?.stops_needed ?? 0) > 0;
  if (!alerts.tolls.length && !alerts.works.length && !needsCharging) return null;

  return (
    <Card>
      <SectionHeader title="On your route" />

      {alerts.tolls.length ? (
        <View style={styles.alertRow}>
          <Icon name="car" size={16} color={colors.warning} />
          <View style={{ flex: 1 }}>
            <Text style={styles.alertTitle}>Toll roads</Text>
            <Text style={styles.alertBody} numberOfLines={2}>
              {alerts.tolls.slice(0, 3).join(', ')}
            </Text>
          </View>
        </View>
      ) : null}

      {alerts.works.length ? (
        <View style={styles.alertRow}>
          <Icon name="traffic" size={16} color={colors.warning} />
          <View style={{ flex: 1 }}>
            <Text style={styles.alertTitle}>Roadworks</Text>
            <Text style={styles.alertBody} numberOfLines={2}>
              {alerts.works.slice(0, 3).join(', ')}
            </Text>
          </View>
        </View>
      ) : null}

      {needsCharging && alerts.charging ? (
        <View style={styles.alertRow}>
          <Icon name="charging" size={16} color={colors.success} />
          <View style={{ flex: 1 }}>
            <Text style={styles.alertTitle}>
              {alerts.charging.stops_needed} charging stop
              {alerts.charging.stops_needed > 1 ? 's' : ''} needed
            </Text>
            <Text style={styles.alertBody} numberOfLines={2}>
              {alerts.charging.chargers.length
                ? alerts.charging.chargers.slice(0, 2).map((c) => c.name).join(', ')
                : `Based on ${alerts.charging.assumed_range_km} km range`}
            </Text>
          </View>
        </View>
      ) : null}
    </Card>
  );
}

/** The row of Food / Hospitals / Pharmacies chips under the search bar. */
function CategoryChips({
  selected, busy, onChoose,
}: {
  selected: NearbyCategory | null;
  busy: boolean;
  onChoose: (key: NearbyCategory) => void;
}): React.JSX.Element {
  const { colors, styles } = useMapTheme();
  return (
    <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.chipRow}>
      {NEARBY_CATEGORIES.map((cat) => {
        const on = selected === cat.key;
        return (
          <Pressable
            key={cat.key}
            onPress={() => onChoose(cat.key)}
            style={[styles.categoryChip, on && { backgroundColor: cat.colour, borderColor: cat.colour }]}
          >
            {on && busy ? (
              <ActivityIndicator size="small" color={colors.onAccent} />
            ) : (
              <Icon name={cat.icon} size={15} color={on ? colors.onAccent : cat.colour} />
            )}
            <Text style={[styles.categoryChipText, on && styles.categoryChipTextOn]}>{cat.label}</Text>
          </Pressable>
        );
      })}
    </ScrollView>
  );
}

/** What we found nearby, listed in the sheet. */
function NearbyCard({
  category, places, onChoose,
}: {
  category: NearbyCategory;
  places: NearbyPlace[];
  onChoose: (place: NearbyPlace) => void;
}): React.JSX.Element {
  const { styles } = useMapTheme();
  const info = categoryInfo(category);
  return (
    <Card>
      <SectionHeader title={`${info.label} nearby`} />
      {places.slice(0, 8).map((place, index) => (
        <Pressable key={`${place.name}-${index}`} onPress={() => onChoose(place)} style={styles.nearbyRow}>
          <View style={[styles.nearbyDot, { backgroundColor: info.colour }]} />
          <Text style={styles.nearbyName} numberOfLines={1}>{place.name}</Text>
          <Text style={styles.nearbyDistance}>{place.distance_km} km</Text>
        </Pressable>
      ))}
    </Card>
  );
}

function SavedPlacesCard({ onChoose }: { onChoose: (place: GeoLocation) => void }): React.JSX.Element {
  const { colors, styles } = useMapTheme();
  const data = useAppData();
  const places = data.profile.savedPlaces.filter((place) => place.kind !== 'recent').slice(0, 4);
  return <Card><SectionHeader title="Saved Places" /><View style={styles.savedRow}>{places.map((place) => <Pressable key={place.id} style={styles.savedChip} onPress={() => onChoose(place)}><Icon name={place.kind === 'home' ? 'home' : place.kind === 'work' ? 'work' : 'star'} size={16} color={colors.primary} /><Text style={styles.savedText} numberOfLines={1}>{place.label}</Text></Pressable>)}</View></Card>;
}

function UpcomingCard({ onNavigate }: { onNavigate: (place: GeoLocation) => void }): React.JSX.Element {
  const { styles } = useMapTheme();
  const data = useAppData();
  const [showAll, setShowAll] = useState(false);
  const events = showAll ? data.profile.calendarEvents : data.profile.calendarEvents.slice(0, 1);
  const toggleShowAll = () => {
    LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);
    setShowAll((value) => !value);
  };
  if (events.length === 0) return <></>;
  return (
    <Card>
      <SectionHeader title="Upcoming" action={showAll ? 'Show Less' : 'View All'} onAction={toggleShowAll} />
      {events.map((event) => {
        const when = new Date(event.startsAt);
        return (
          <View key={event.id} style={styles.upcomingEvent}>
            <View style={styles.upcomingRow}>
              <View style={styles.timeBox}>
                <Text style={styles.timeBig}>{when.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' }).replace(/\s?(am|pm)/i, '')}</Text>
                <Text style={styles.timeAmpm}>{when.toLocaleTimeString([], { hour: 'numeric' }).replace(/[0-9:\s]/g, '')}</Text>
              </View>
              <View style={{ flex: 1 }}>
                <Text style={styles.apptName}>{event.title}</Text>
                <Text style={styles.apptMeta}>{event.subtitle} · remind {event.reminderMinutes} min before</Text>
              </View>
            </View>
            <Button label="Start Navigation" icon="tabMap" size="sm" style={{ marginTop: spacing.sm }} onPress={() => onNavigate(event.location)} />
          </View>
        );
      })}
    </Card>
  );
}

const SOS_SIZE = 44;
/** Gap between the screen edge and the button, halo aside. */
const SOS_MARGIN = 22;
const SOS_GLOW_SIZE = 64;
/** Enough steps that the falloff reads as smooth rather than banded. */
const SOS_GLOW_STEPS = 12;
const SOS_GLOW_STEP_ALPHA = 0.055;
/** Ring diameters, outside in, stopping just shy of the button. */
const SOS_GLOW_RINGS = Array.from(
  { length: SOS_GLOW_STEPS },
  (_, ring) =>
    SOS_GLOW_SIZE - (ring * (SOS_GLOW_SIZE - (SOS_SIZE + 4))) / (SOS_GLOW_STEPS - 1),
);

function LiveSharingCard({ onSelect }: { onSelect: (person: LiveLocation) => void }): React.JSX.Element {
  const { colors, styles } = useMapTheme();
  const data = useAppData();
  const [showAll, setShowAll] = useState(false);
  const live = data.connections.filter((person) => person.status === 'connected' && person.isLive);
  const visibleLive = showAll ? live : live.slice(0, 3);
  const toggleShowAll = () => {
    LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);
    setShowAll((value) => !value);
  };
  return (
    <Card>
      <SectionHeader title="Live Sharing" action={showAll ? 'Show Less' : 'View All'} onAction={toggleShowAll} />
      <View style={styles.avatarRow}>
        {visibleLive.map((person) => (
          <Pressable key={person.id} style={styles.avatarItem} disabled={!person.location} accessibilityRole="button" accessibilityLabel={`Show ${person.name} on map`} onPress={() => person.location && onSelect({ ...person, location: person.location })}>
            <Avatar name={person.name} size={44} ring={colors.live} dot={colors.live} />
            <Text style={styles.avatarName}>{person.name}</Text>
            <Text style={styles.avatarLive}>Live</Text>
          </Pressable>
        ))}
        {!showAll && live.length > 3 ? <View style={styles.avatarItem}>
          <View style={styles.morePeople}>
            <Text style={styles.moreText}>+{live.length - 3}</Text>
          </View>
        </View> : null}
      </View>
    </Card>
  );
}

function LivePersonMenu({
  person,
  onClose,
  onNavigate,
  onMessage,
  onSos,
  onShareBack,
  onSafeArrival,
}: {
  person: LiveLocation;
  onClose: () => void;
  onNavigate: () => void;
  onMessage: () => void;
  onSos: () => void;
  onShareBack: () => void;
  onSafeArrival: () => void;
}): React.JSX.Element {
  const { colors, styles } = useMapTheme();
  const swipeResponder = React.useMemo(
    () =>
      PanResponder.create({
        onMoveShouldSetPanResponder: (_event, gesture) => gesture.dy > 10,
        onPanResponderRelease: (_event, gesture) => {
          if (gesture.dy > 40) onClose();
        },
      }),
    [onClose],
  );
  const actions = [
    { label: 'Navigate to person', detail: 'Get directions from your current location', icon: 'tabMap' as const, onPress: onNavigate },
    { label: 'Send message', detail: 'Let them know you are checking in', icon: 'send' as const, onPress: onMessage },
    { label: 'SOS', detail: 'Send your location to your emergency circle', icon: 'sos' as const, onPress: onSos, danger: true },
    { label: 'Share my location', detail: 'Give them live access to your location', icon: 'liveShare' as const, onPress: onShareBack },
    { label: 'Set safe arrival', detail: 'Get an alert when you reach your destination', icon: 'safeArrival' as const, onPress: onSafeArrival },
  ];

  return (
    <View {...swipeResponder.panHandlers}>
      <Card>
        <View style={styles.personMenuHeader}>
          <Avatar name={person.name} size={42} ring={colors.live} dot={colors.live} />
          <View style={styles.personMenuTitle}>
            <Text style={styles.personMenuName}>{person.name}</Text>
            <Text style={styles.personMenuMeta}>Live location · {person.lastUpdated}</Text>
          </View>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="Close person actions"
            accessibilityHint="Swipe down to return to the map menu"
            onPress={onClose}
            style={styles.closeButton}
          >
            <Text style={styles.chevron}>×</Text>
          </Pressable>
        </View>
        <Text style={styles.personLocation}>{person.location.label ?? 'Shared location'}</Text>
        <Text style={styles.swipeHint}>Swipe down to close</Text>
        <View style={styles.personActions}>
          {actions.map((action) => (
            <Pressable
              key={action.label}
              accessibilityRole="button"
              accessibilityLabel={action.label}
              onPress={action.onPress}
              style={({ pressed }) => [styles.personAction, pressed && styles.pressed]}
            >
              <Icon name={action.icon} size={19} color={action.danger ? colors.emergency : colors.primary} />
              <View style={styles.personActionText}>
                <Text style={[styles.personActionLabel, action.danger && { color: colors.emergency }]}>
                  {action.label}
                </Text>
                <Text style={styles.personActionDetail}>{action.detail}</Text>
              </View>
              <Text style={styles.chevron}>›</Text>
            </Pressable>
          ))}
        </View>
      </Card>
    </View>
  );
}

function EllySuggestsCard(): React.JSX.Element {
  const { colors, isDark, styles } = useMapTheme();
  const data = useAppData();
  const suggestion = data.suggestions[0];
  return (
    <Card
      style={{
        backgroundColor: colors.card,
        borderColor: colors.elly,
      }}
    >
      <View style={styles.suggestRow}>
        <IconChip icon="elly" color={colors.elly} />
        <View style={{ flex: 1 }}>
          <Text style={styles.suggestTitle}>ELLY Suggests</Text>
          <Text style={styles.suggestBody}>
            {suggestion?.detail ?? 'No new travel suggestions.'}
          </Text>
        </View>
        <Text style={styles.chevron}>›</Text>
      </View>
    </Card>
  );
}

function useMapTheme() {
  const { colors, isDark } = useAppTheme();
  const styles = React.useMemo(() => createStyles(colors, isDark), [colors, isDark]);
  return { colors, isDark, styles };
}

function createStyles(colors: ThemeColors, isDark: boolean) {
  return StyleSheet.create({
  dropdown: {
    marginTop: spacing.sm,
    backgroundColor: colors.card,
    borderRadius: radius.md,
    borderWidth: 1,
    borderColor: colors.border,
    paddingVertical: spacing.sm,
    paddingHorizontal: spacing.md,
    gap: spacing.xs,
    ...cardShadow(colors, isDark),
  },
  dropdownError: { fontSize: fontSize.sm, color: colors.textMuted },
  resultRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    paddingVertical: spacing.sm,
  },
  resultInfo: { flex: 1 },
  resultText: { fontSize: fontSize.md, color: colors.text },
  resultAddress: { fontSize: fontSize.sm, color: colors.textMuted, marginTop: 2 },
  routeTo: { flex: 1, fontSize: fontSize.md, fontWeight: '700', color: colors.text },
  panelHeader: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  closeButton: {
    width: 28,
    height: 28,
    borderRadius: 14,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.surfaceAlt,
  },
  pressed: { opacity: 0.6 },
  routeRow: {
    flexDirection: 'row',
    alignItems: 'baseline',
    gap: spacing.sm,
    marginTop: spacing.xs,
  },
  routeEta: { fontSize: fontSize.lg, fontWeight: '700', color: colors.primary },
  routeDistance: { fontSize: fontSize.sm, color: colors.textMuted },
  routeFuel: { fontSize: fontSize.sm, color: colors.textFaint },
  routeSummary: { fontSize: fontSize.sm, color: colors.textFaint },

  modeRow: { marginTop: spacing.sm },
  startButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.sm,
    marginTop: spacing.sm,
    paddingVertical: spacing.sm + 2,
    borderRadius: radius.pill,
    backgroundColor: colors.primary,
  },
  startButtonText: { color: colors.onAccent, fontSize: fontSize.md, fontWeight: '700' },
  // the big "500 m / turn left" card
  turnCard: { flexDirection: 'row', alignItems: 'center', gap: spacing.md },
  turnArrow: {
    width: 52,
    height: 52,
    borderRadius: radius.md,
    backgroundColor: colors.primary,
    alignItems: 'center',
    justifyContent: 'center',
  },
  turnWords: { flex: 1 },
  turnDistance: { fontSize: fontSize.xxl ?? fontSize.xl, fontWeight: '800', color: colors.text },
  turnInstruction: { fontSize: fontSize.md, color: colors.textMuted, marginTop: 2 },
  thenRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
    marginTop: spacing.sm,
    paddingTop: spacing.sm,
    borderTopWidth: 1,
    borderTopColor: colors.border,
  },
  thenText: { flex: 1, fontSize: fontSize.sm, color: colors.textMuted },
  tripLeftRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: spacing.md,
  },
  tripLeftText: { flex: 1, fontSize: fontSize.sm, fontWeight: '600', color: colors.text },
  endButton: {
    paddingVertical: spacing.xs + 2,
    paddingHorizontal: spacing.lg,
    borderRadius: radius.pill,
    borderWidth: 1,
    borderColor: colors.border,
  },
  endButtonText: { fontSize: fontSize.sm, fontWeight: '600', color: colors.emergency },
  // small "look ahead" controls, quieter than the turn card above them
  previewRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    marginTop: spacing.sm,
    paddingTop: spacing.sm,
    borderTopWidth: 1,
    borderTopColor: colors.border,
  },
  previewButton: {
    paddingVertical: spacing.xs,
    paddingHorizontal: spacing.md,
    borderRadius: radius.pill,
    borderWidth: 1,
    borderColor: colors.border,
  },
  debugBox: {
    position: 'absolute',
    top: 8,
    left: 8,
    padding: 8,
    borderRadius: 8,
    backgroundColor: 'rgba(0,0,0,0.78)',
    zIndex: 99,
  },
  debugText: { color: '#fff', fontSize: 11, fontFamily: 'monospace' },
  previewButtonOff: { opacity: 0.35 },
  previewButtonText: { fontSize: fontSize.xs, fontWeight: '600', color: colors.textMuted },
  previewCount: { flex: 1, textAlign: 'center', fontSize: fontSize.xs, color: colors.textFaint },
  offRouteBanner: {
    marginTop: spacing.sm,
    padding: spacing.sm,
    borderRadius: radius.md,
    backgroundColor: withAlpha(colors.warning, 0.15),
  },
  offRouteText: { fontSize: fontSize.sm, color: colors.text },
  fromNote: { fontSize: fontSize.xs, color: colors.textMuted, marginTop: spacing.xs },
  altRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.xs,
    marginTop: spacing.sm,
  },
  altChip: {
    paddingVertical: spacing.xs,
    paddingHorizontal: spacing.sm,
    borderRadius: radius.pill,
    borderWidth: 1,
    borderColor: colors.border,
  },
  altChipOn: {
    backgroundColor: withAlpha(colors.primary, 0.12),
    borderColor: colors.primary,
  },
  altText: { fontSize: fontSize.xs, color: colors.textMuted },
  altTextOn: { color: colors.primary, fontWeight: '700' },
  directionsToggle: { marginTop: spacing.sm },
  directionsToggleText: {
    fontSize: fontSize.sm,
    color: colors.primary,
    fontWeight: '600',
  },
  routeActions: { flexDirection: 'row', gap: spacing.sm, marginTop: spacing.sm },
  secondaryAction: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: spacing.xs, flex: 1, paddingVertical: spacing.sm, borderWidth: 1, borderColor: colors.border, borderRadius: radius.pill },
  secondaryActionText: { color: colors.primary, fontSize: fontSize.sm, fontWeight: '700' },
  stepRow: {
    flexDirection: 'row',
    gap: spacing.sm,
    paddingVertical: spacing.sm,
    borderTopWidth: 1,
    borderTopColor: colors.border,
  },
  stepNumber: {
    fontSize: fontSize.xs,
    color: colors.textFaint,
    width: 18,
    textAlign: 'right',
  },
  stepText: { fontSize: fontSize.sm, color: colors.text },
  stepDistance: { fontSize: fontSize.xs, color: colors.textMuted, marginTop: 2 },
  root: { flex: 1, backgroundColor: colors.mapBackdrop },
  overlay: { flex: 1 },
  top: { paddingHorizontal: spacing.md, gap: spacing.md },
  mapArea: { flex: 1, position: 'relative' },
  controls: { position: 'absolute', right: spacing.md, top: spacing.md, gap: spacing.sm },
  control: {
    width: 40,
    height: 40,
    borderRadius: radius.md,
    backgroundColor: colors.card,
    alignItems: 'center',
    justifyContent: 'center',
    ...cardShadow(colors, isDark),
  },
  layersMenu: {
    position: 'absolute',
    right: spacing.md,
    top: spacing.md + 48,
    width: 220,
    backgroundColor: colors.card,
    borderRadius: radius.lg,
    borderWidth: 1,
    borderColor: colors.border,
    padding: spacing.md,
    ...cardShadow(colors, isDark),
  },
  layersTitle: {
    fontSize: fontSize.md,
    fontWeight: '700',
    color: colors.text,
    marginBottom: spacing.md,
  },
  layersRow: {
    flexDirection: 'row',
    gap: spacing.md,
  },
  layerItem: {
    flex: 1,
    gap: spacing.xs,
  },
  layerPreview: {
    height: 64,
    borderRadius: radius.md,
    borderWidth: 1,
    borderColor: colors.border,
    backgroundColor: colors.surfaceAlt,
    alignItems: 'center',
    justifyContent: 'center',
  },
  layerPreviewSelected: {
    borderWidth: 2,
    borderColor: colors.primary,
  },
  layerLabel: {
    fontSize: fontSize.sm,
    fontWeight: '600',
    color: colors.textMuted,
    textAlign: 'center',
  },
  layerLabelSelected: {
    color: colors.primary,
    fontWeight: '700',
  },
  weatherChip: {
    position: 'absolute',
    left: spacing.md,
    bottom: spacing.md,
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
    backgroundColor: colors.card,
    borderRadius: radius.pill,
    paddingVertical: 8,
    paddingHorizontal: spacing.md,
    ...cardShadow(colors, isDark),
  },
  weatherTemp: { fontSize: fontSize.md, fontWeight: '700', color: colors.text },
  aqiDot: { width: 6, height: 6, borderRadius: 3, backgroundColor: colors.success, marginHorizontal: 3 },
  weatherAqi: { fontSize: fontSize.sm, color: colors.textMuted, fontWeight: '600' },

  sosWrap: {
    position: 'absolute',
    // Sized to the halo rather than the button so Android can't clip the
    // outer rings, then pulled out by the overhang to leave the button
    // itself exactly where it was.
    right: SOS_MARGIN - (SOS_GLOW_SIZE - SOS_SIZE) / 2,
    bottom: SOS_MARGIN - (SOS_GLOW_SIZE - SOS_SIZE) / 2,
    width: SOS_GLOW_SIZE,
    height: SOS_GLOW_SIZE,
    alignItems: 'center',
    justifyContent: 'center',
  },
  sos: {
    width: SOS_SIZE,
    height: SOS_SIZE,
    borderRadius: SOS_SIZE / 2,
    backgroundColor: colors.emergency,
    alignItems: 'center',
    justifyContent: 'center',
    // The rings above carry the glow now, so this is pulled back to a soft
    // lift under the button rather than a second halo on top of the first.
    shadowColor: colors.emergency,
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 8,
  },
  sosText: { color: colors.onAccent, fontWeight: '800', fontSize: fontSize.sm },

  sheet: {
    backgroundColor: colors.background,
    borderTopLeftRadius: radius.lg + 4,
    borderTopRightRadius: radius.lg + 4,
    overflow: 'hidden',
    ...cardShadow(colors, isDark),
    shadowOffset: { width: 0, height: -4 },
  },
  personSheet: {
    position: 'absolute', left: 0, right: 0, bottom: 0,
    backgroundColor: colors.background,
    borderTopLeftRadius: radius.lg + 4, borderTopRightRadius: radius.lg + 4,
    paddingTop: spacing.xs, paddingHorizontal: spacing.md,
    ...cardShadow(colors, isDark), shadowOffset: { width: 0, height: -4 },
  },
  personSheetHandle: { height: 28, alignItems: 'center', justifyContent: 'center' },
  personMenuHeader: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  personMenuTitle: { flex: 1 },
  personMenuName: { fontSize: fontSize.md, fontWeight: '800', color: colors.text },
  personMenuMeta: { fontSize: fontSize.xs, color: colors.live, marginTop: 2 },
  swipeHint: { fontSize: fontSize.xs, color: colors.textFaint, textAlign: 'center', marginTop: spacing.sm },
  personActions: { marginTop: spacing.sm },
  personAction: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    minHeight: 52,
    borderTopWidth: 1,
    borderTopColor: colors.border,
  },
  personActionText: { flex: 1 },
  personActionLabel: { fontSize: fontSize.md, fontWeight: '700', color: colors.text },
  personActionDetail: { fontSize: fontSize.xs, color: colors.textMuted, marginTop: 2 },
  personLocation: { fontSize: fontSize.sm, color: colors.textMuted, marginTop: spacing.sm },
  handleButton: { height: 28 },
  handlePressable: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  handle: {
    width: 40,
    height: 5,
    borderRadius: 3,
    backgroundColor: colors.borderStrong,
  },
  sheetContent: { paddingHorizontal: spacing.md, paddingBottom: spacing.lg, gap: spacing.md },

  chipRow: { gap: spacing.xs, paddingRight: spacing.md },
  categoryChip: {
    flexDirection: 'row', alignItems: 'center', gap: spacing.xs,
    paddingVertical: spacing.xs + 2, paddingHorizontal: spacing.sm + 2,
    borderRadius: radius.pill, borderWidth: 1,
    borderColor: colors.border, backgroundColor: colors.card,
  },
  categoryChipText: { fontSize: fontSize.sm, color: colors.text, fontWeight: '600' },
  categoryChipTextOn: { color: colors.onAccent },
  nearbyRow: {
    flexDirection: 'row', alignItems: 'center', gap: spacing.sm,
    paddingVertical: spacing.sm, borderTopWidth: 1, borderTopColor: colors.border,
  },
  nearbyDot: { width: 10, height: 10, borderRadius: 5 },
  nearbyName: { flex: 1, fontSize: fontSize.md, color: colors.text },
  nearbyDistance: { fontSize: fontSize.sm, color: colors.textMuted },
  alertRow: {
    flexDirection: 'row', gap: spacing.sm, alignItems: 'flex-start',
    paddingVertical: spacing.sm, borderTopWidth: 1, borderTopColor: colors.border,
  },
  alertTitle: { fontSize: fontSize.sm, fontWeight: '600', color: colors.text },
  alertBody: { fontSize: fontSize.xs, color: colors.textMuted, marginTop: 2 },
  searchDock: { gap: spacing.xs },
  savedRow: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
  savedChip: { flexDirection: 'row', alignItems: 'center', gap: spacing.xs, maxWidth: '48%', backgroundColor: colors.surfaceAlt, borderRadius: radius.pill, paddingVertical: spacing.sm, paddingHorizontal: spacing.md },
  savedText: { color: colors.text, fontSize: fontSize.sm, fontWeight: '600', flexShrink: 1 },

  upcomingRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.md },
  timeBox: {
    backgroundColor: withAlpha(colors.primary, 0.1),
    borderRadius: radius.md,
    paddingVertical: spacing.sm,
    paddingHorizontal: spacing.md,
    alignItems: 'center',
  },
  timeBig: { fontSize: fontSize.lg, fontWeight: '800', color: colors.primary },
  timeAmpm: { fontSize: fontSize.xs, fontWeight: '700', color: colors.primary },
  apptName: { fontSize: fontSize.md, fontWeight: '700', color: colors.text },
  apptMeta: { fontSize: fontSize.sm, color: colors.textMuted, marginTop: 2 },

  avatarRow: { flexDirection: 'row', flexWrap: 'wrap', columnGap: spacing.xl, rowGap: spacing.md, justifyContent: 'flex-start', marginTop: spacing.xs },
  avatarItem: { alignItems: 'center', gap: 3 },
  upcomingEvent: { marginTop: spacing.sm },
  avatarName: { fontSize: fontSize.xs + 1, fontWeight: '600', color: colors.text },
  avatarLive: { fontSize: fontSize.xs, color: colors.live, fontWeight: '700' },
  morePeople: {width: 44, height: 44, borderRadius: 22, backgroundColor: colors.surfaceAlt, alignItems: 'center', justifyContent: 'center'},
  moreText: { fontSize: fontSize.md, fontWeight: '700', color: colors.textMuted },

  ellySuggestButton: {position: 'absolute', right: spacing.md, top: spacing.md + 96, width: 40, height: 40, borderRadius: radius.md,  backgroundColor: colors.card, alignItems: 'center', justifyContent: 'center', ...cardShadow(colors, isDark)},
  ellySuggestPopup: {position: 'absolute', right: spacing.md + 48, top: spacing.md + 96, width: 360, maxWidth: '70%', backgroundColor: colors.card, borderRadius: radius.lg, borderWidth: 1, borderColor: colors.border, padding: spacing.md, ...cardShadow(colors, isDark)},
  
  suggestRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.md },
  suggestTitle: { fontSize: fontSize.md, fontWeight: '700', color: colors.elly },
  suggestBody: { fontSize: fontSize.sm, color: colors.text, marginTop: 2, lineHeight: 18 },
  chevron: { fontSize: 24, color: colors.textFaint },
  });
}