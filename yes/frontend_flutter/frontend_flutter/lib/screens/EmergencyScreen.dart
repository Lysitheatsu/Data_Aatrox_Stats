import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Icon;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/index.dart';
import '../theme/index.dart';
import '../theme/ThemeProvider.dart';
import '../data/AppDataProvider.dart';
import '../theme/icons.dart';
import '../api/client.dart';

const USE_MOCK_DATA =
  String.fromEnvironment('EXPO_PUBLIC_DATA_SOURCE') != 'api';

const Map<String, String> emergencyNumbers = {
  'AU': '000',
  'US': '911',
  'CA': '911',
  'GB': '999',
  'NZ': '111',
  'DE': '112',
  'FR': '112',
};

class NearbyPlace {
  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final double distance;
  String type;

  NearbyPlace({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.distance,
    required this.type,
  });
}

String getCountryCode() {
  if (kIsWeb) {
    try {
      final region =
        WidgetsBinding.instance.platformDispatcher.locale.countryCode;
      if (region != null && region.isNotEmpty) {
        return region.toUpperCase();
      }
    } catch (_) {
      return '';
    }
  }
  return '';
}

String? getEmergencyNumber(String countryCode) {
  return emergencyNumbers[countryCode];
}

/** Module 3 — SOS & Emergency. */
class EmergencyScreen extends HookWidget {
  final ValueChanged<GeoLocation>? onOpenMapLocation;

  const EmergencyScreen({super.key, this.onOpenMapLocation});

  @override
  Widget build(BuildContext context) {
    final theme = useAppTheme(context);
    final colors = theme.colors;
    final isDark = theme.isDark;
    final styles = _createStyles(colors, isDark);
    final data = useAppData(context);
    final sosStatus = useState('Protection active');
    final isListening = useState(false);
    final gpsLive = useState(true);
    final showConfirm = useState(false);
    final showContacts = useState(false);
    final showProcess = useState(false);
    final selectedService = useState('Emergency help');
    final contactName = useTextEditingController();
    final contactPhone = useTextEditingController();
    final nearbyHospitals = useState<List<NearbyPlace>>([]);
    final nearbyClinics = useState<List<NearbyPlace>>([]);
    final nearbyPharmacies = useState<List<NearbyPlace>>([]);
    final nearbyBloodBanks = useState<List<NearbyPlace>>([]);
    final healthLoading = useState(false);
    final recognitionRef = useRef<SpeechToText?>(null);
    final countryCode = getCountryCode();
    final emergencyNumber = getEmergencyNumber(countryCode);

    void showMessage(String title, String message) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
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

    double getDistance(
      double lat1,
      double lon1,
      double lat2,
      double lon2,
    ) {
      const earthRadius = 6371;
      final latDifference = (lat2 - lat1) * math.pi / 180;
      final lonDifference = (lon2 - lon1) * math.pi / 180;
      final a =
        math.sin(latDifference / 2) * math.sin(latDifference / 2) +
        math.cos(lat1 * math.pi / 180) *
        math.cos(lat2 * math.pi / 180) *
        math.sin(lonDifference / 2) *
        math.sin(lonDifference / 2);
      final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
      return earthRadius * c;
    }

    String formatHealthDistance(double distance) {
      if (distance < 1) {
        final metres = (distance * 1000).round();
        return '$metres m away';
      }

      return '${distance.toStringAsFixed(1)} km away';
    }

    Future<void> getNearbyHealthServices() async {
      if (!kIsWeb) {
        return;
      }

      healthLoading.value = true;

      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: WebSettings(
            accuracy: LocationAccuracy.high,
            maximumAge: Duration(minutes: 1),
            timeLimit: Duration(seconds: 4),
          ),
        );
        final latitude = position.latitude;
        final longitude = position.longitude;
        const radius = 5000;

        final query = '''
          [out:json][timeout:25];
          (
            node["amenity"="hospital"](around:$radius,$latitude,$longitude);
            way["amenity"="hospital"](around:$radius,$latitude,$longitude);
            relation["amenity"="hospital"](around:$radius,$latitude,$longitude);
            node["amenity"="clinic"](around:$radius,$latitude,$longitude);
            way["amenity"="clinic"](around:$radius,$latitude,$longitude);
            relation["amenity"="clinic"](around:$radius,$latitude,$longitude);
            node["amenity"="pharmacy"](around:$radius,$latitude,$longitude);
            way["amenity"="pharmacy"](around:$radius,$latitude,$longitude);
            relation["amenity"="pharmacy"](around:$radius,$latitude,$longitude);
            node["healthcare"="blood_donation"](around:$radius,$latitude,$longitude);
            way["healthcare"="blood_donation"](around:$radius,$latitude,$longitude);
            relation["healthcare"="blood_donation"](around:$radius,$latitude,$longitude);
          );
          out center tags;
        ''';

        try {
          const endpoints = [
            'https://lz4.overpass-api.de/api/interpreter',
            'https://overpass-api.de/api/interpreter',
          ];
          http.Response? response;

          for (final endpoint in endpoints) {
            try {
              final candidate = await http.post(
                Uri.parse(endpoint),
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                body: 'data=${Uri.encodeQueryComponent(query)}',
              ).timeout(const Duration(seconds: 8));

              if (candidate.statusCode >= 200 && candidate.statusCode < 300) {
                response = candidate;
                break;
              }
            } catch (_) {}
          }

          if (response == null) {
            throw Exception('Could not load nearby services.');
          }

          final result = jsonDecode(response.body);
          final hospitals = <NearbyPlace>[];
          final clinics = <NearbyPlace>[];
          final pharmacies = <NearbyPlace>[];
          final bloodBanks = <NearbyPlace>[];
          for (final item in result['elements']) {
            double? placeLatitude = (item['lat'] as num?)?.toDouble();
            double? placeLongitude = (item['lon'] as num?)?.toDouble();
            if (item['center'] != null) {
              placeLatitude = (item['center']['lat'] as num?)?.toDouble();
              placeLongitude = (item['center']['lon'] as num?)?.toDouble();
            }
            if (placeLatitude == null || placeLongitude == null) {
              continue;
            }
            var name = 'Unnamed location';
            if (item['tags']?['name'] != null) {
              name = item['tags']['name'];
            } else if (item['tags']?['brand'] != null) {
              name = item['tags']['brand'];
            }
            final distance = getDistance(
              latitude,
              longitude,
              placeLatitude,
              placeLongitude,
            );
            final place = NearbyPlace(
              id: (item['id'] as num).toInt(),
              name: name,
              latitude: placeLatitude,
              longitude: placeLongitude,
              distance: distance,
              type: '',
            );
            if (item['tags']?['amenity'] == 'hospital') {
              place.type = 'hospital';
              hospitals.add(place);
            }
            if (item['tags']?['amenity'] == 'clinic') {
              place.type = 'clinic';
              clinics.add(place);
            }
            if (item['tags']?['amenity'] == 'pharmacy') {
              place.type = 'pharmacy';
              pharmacies.add(place);
            }
            if (item['tags']?['healthcare'] == 'blood_donation') {
              place.type = 'blood_donation';
              bloodBanks.add(place);
            }
          }

          hospitals.sort((a, b) => a.distance.compareTo(b.distance));
          clinics.sort((a, b) => a.distance.compareTo(b.distance));
          pharmacies.sort((a, b) => a.distance.compareTo(b.distance));
          bloodBanks.sort((a, b) => a.distance.compareTo(b.distance));
          nearbyHospitals.value = hospitals;
          nearbyClinics.value = clinics;
          nearbyPharmacies.value = pharmacies;
          nearbyBloodBanks.value = bloodBanks;
        } catch (_) {
          showMessage(
            'Health Services',
            'Could not load nearby health services.',
          );
        }
        healthLoading.value = false;
      } catch (_) {
        healthLoading.value = false;
        showMessage(
          'Location',
          'ELLY could not get your current location.',
        );
      }
    }

    void openHealthService(NearbyPlace? place) {
      if (place == null) {
        showMessage(
          'Health Services',
          'No nearby location was found.',
        );
        return;
      }

      final location = GeoLocation(
        label: place.name,
        latitude: place.latitude,
        longitude: place.longitude,
      );

      if (onOpenMapLocation != null) {
        onOpenMapLocation!(location);
        return;
      }

      Navigator.of(context).pushNamed(
        'Map',
        arguments: {
          'focusLocation': location,
        },
      );
    }

    Future<dynamic> sendSosToBackend(
      String type,
      double latitude,
      double longitude,
      double accuracy,
    ) async {
      final id = DateTime.now().millisecondsSinceEpoch.toString();

      final data = {
        'packet_id': 'packet_$id',
        'session_id': 'session_$id',
        'user_id': 'demo_user',
        'generated_at': DateTime.now().toUtc().toIso8601String(),
        'packet_version': '2.0',
        'sequence_number': 1,
        'status': 'QUEUED',
        'priority': 'CRITICAL',
        'packet_hash': 'sos_$id',
        'packet_checksum': 'sos_$id',
        'location': {
          'latitude': latitude,
          'longitude': longitude,
          'accuracy': accuracy,
        },
        'transcript': {
          'text': type == 'voice' ? 'Voice SOS detected' : 'Manual SOS button pressed',
          'confidence': 1,
          'language': 'en',
          'is_partial': false,
          'speech_probability': 1,
          'parsed_intent': 'EMERGENCY',
          'matched_keywords': type == 'voice' ? ['help', 'help', 'help'] : ['SOS'],
        },
      };

      final response = await http.post(
        Uri.parse('$API_BASE_URL/v1/emergency/dispatch'),
        headers: { 'Content-Type': 'application/json' },
        body: jsonEncode(data),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(response.body);
      }

      return jsonDecode(response.body);
    }

    late final void Function() callEmergency;

    Future<void> activateSos(String type) async {
      if (type == 'manual' || USE_MOCK_DATA) {
        if (type == 'voice') selectedService.value = 'Voice-detected emergency';
        showConfirm.value = true;
        return;
      }
      if (type == 'voice') {
        sosStatus.value = 'Voice SOS detected';
      } else {
        sosStatus.value = 'Preparing emergency alert...';
      }

      if (kIsWeb) {
        try {
          final position = await Geolocator.getCurrentPosition();

          try {
            final latitude = position.latitude;
            final longitude = position.longitude;
            final accuracy = position.accuracy;

            sosStatus.value = 'Sending emergency alert...';

            final result = await sendSosToBackend(
              type,
              latitude,
              longitude,
              accuracy,
            );

            sosStatus.value = 'SOS sent · ${result['confirmation_code']}';
            callEmergency();
          } catch (_) {
            sosStatus.value = 'Could not send SOS to the server.';
            showMessage('SOS', 'Could not send SOS information to the server.');
          }
        } catch (_) {
          sosStatus.value = 'Could not get your location.';
          showMessage('Location', 'ELLY could not get your current location.');
        }
        return;
      }

      callEmergency();
    }

    callEmergency = () {
      if (emergencyNumber != null) {
        showMessage('Emergency', 'Opening phone dialler.');
        launchUrl(Uri.parse('tel:$emergencyNumber'));
      } else {
        showMessage('Emergency', 'Emergency number not found.');
      }
    };

    Future<void> stopVoiceDetection() async {
      if (recognitionRef.value != null) {
        await recognitionRef.value!.stop();
        recognitionRef.value = null;
      }
      isListening.value = false;
    }

    Future<void> startVoiceDetection() async {
      if (!kIsWeb) {
        sosStatus.value = 'Voice SOS only works on the web version.';
        return;
      }

      if (isListening.value) {
        await stopVoiceDetection();
        return;
      }

      final recognition = SpeechToText();
      final available = await recognition.initialize(
        onError: (_) {
          recognitionRef.value = null;
          isListening.value = false;
          sosStatus.value = 'Voice detection stopped. Please try again.';
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            recognitionRef.value = null;
            isListening.value = false;
          }
        },
      );

      if (!available) {
        sosStatus.value = 'Voice detection is not supported in this browser.';
        return;
      }

      recognitionRef.value = recognition;
      await recognition.listen(
        localeId: 'en_AU',
        onResult: (event) {
          var words = event.recognizedWords;

          words = words.toLowerCase().trim();

          if (words.contains('help help help')) {
            activateSos('voice');
            recognition.stop();
          }
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
        ),
      );
      isListening.value = true;
      sosStatus.value = 'Listening for help help help...';
    }

    void openEmergencyService(String service) {
      selectedService.value = service;
      showConfirm.value = true;
    }

    Future<void> shareLiveLocation() async {
      if (kIsWeb) {
        try {
          final position = await Geolocator.getCurrentPosition();
          final latitude = position.latitude;
          final longitude = position.longitude;
          final locationUrl =
            'https://www.openstreetmap.org/?mlat=$latitude&mlon=$longitude';

          showMessage('Share Live Location', locationUrl);
        } catch (_) {
          showMessage('Location', 'ELLY could not get your current location.');
        }
        return;
      }

      showMessage('Share Live Location', 'Location sharing will open here.');
    }

    void viewSosCircle() {
      showContacts.value = true;
    }

    void simulateSos() {
      showConfirm.value = false;
      sosStatus.value = 'DEMO ONLY · ${selectedService.value} alert simulated';
      showMessage('Demo SOS completed', 'No emergency service was contacted. ${data.profile.emergencyContacts.where((item) => item.inSosCircle).length} SOS Circle contacts would be notified.');
    }

    void addContact() {
      if (contactName.text.trim().isEmpty || contactPhone.text.trim().isEmpty) return;
      data.addEmergencyContact((
        name: contactName.text.trim(),
        phone: contactPhone.text.trim(),
        relationship: 'Contact',
        inSosCircle: true,
      ));
      contactName.clear();
      contactPhone.clear();
    }

    var hospitalText = 'No hospitals found nearby';
    var clinicText = 'No clinics found nearby';
    var pharmacyText = 'No pharmacies found nearby';
    var bloodBankText = 'No blood banks found nearby';

    if (healthLoading.value) {
      hospitalText = 'Finding hospitals near you...';
      clinicText = 'Finding clinics near you...';
      pharmacyText = 'Finding pharmacies near you...';
      bloodBankText = 'Finding blood banks near you...';
    } else {
      if (nearbyHospitals.value.isNotEmpty) {
        hospitalText =
          '${nearbyHospitals.value[0].name} · ${formatHealthDistance(nearbyHospitals.value[0].distance)}';
      }
      if (nearbyClinics.value.isNotEmpty) {
        clinicText =
          '${nearbyClinics.value[0].name} · ${formatHealthDistance(nearbyClinics.value[0].distance)}';
      }
      if (nearbyPharmacies.value.isNotEmpty) {
        pharmacyText =
          '${nearbyPharmacies.value[0].name} · ${formatHealthDistance(nearbyPharmacies.value[0].distance)}';
      }
      if (nearbyBloodBanks.value.isNotEmpty) {
        bloodBankText =
          '${nearbyBloodBanks.value[0].name} · ${formatHealthDistance(nearbyBloodBanks.value[0].distance)}';
      }
    }

    useEffect(() {
      getNearbyHealthServices();
      return null;
    }, const []);

    useEffect(() {
      return () {
        recognitionRef.value?.stop();
      };
    }, const []);

    return Stack(
      children: [
        Screen(
          children: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Header(
                title: 'Emergency',
                titleColor: colors.emergency,
                rightIcon: 'shield',
                rightIconColor: colors.text,
              ),

              SizedBox(height: spacing.md),

              Container(
                constraints: BoxConstraints(
                  minHeight: styles.sosBanner.minHeight,
                ),
                padding: EdgeInsets.only(
                  left: styles.sosBanner.paddingLeft,
                  right: styles.sosBanner.paddingRight,
                ),
                decoration: BoxDecoration(
                  color: styles.sosBanner.backgroundColor,
                  borderRadius: BorderRadius.circular(styles.sosBanner.borderRadius),
                  boxShadow: styles.sosBanner.boxShadow,
                ),
                clipBehavior: Clip.hardEdge,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('In an emergency?', style: styles.sosTitle),
                          SizedBox(height: styles.sosText.marginTop),
                          Text("We're here to help.", style: styles.sosText.textStyle),
                        ],
                      ),
                    ),

                    Transform.translate(
                      offset: Offset(styles.sosOuterCircle.marginRight, 0),
                      child: Container(
                        width: styles.sosOuterCircle.width,
                        height: styles.sosOuterCircle.height,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: styles.sosOuterCircle.backgroundColor,
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          width: styles.sosMiddleCircle.width,
                          height: styles.sosMiddleCircle.height,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: styles.sosMiddleCircle.backgroundColor,
                          ),
                          alignment: Alignment.center,
                          child: GestureDetector(
                            onTap: () => activateSos('manual'),
                            child: Container(
                              width: styles.sosButton.width,
                              height: styles.sosButton.height,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: styles.sosButton.backgroundColor,
                                boxShadow: styles.sosButton.boxShadow,
                              ),
                              alignment: Alignment.center,
                              child: Text('SOS', style: styles.sosButtonText),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: styles.sectionRow.marginTop),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Quick Actions', style: styles.sectionTitle),
                  GestureDetector(
                    onTap: startVoiceDetection,
                    child: Text(
                      isListening.value ? 'Stop Voice SOS' : 'Voice SOS',
                      style: styles.voiceText,
                    ),
                  ),
                ],
              ),

              SizedBox(height: styles.sectionRow.marginBottom),

              LayoutBuilder(
                builder: (context, constraints) {
                  int columns = 1;

                  if (constraints.maxWidth >= 720) {
                    columns = 3;
                  } else if (constraints.maxWidth >= 320) {
                    columns = 2;
                  }

                  final gap = styles.quickGrid.gap;
                  final totalGap = gap * (columns - 1);
                  final availableWidth = constraints.maxWidth - totalGap;
                  final itemWidth =
                    availableWidth > 0 ? availableWidth / columns : 0.0;

                  return Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: styles.quickGrid.gap,
                    runSpacing: styles.quickGrid.gap,
                    children: [
                      SizedBox(
                        width: itemWidth,
                        child: EmergencyAction(
                          context: context,
                          icon: 'ambulance',
                          title: 'Ambulance',
                          color: colors.emergency,
                          onPress: () => openEmergencyService('Ambulance'),
                        ),
                      ),

                      SizedBox(
                        width: itemWidth,
                        child: EmergencyAction(
                          context: context,
                          icon: 'police',
                          title: 'Police',
                          color: colors.primary,
                          onPress: () => openEmergencyService('Police'),
                        ),
                      ),

                      SizedBox(
                        width: itemWidth,
                        child: EmergencyAction(
                          context: context,
                          icon: 'fire',
                          title: 'Fire',
                          color: colors.warning,
                          onPress: () => openEmergencyService('Fire'),
                        ),
                      ),

                      SizedBox(
                        width: itemWidth,
                        child: EmergencyAction(
                          context: context,
                          icon: 'roadside',
                          title: 'Roadside Assistance',
                          color: colors.elly,
                          onPress: () => openEmergencyService('Roadside Assistance'),
                        ),
                      ),

                      SizedBox(
                        width: itemWidth,
                        child: EmergencyAction(
                          context: context,
                          icon: 'shareLocation',
                          title: 'Share Live Location',
                          color: colors.success,
                          onPress: shareLiveLocation,
                        ),
                      ),

                      SizedBox(
                        width: itemWidth,
                        child: EmergencyAction(
                          context: context,
                          icon: 'contacts',
                          title: 'Emergency Contacts',
                          color: colors.elly,
                          onPress: viewSosCircle,
                        ),
                      ),
                    ],
                  );
                },
              ),

              SizedBox(height: styles.healthSectionTitle.marginTop),

              Text('Health Services', style: styles.healthSectionTitle.textStyle),

              SizedBox(height: styles.healthSectionTitle.marginBottom),

              Container(
                decoration: BoxDecoration(
                  color: styles.healthCard.backgroundColor,
                  borderRadius: BorderRadius.circular(styles.healthCard.borderRadius),
                  border: Border.all(
                    width: styles.healthCard.borderWidth,
                    color: styles.healthCard.borderColor,
                  ),
                  boxShadow: styles.healthCard.boxShadow,
                ),
                clipBehavior: Clip.hardEdge,
                child: Column(
                  children: [
                    HealthService(
                      context: context,
                      icon: 'hospital',
                      symbol: 'H',
                      title: 'Nearest Hospital',
                      text: hospitalText,
                      color: colors.emergency,
                      onPress: () => openHealthService(
                        nearbyHospitals.value.isNotEmpty
                          ? nearbyHospitals.value[0]
                          : null,
                      ),
                    ),

                    Container(
                      height: styles.divider.height,
                      margin: EdgeInsets.only(left: styles.divider.marginLeft),
                      color: styles.divider.backgroundColor,
                    ),

                    HealthService(
                      context: context,
                      icon: 'clinic',
                      title: 'Nearby Clinics',
                      text: clinicText,
                      color: colors.success,
                      onPress: () => openHealthService(
                        nearbyClinics.value.isNotEmpty
                          ? nearbyClinics.value[0]
                          : null,
                      ),
                    ),

                    Container(
                      height: styles.divider.height,
                      margin: EdgeInsets.only(left: styles.divider.marginLeft),
                      color: styles.divider.backgroundColor,
                    ),

                    HealthService(
                      context: context,
                      icon: 'pharmacy',
                      symbol: '+',
                      title: 'Pharmacies',
                      text: pharmacyText,
                      color: colors.success,
                      onPress: () => openHealthService(
                        nearbyPharmacies.value.isNotEmpty
                          ? nearbyPharmacies.value[0]
                          : null,
                      ),
                    ),

                    Container(
                      height: styles.divider.height,
                      margin: EdgeInsets.only(left: styles.divider.marginLeft),
                      color: styles.divider.backgroundColor,
                    ),

                    HealthService(
                      context: context,
                      icon: 'bloodBank',
                      title: 'Blood Banks',
                      text: bloodBankText,
                      color: colors.emergency,
                      onPress: () => openHealthService(
                        nearbyBloodBanks.value.isNotEmpty
                          ? nearbyBloodBanks.value[0]
                          : null,
                      ),
                    ),

                    Container(
                      height: styles.divider.height,
                      margin: EdgeInsets.only(left: styles.divider.marginLeft),
                      color: styles.divider.backgroundColor,
                    ),

                    GestureDetector(
                      onTap: getNearbyHealthServices,
                      child: Container(
                        constraints: BoxConstraints(
                          minHeight: styles.moreServices.minHeight,
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Refresh Nearby Services', style: styles.moreServicesText),
                            SizedBox(width: styles.moreServices.gap),
                            Text('⌄', style: styles.moreServicesIcon),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: styles.statusText.marginTop),

              Text(
                sosStatus.value,
                style: styles.statusText.textStyle,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        if (showConfirm.value)
          Positioned.fill(
            child: Container(
              color: styles.modalBackdrop.backgroundColor,
              padding: styles.modalBackdrop.padding,
              alignment: Alignment.center,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: double.infinity,
                  constraints: BoxConstraints(
                    maxWidth: styles.modalCard.maxWidth,
                    maxHeight: MediaQuery.sizeOf(context).height * styles.modalCard.maxHeight,
                  ),
                  padding: styles.modalCard.padding,
                  decoration: BoxDecoration(
                    color: styles.modalCard.backgroundColor,
                    borderRadius: BorderRadius.circular(styles.modalCard.borderRadius),
                    border: Border.all(
                      width: styles.modalCard.borderWidth,
                      color: styles.modalCard.borderColor,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: styles.demoBadge.padding,
                            decoration: BoxDecoration(
                              color: styles.demoBadge.backgroundColor,
                              borderRadius: BorderRadius.circular(styles.demoBadge.borderRadius),
                            ),
                            child: Text('SIMULATION', style: styles.demoBadgeText),
                          ),
                        ),
                        SizedBox(height: styles.modalCard.gap),
                        Text(selectedService.value, style: styles.modalTitle),
                        SizedBox(height: styles.modalCard.gap),
                        Text(
                          'This demo records no incident and contacts no emergency service. In production, this confirmation will hand off to the client dispatch endpoint.',
                          style: styles.modalText,
                        ),
                        SizedBox(height: styles.modalCard.gap),
                        Row(
                          children: [
                            Icon(name: 'shareLocation', size: 20, color: colors.emergency),
                            SizedBox(width: styles.summaryRow.gap),
                            Expanded(
                              child: Text(
                                gpsLive.value ? 'Current location will be included' : 'Location sharing is off',
                                style: styles.summaryText,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: styles.modalCard.gap),
                        Row(
                          children: [
                            Icon(name: 'contacts', size: 20, color: colors.emergency),
                            SizedBox(width: styles.summaryRow.gap),
                            Expanded(
                              child: Text(
                                '${data.profile.emergencyContacts.where((item) => item.inSosCircle).length} SOS Circle contacts selected',
                                style: styles.summaryText,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: styles.modalCard.gap),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: styles.modalActions.gap,
                          runSpacing: styles.modalActions.gap,
                          children: [
                            Button(
                              label: 'Cancel',
                              variant: 'outline',
                              onPress: () => showConfirm.value = false,
                            ),
                            Button(
                              label: 'Run demo SOS',
                              color: colors.emergency,
                              onPress: simulateSos,
                            ),
                          ],
                        ),
                        if (emergencyNumber != null) ...[
                          SizedBox(height: styles.callLink.paddingTop),
                          GestureDetector(
                            onTap: callEmergency,
                            child: Text(
                              'Call $emergencyNumber using the phone dialler',
                              style: styles.callLink.textStyle,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

        if (showContacts.value)
          Positioned.fill(
            child: Container(
              color: styles.modalBackdrop.backgroundColor,
              padding: styles.modalBackdrop.padding,
              alignment: Alignment.center,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: double.infinity,
                  constraints: BoxConstraints(
                    maxWidth: styles.modalCard.maxWidth,
                    maxHeight: MediaQuery.sizeOf(context).height * styles.modalCard.maxHeight,
                  ),
                  padding: styles.modalCard.padding,
                  decoration: BoxDecoration(
                    color: styles.modalCard.backgroundColor,
                    borderRadius: BorderRadius.circular(styles.modalCard.borderRadius),
                    border: Border.all(
                      width: styles.modalCard.borderWidth,
                      color: styles.modalCard.borderColor,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Emergency Contacts', style: styles.modalTitle),
                        SizedBox(height: styles.modalCard.gap),
                        Text(
                          'Choose which emergency contacts would be notified.',
                          style: styles.modalText,
                        ),
                        SizedBox(height: styles.modalCard.gap),
                        ...data.profile.emergencyContacts.map((contact) =>
                          GestureDetector(
                            onTap: () => data.toggleSosCircle(contact.id),
                            child: Container(
                              padding: EdgeInsets.only(top: styles.contactRow.paddingTop),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    width: styles.contactRow.borderTopWidth,
                                    color: styles.contactRow.borderTopColor,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(contact.name, style: styles.contactName),
                                        SizedBox(height: styles.contactMeta.marginTop),
                                        Text(
                                          '${contact.relationship} · ${contact.phone}',
                                          style: styles.contactMeta.textStyle,
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: styles.contactRow.gap),
                                  Text(
                                    contact.inSosCircle ? '✓' : '',
                                    style: styles.contactCheck,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: styles.modalCard.gap),
                        TextField(
                          controller: contactName,
                          style: TextStyle(color: styles.input.color),
                          decoration: InputDecoration(
                            hintText: 'Contact name',
                            hintStyle: TextStyle(color: colors.textMuted),
                            filled: true,
                            fillColor: styles.input.backgroundColor,
                            contentPadding: styles.input.padding,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(styles.input.borderRadius),
                              borderSide: BorderSide(
                                width: styles.input.borderWidth,
                                color: styles.input.borderColor,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(styles.input.borderRadius),
                              borderSide: BorderSide(
                                width: styles.input.borderWidth,
                                color: styles.input.borderColor,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: styles.modalCard.gap),
                        TextField(
                          controller: contactPhone,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(color: styles.input.color),
                          decoration: InputDecoration(
                            hintText: 'Phone number',
                            hintStyle: TextStyle(color: colors.textMuted),
                            filled: true,
                            fillColor: styles.input.backgroundColor,
                            contentPadding: styles.input.padding,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(styles.input.borderRadius),
                              borderSide: BorderSide(
                                width: styles.input.borderWidth,
                                color: styles.input.borderColor,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(styles.input.borderRadius),
                              borderSide: BorderSide(
                                width: styles.input.borderWidth,
                                color: styles.input.borderColor,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: styles.modalCard.gap),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: styles.modalActions.gap,
                          runSpacing: styles.modalActions.gap,
                          children: [
                            Button(
                              label: 'Add contact',
                              variant: 'outline',
                              onPress: addContact,
                            ),
                            Button(
                              label: 'Done',
                              onPress: () => showContacts.value = false,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

        if (showProcess.value)
          Positioned.fill(
            child: Container(
              color: styles.modalBackdrop.backgroundColor,
              padding: styles.modalBackdrop.padding,
              alignment: Alignment.center,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: double.infinity,
                  constraints: BoxConstraints(
                    maxWidth: styles.modalCard.maxWidth,
                    maxHeight: MediaQuery.sizeOf(context).height * styles.modalCard.maxHeight,
                  ),
                  padding: styles.modalCard.padding,
                  decoration: BoxDecoration(
                    color: styles.modalCard.backgroundColor,
                    borderRadius: BorderRadius.circular(styles.modalCard.borderRadius),
                    border: Border.all(
                      width: styles.modalCard.borderWidth,
                      color: styles.modalCard.borderColor,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Emergency Services', style: styles.modalTitle),
                        SizedBox(height: styles.modalCard.gap),
                        ...[
                          'Confirm the trigger and requested service',
                          'Capture the latest available location',
                          'Create an incident with the dispatch provider',
                          'Notify selected SOS Circle contacts',
                          'Keep sharing incident updates until resolved',
                        ].asMap().entries.map((entry) =>
                          Padding(
                            padding: EdgeInsets.only(bottom: styles.modalCard.gap),
                            child: Row(
                              children: [
                                Container(
                                  width: styles.processNumber.width,
                                  height: styles.processNumber.height,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: styles.processNumber.backgroundColor,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${entry.key + 1}',
                                    style: styles.processNumber.textStyle,
                                  ),
                                ),
                                SizedBox(width: styles.processRow.gap),
                                Expanded(
                                  child: Text(entry.value, style: styles.summaryText),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Text(
                          'The current demo stops before dispatch and clearly reports that no help was contacted.',
                          style: styles.modalText,
                        ),
                        SizedBox(height: styles.modalCard.gap),
                        Button(
                          label: 'Close',
                          onPress: () => showProcess.value = false,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

Widget EmergencyAction({
  required BuildContext context,
  required IconName icon,
  required String title,
  required Color color,
  required VoidCallback onPress,
}) {
  final theme = useAppTheme(context);
  final colors = theme.colors;
  final isDark = theme.isDark;
  final styles = _createStyles(colors, isDark);

  return GestureDetector(
    onTap: onPress,
    child: Container(
      constraints: BoxConstraints(
        minHeight: styles.quickAction.minHeight,
      ),
      padding: styles.quickAction.padding,
      decoration: BoxDecoration(
        color: styles.quickAction.backgroundColor,
        borderRadius: BorderRadius.circular(styles.quickAction.borderRadius),
        border: Border.all(
          width: styles.quickAction.borderWidth,
          color: styles.quickAction.borderColor,
        ),
        boxShadow: styles.quickAction.boxShadow,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: styles.quickIcon.width,
            height: styles.quickIcon.height,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: withAlpha(color, 0.12),
            ),
            alignment: Alignment.center,
            child: Icon(name: icon, size: 32, color: color),
          ),
          SizedBox(height: styles.quickIcon.marginBottom),
          Text(
            title,
            style: styles.quickTitle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

Widget HealthService({
  required BuildContext context,
  required IconName icon,
  String? symbol,
  required String title,
  required String text,
  required Color color,
  required VoidCallback onPress,
}) {
  final theme = useAppTheme(context);
  final colors = theme.colors;
  final isDark = theme.isDark;
  final styles = _createStyles(colors, isDark);

  return GestureDetector(
    onTap: onPress,
    child: Container(
      constraints: BoxConstraints(
        minHeight: styles.healthRow.minHeight,
      ),
      padding: styles.healthRow.padding,
      child: Row(
        children: [
          Container(
            width: styles.healthIcon.width,
            height: styles.healthIcon.height,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
            alignment: Alignment.center,
            child: symbol != null
              ? Text(symbol, style: styles.healthIconText)
              : Icon(name: icon, size: 19, color: colors.onAccent),
          ),

          SizedBox(width: styles.healthIcon.marginRight),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: styles.healthTitle),
                SizedBox(height: styles.healthText.marginTop),
                Text(text, style: styles.healthText.textStyle),
              ],
            ),
          ),

          SizedBox(width: styles.healthArrow.marginLeft),

          Text('›', style: styles.healthArrow.textStyle),
        ],
      ),
    ),
  );
}

dynamic _createStyles(ThemeColors colors, bool isDark) {
  return (
    sosBanner: (
      minHeight: 140.0,
      backgroundColor: colors.emergency,
      borderRadius: radius.lg,
      paddingLeft: spacing.lg,
      paddingRight: spacing.md,
      boxShadow: cardShadow(colors, isDark),
    ),
    sosBannerText: (flex: 1,),
    sosTitle: TextStyle(color: colors.onAccent, fontSize: fontSize.lg, fontWeight: FontWeight.w800),
    sosText: (textStyle: TextStyle(color: colors.onAccent, fontSize: fontSize.xl, fontWeight: FontWeight.w800), marginTop: spacing.sm),

    sosOuterCircle: (
      width: 132.0,
      height: 132.0,
      borderRadius: 66.0,
      backgroundColor: withAlpha(colors.onAccent, 0.1),
      marginRight: -8.0,
    ),
    sosMiddleCircle: (
      width: 106.0,
      height: 106.0,
      borderRadius: 53.0,
      backgroundColor: withAlpha(colors.onAccent, 0.16),
    ),
    sosButton: (
      width: 80.0,
      height: 80.0,
      borderRadius: 40.0,
      backgroundColor: colors.onAccent,
      boxShadow: cardShadow(colors, isDark),
    ),
    sosButtonText: TextStyle(color: colors.emergency, fontSize: fontSize.lg, fontWeight: FontWeight.w800),

    sectionRow: (
      marginTop: spacing.md,
      marginBottom: spacing.sm,
    ),
    sectionTitle: TextStyle(color: colors.text, fontSize: fontSize.lg, fontWeight: FontWeight.w800),
    voiceText: TextStyle(color: colors.emergency, fontSize: fontSize.sm, fontWeight: FontWeight.w700),

    quickGrid: (
      gap: spacing.md,
    ),
    quickAction: (
      width: 0.31,
      minHeight: 126.0,
      backgroundColor: colors.surface,
      borderWidth: 1.0,
      borderColor: colors.border,
      borderRadius: radius.lg,
      padding: EdgeInsets.all(spacing.md),
      boxShadow: cardShadow(colors, isDark),
    ),
    quickIcon: (
      width: 56.0,
      height: 56.0,
      borderRadius: 28.0,
      marginBottom: spacing.sm,
    ),
    quickTitle: TextStyle(color: colors.text, fontSize: fontSize.sm, fontWeight: FontWeight.w700, height: 18 / fontSize.sm),

    healthSectionTitle: (
      textStyle: TextStyle(
        color: colors.text,
        fontSize: fontSize.lg,
        fontWeight: FontWeight.w800,
      ),
      marginTop: spacing.md,
      marginBottom: spacing.sm,
    ),
    healthCard: (
      backgroundColor: colors.surface,
      borderWidth: 1.0,
      borderColor: colors.border,
      borderRadius: radius.lg,
      boxShadow: cardShadow(colors, isDark),
    ),
    healthRow: (
      minHeight: 76.0,
      padding: EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: spacing.sm,
      ),
    ),
    healthIcon: (
      width: 36.0,
      height: 36.0,
      borderRadius: 18.0,
      marginRight: spacing.md,
    ),
    healthIconText: TextStyle(color: colors.onAccent, fontSize: fontSize.md, fontWeight: FontWeight.w800),
    healthTitle: TextStyle(color: colors.text, fontSize: fontSize.md, fontWeight: FontWeight.w700),
    healthText: (textStyle: TextStyle(color: colors.textMuted, fontSize: fontSize.sm), marginTop: 3.0),
    healthArrow: (textStyle: TextStyle(color: colors.text, fontSize: 28), marginLeft: spacing.sm),
    divider: (height: 1.0, backgroundColor: colors.border, marginLeft: 70.0),

    moreServices: (
      minHeight: 58.0,
      gap: spacing.sm,
    ),
    moreServicesText: TextStyle(color: colors.text, fontSize: fontSize.md, fontWeight: FontWeight.w700),
    moreServicesIcon: TextStyle(color: colors.textMuted, fontSize: fontSize.lg, fontWeight: FontWeight.w700),

    statusText: (textStyle: TextStyle(color: colors.textMuted, fontSize: fontSize.xs), marginTop: spacing.md),

    grow: (flex: 1,),
    modalBackdrop: (backgroundColor: colors.scrim, padding: EdgeInsets.all(spacing.lg)),
    modalCard: (maxWidth: 480.0, maxHeight: 0.88, backgroundColor: colors.card, borderRadius: radius.lg, borderWidth: 1.0, borderColor: colors.border, padding: EdgeInsets.all(spacing.lg), gap: spacing.md),
    modalTitle: TextStyle(color: colors.text, fontSize: fontSize.xl, fontWeight: FontWeight.w800),
    modalText: TextStyle(color: colors.textMuted, fontSize: fontSize.sm, height: 20 / fontSize.sm),
    demoBadge: (backgroundColor: withAlpha(colors.warning, 0.18), borderRadius: radius.pill, padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs)),
    demoBadgeText: TextStyle(color: colors.warning, fontSize: fontSize.xs, fontWeight: FontWeight.w800),
    summaryRow: (gap: spacing.sm,),
    summaryText: TextStyle(color: colors.text, fontSize: fontSize.sm, height: 19 / fontSize.sm),
    modalActions: (gap: spacing.sm,),
    callLink: (textStyle: TextStyle(color: colors.emergency, fontSize: fontSize.sm, fontWeight: FontWeight.w700), paddingTop: spacing.xs),
    contactRow: (gap: spacing.sm, borderTopWidth: 1.0, borderTopColor: colors.border, paddingTop: spacing.sm),
    contactName: TextStyle(color: colors.text, fontSize: fontSize.md, fontWeight: FontWeight.w700),
    contactMeta: (textStyle: TextStyle(color: colors.textMuted, fontSize: fontSize.xs), marginTop: 2.0),
    contactCheck: TextStyle(color: colors.emergency, fontSize: fontSize.lg, fontWeight: FontWeight.w800),
    input: (backgroundColor: colors.background, color: colors.text, borderWidth: 1.0, borderColor: colors.border, borderRadius: radius.sm, padding: EdgeInsets.all(spacing.md)),
    processRow: (gap: spacing.sm,),
    processNumber: (
      width: 26.0,
      height: 26.0,
      backgroundColor: colors.emergency,
      textStyle: TextStyle(
        color: colors.onAccent,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}