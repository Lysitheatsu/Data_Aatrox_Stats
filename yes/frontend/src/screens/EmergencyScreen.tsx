import React from 'react';
import { Alert, Linking, Modal, Platform, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import {
  Screen,
  Header,
  Button,
  Icon,
} from '@/components';
import { cardShadow, fontSize, radius, spacing, withAlpha, type ThemeColors } from '@/theme';
import { useAppTheme } from '@/theme/ThemeProvider';
import { useAppData } from '@/data/AppDataProvider';
import type { IconName } from '@/theme/icons';
import { API_BASE_URL } from '@/api/client';

const USE_MOCK_DATA = process.env.EXPO_PUBLIC_DATA_SOURCE !== 'api';

const emergencyNumbers: Record<string, string> = {
  AU: '000',
  US: '911',
  CA: '911',
  GB: '999',
  NZ: '111',
  DE: '112',
  FR: '112',
};

type NearbyPlace = {
  id: number;
  name: string;
  latitude: number;
  longitude: number;
  distance: number;
  type: string;
};

function getCountryCode() {
  if (Platform.OS === 'web') {
    try {
      const language = navigator.language;
      const locale = new Intl.Locale(language);
      if (locale.region) {
        return locale.region.toUpperCase();
      }
    } catch {
      return '';
    }
  }
  return '';
}

function getEmergencyNumber(countryCode: string) {
  return emergencyNumbers[countryCode];
}

/** Module 3 — SOS & Emergency. */
export function EmergencyScreen(): React.JSX.Element {
  const { colors, isDark } = useAppTheme();
  const styles = React.useMemo(() => createStyles(colors, isDark), [colors, isDark]);
  const data = useAppData();
  const navigation = useNavigation<any>();
  const [sosStatus, setSosStatus] = React.useState('Protection active');
  const [isListening, setIsListening] = React.useState(false);
  const [gpsLive] = React.useState(true);
  const [showConfirm, setShowConfirm] = React.useState(false);
  const [showContacts, setShowContacts] = React.useState(false);
  const [showProcess, setShowProcess] = React.useState(false);
  const [selectedService, setSelectedService] = React.useState('Emergency help');
  const [contactName, setContactName] = React.useState('');
  const [contactPhone, setContactPhone] = React.useState('');
  const [nearbyHospitals, setNearbyHospitals] = React.useState<NearbyPlace[]>([]);
  const [nearbyClinics, setNearbyClinics] = React.useState<NearbyPlace[]>([]);
  const [nearbyPharmacies, setNearbyPharmacies] = React.useState<NearbyPlace[]>([]);
  const [nearbyBloodBanks, setNearbyBloodBanks] = React.useState<NearbyPlace[]>([]);
  const [healthLoading, setHealthLoading] = React.useState(false);
  const recognitionRef = React.useRef<any>(null);
  const countryCode = getCountryCode();
  const emergencyNumber = getEmergencyNumber(countryCode);

  function showMessage(title: string, message: string) {
    if (Platform.OS === 'web') {
      window.alert(`${title}\n${message}`);
    } else {
      Alert.alert(title, message);
    }
  }

  function getDistance(
    lat1: number,
    lon1: number,
    lat2: number,
    lon2: number,
  ) {
    const earthRadius = 6371;
    const latDifference = (lat2 - lat1) * Math.PI / 180;
    const lonDifference = (lon2 - lon1) * Math.PI / 180;
    const a =
      Math.sin(latDifference / 2) * Math.sin(latDifference / 2) +
      Math.cos(lat1 * Math.PI / 180) *
      Math.cos(lat2 * Math.PI / 180) *
      Math.sin(lonDifference / 2) *
      Math.sin(lonDifference / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return earthRadius * c;
  }

  function formatHealthDistance(distance: number) {
    if (distance < 1) {
      const metres = Math.round(distance * 1000);
      return `${metres} m away`;
    }

    return `${distance.toFixed(1)} km away`;
  }

  async function getNearbyHealthServices() {
    if (Platform.OS !== 'web') {
      return;
    }

    if (!navigator.geolocation) {
      return;
    }
    setHealthLoading(true);
    navigator.geolocation.getCurrentPosition(
      async function (position) {
        const latitude = position.coords.latitude;
        const longitude = position.coords.longitude;
        const radius = 2000; 

        const query = `
          [out:json][timeout:25];
          (
            node["amenity"="hospital"](around:${radius},${latitude},${longitude});
            way["amenity"="hospital"](around:${radius},${latitude},${longitude});
            relation["amenity"="hospital"](around:${radius},${latitude},${longitude});
            node["amenity"="clinic"](around:${radius},${latitude},${longitude});
            way["amenity"="clinic"](around:${radius},${latitude},${longitude});
            relation["amenity"="clinic"](around:${radius},${latitude},${longitude});
            node["amenity"="pharmacy"](around:${radius},${latitude},${longitude});
            way["amenity"="pharmacy"](around:${radius},${latitude},${longitude});
            relation["amenity"="pharmacy"](around:${radius},${latitude},${longitude});
            node["healthcare"="blood_donation"](around:${radius},${latitude},${longitude});
            way["healthcare"="blood_donation"](around:${radius},${latitude},${longitude});
            relation["healthcare"="blood_donation"](around:${radius},${latitude},${longitude});
          );
          out center tags;
        `;
        try {
          const url =
            `https://overpass-api.de/api/interpreter?data=${encodeURIComponent(query)}`;
          const response = await fetch(url);

          if (!response.ok) {
            throw new Error('Could not load nearby services.');
          }
          const result = await response.json();
          const hospitals: NearbyPlace[] = [];
          const clinics: NearbyPlace[] = [];
          const pharmacies: NearbyPlace[] = [];
          const bloodBanks: NearbyPlace[] = [];
          for (const item of result.elements) {
            let placeLatitude = item.lat;
            let placeLongitude = item.lon;
            if (item.center) {
              placeLatitude = item.center.lat;
              placeLongitude = item.center.lon;
            }
            if (placeLatitude == null || placeLongitude == null) {
              continue;
            }
            let name = 'Unnamed location';
            if (item.tags?.name) {
              name = item.tags.name;
            } else if (item.tags?.brand) {
              name = item.tags.brand;
            }
            const distance = getDistance(
              latitude,
              longitude,
              placeLatitude,
              placeLongitude,
            );
            const place: NearbyPlace = {
              id: item.id,
              name: name,
              latitude: placeLatitude,
              longitude: placeLongitude,
              distance: distance,
              type: '',
            };
            if (item.tags?.amenity === 'hospital') {
              place.type = 'hospital';
              hospitals.push(place);
            }
            if (item.tags?.amenity === 'clinic') {
              place.type = 'clinic';
              clinics.push(place);
            }
            if (item.tags?.amenity === 'pharmacy') {
              place.type = 'pharmacy';
              pharmacies.push(place);
            }
            if (item.tags?.healthcare === 'blood_donation') {
              place.type = 'blood_donation';
              bloodBanks.push(place);
            }
          }

          hospitals.sort((a, b) => a.distance - b.distance);
          clinics.sort((a, b) => a.distance - b.distance);
          pharmacies.sort((a, b) => a.distance - b.distance);
          bloodBanks.sort((a, b) => a.distance - b.distance);
          setNearbyHospitals(hospitals);
          setNearbyClinics(clinics);
          setNearbyPharmacies(pharmacies);
          setNearbyBloodBanks(bloodBanks);
        } catch {
          showMessage(
            'Health Services',
            'Could not load nearby health services.',
          );
        }
        setHealthLoading(false);
      },
      function () {
        setHealthLoading(false);
        showMessage(
          'Location',
          'ELLY could not get your current location.',
        );
      }
    );
  }

  function openHealthService(place: NearbyPlace | undefined) {
    if (!place) {
      showMessage(
        'Health Services',
        'No nearby location was found.',
      );
      return;
    }

    const location = {
      label: place.name,
      latitude: place.latitude,
      longitude: place.longitude,
    };

    navigation.navigate('Map', {
      focusLocation: location,
    });
  }

  async function sendSosToBackend(
    type: string,
    latitude: number,
    longitude: number,
    accuracy: number,
  ) {
    const id = Date.now().toString();

    const data = {
      packet_id: `packet_${id}`,
      session_id: `session_${id}`,
      user_id: 'demo_user',
      generated_at: new Date().toISOString(),
      packet_version: '2.0',
      sequence_number: 1,
      status: 'QUEUED',
      priority: 'CRITICAL',
      packet_hash: `sos_${id}`,
      packet_checksum: `sos_${id}`,
      location: {
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
      },
      transcript: {
        text: type === 'voice' ? 'Voice SOS detected' : 'Manual SOS button pressed',
        confidence: 1,
        language: 'en',
        is_partial: false,
        speech_probability: 1,
        parsed_intent: 'EMERGENCY',
        matched_keywords: type === 'voice' ? ['help', 'help', 'help'] : ['SOS'],
      },
    };

    const response = await fetch(`${API_BASE_URL}/v1/emergency/dispatch`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });
    if (!response.ok) {
      throw new Error(await response.text());
    }

    return response.json();
  }
  async function activateSos(type: string) {
    if (type === 'manual' || USE_MOCK_DATA) {
      if (type === 'voice') setSelectedService('Voice-detected emergency');
      setShowConfirm(true);
      return;
    }
    if (type === 'voice') {
      setSosStatus('Voice SOS detected');
    } else {
      setSosStatus('Preparing emergency alert...');
    }

    if (Platform.OS === 'web' && navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        async function (position) {
          try {
            const latitude = position.coords.latitude;
            const longitude = position.coords.longitude;
            const accuracy = position.coords.accuracy;

            setSosStatus('Sending emergency alert...');

            const result = await sendSosToBackend(
              type,
              latitude,
              longitude,
              accuracy,
            );

            setSosStatus(`SOS sent · ${result.confirmation_code}`);
            callEmergency();
          } catch {
            setSosStatus('Could not send SOS to the server.');
            showMessage('SOS', 'Could not send SOS information to the server.');
          }
        },
        function () {
          setSosStatus('Could not get your location.');
          showMessage('Location', 'ELLY could not get your current location.');
        }
      );
      return;
    }
    callEmergency();
  }

  function callEmergency() {
    if (emergencyNumber) {
      showMessage('Emergency', 'Opening phone dialler.');
      Linking.openURL(`tel:${emergencyNumber}`);
    } else {
      showMessage('Emergency', 'Emergency number not found.');
    }
  }
  function stopVoiceDetection() {
    if (recognitionRef.current) {
      recognitionRef.current.stop();
      recognitionRef.current = null;
    }
    setIsListening(false);
  }
  function startVoiceDetection() {
    if (Platform.OS !== 'web') {
      setSosStatus('Voice SOS only works on the web version.');
      return;
    }
    const SpeechRecognition =
      (globalThis as any).SpeechRecognition ||
      (globalThis as any).webkitSpeechRecognition;

    if (!SpeechRecognition) {
      setSosStatus('Voice detection is not supported in this browser.');
      return;
    }
    if (isListening) {
      stopVoiceDetection();
      return;
    }

    const recognition = new SpeechRecognition();
    recognition.continuous = true;
    recognition.interimResults = true;
    recognition.lang = 'en-AU';
    recognition.onresult = function (event: any) {
      let words = '';

      for (let i = event.resultIndex; i < event.results.length; i++) {
        words = words + event.results[i][0].transcript + ' ';
      }

      words = words.toLowerCase().trim();

      if (words.includes('help help help')) {
        activateSos('voice');
        recognition.stop();
      }
    };

    recognition.onerror = function () {
      recognitionRef.current = null;
      setIsListening(false);
      setSosStatus('Voice detection stopped. Please try again.');
    };

    recognition.onend = function () {
      recognitionRef.current = null;
      setIsListening(false);
    };

    recognitionRef.current = recognition;
    recognition.start();
    setIsListening(true);
    setSosStatus('Listening for help help help...');
  }

  function openEmergencyService(service: string) {
    setSelectedService(service);
    setShowConfirm(true);
  }

  function shareLiveLocation() {
    if (Platform.OS === 'web' && navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        function (position) {
          const latitude = position.coords.latitude;
          const longitude = position.coords.longitude;
          const locationUrl =
            `https://www.openstreetmap.org/?mlat=${latitude}&mlon=${longitude}`;

          showMessage('Share Live Location', locationUrl);
        },
        function () {
          showMessage('Location', 'ELLY could not get your current location.');
        }
      );
      return;
    }

    showMessage('Share Live Location', 'Location sharing will open here.');
  }

  function viewSosCircle() {
    setShowContacts(true);
  }
  function simulateSos() {
    setShowConfirm(false);
    setSosStatus(`DEMO ONLY · ${selectedService} alert simulated`);
    showMessage('Demo SOS completed', `No emergency service was contacted. ${data.profile.emergencyContacts.filter((item) => item.inSosCircle).length} SOS Circle contacts would be notified.`);
  }
  function addContact() {
    if (!contactName.trim() || !contactPhone.trim()) return;
    data.addEmergencyContact({ name: contactName.trim(), phone: contactPhone.trim(), relationship: 'Contact', inSosCircle: true });
    setContactName('');
    setContactPhone('');
  }

  let hospitalText = 'No hospitals found nearby';
  let clinicText = 'No clinics found nearby';
  let pharmacyText = 'No pharmacies found nearby';
  let bloodBankText = 'No blood banks found nearby';

  if (healthLoading) {
    hospitalText = 'Finding hospitals near you...';
    clinicText = 'Finding clinics near you...';
    pharmacyText = 'Finding pharmacies near you...';
    bloodBankText = 'Finding blood banks near you...';
  } else {
    if (nearbyHospitals[0]) {
      hospitalText =
        `${nearbyHospitals[0].name} · ${formatHealthDistance(nearbyHospitals[0].distance)}`;
    }
    if (nearbyClinics[0]) {
      clinicText =
        `${nearbyClinics[0].name} · ${formatHealthDistance(nearbyClinics[0].distance)}`;
    }
    if (nearbyPharmacies[0]) {
      pharmacyText =
        `${nearbyPharmacies[0].name} · ${formatHealthDistance(nearbyPharmacies[0].distance)}`;
    }
    if (nearbyBloodBanks[0]) {
      bloodBankText =
        `${nearbyBloodBanks[0].name} · ${formatHealthDistance(nearbyBloodBanks[0].distance)}`;
    }
  }
  React.useEffect(() => {
    getNearbyHealthServices();
  }, []);

  React.useEffect(() => () => recognitionRef.current?.stop?.(), []);

  return (
    <Screen>
      <Header title="Emergency" titleColor={colors.emergency} rightIcon="shield"
        rightIconColor={colors.text} />

      <View style={styles.sosBanner}>
        <View style={styles.sosBannerText}>
          <Text style={styles.sosTitle}>In an emergency?</Text>
          <Text style={styles.sosText}>We're here to help.</Text>
        </View>

        <View style={styles.sosOuterCircle}>
          <View style={styles.sosMiddleCircle}>
            <Pressable style={styles.sosButton} onPress={() => activateSos('manual')}>
              <Text style={styles.sosButtonText}>SOS</Text>
            </Pressable>
          </View>
        </View>
      </View>

      <View style={styles.sectionRow}>
        <Text style={styles.sectionTitle}>Quick Actions</Text>
        <Pressable onPress={startVoiceDetection}>
          <Text style={styles.voiceText}>
            {isListening ? 'Stop Voice SOS' : 'Voice SOS'}
          </Text>
        </Pressable>
      </View>

      <View style={styles.quickGrid}>
        <EmergencyAction
          icon="ambulance"
          title="Ambulance"
          color={colors.emergency}
          onPress={() => openEmergencyService('Ambulance')}
        />

        <EmergencyAction
          icon="police"
          title="Police"
          color={colors.primary}
          onPress={() => openEmergencyService('Police')}
        />

        <EmergencyAction
          icon="fire"
          title="Fire"
          color={colors.warning}
          onPress={() => openEmergencyService('Fire')}
        />

        <EmergencyAction
          icon="roadside"
          title="Roadside Assistance"
          color={colors.elly}
          onPress={() => openEmergencyService('Roadside Assistance')}
        />

        <EmergencyAction
          icon="shareLocation"
          title="Share Live Location"
          color={colors.success}
          onPress={shareLiveLocation}
        />

        <EmergencyAction
          icon="contacts"
          title="Emergency Contacts"
          color={colors.elly}
          onPress={viewSosCircle}
        />
      </View>

      <Text style={styles.healthSectionTitle}>Health Services</Text>

      <View style={styles.healthCard}>
        <HealthService
          icon="hospital"
          symbol="H"
          title="Nearest Hospital"
          text={hospitalText}
          color={colors.emergency}
          onPress={() => openHealthService(nearbyHospitals[0])}
        />

        <View style={styles.divider} />

        <HealthService
          icon="clinic"
          title="Nearby Clinics"
          text={clinicText}
          color={colors.success}
          onPress={() => openHealthService(nearbyClinics[0])}
        />

        <View style={styles.divider} />

        <HealthService
          icon="pharmacy"
          symbol="+"
          title="Pharmacies"
          text={pharmacyText}
          color={colors.success}
          onPress={() => openHealthService(nearbyPharmacies[0])}
        />

        <View style={styles.divider} />

        <HealthService
          icon="bloodBank"
          title="Blood Banks"
          text={bloodBankText}
          color={colors.emergency}
          onPress={() => openHealthService(nearbyBloodBanks[0])}
        />

        <View style={styles.divider} />

        <Pressable style={styles.moreServices} onPress={getNearbyHealthServices}>
          <Text style={styles.moreServicesText}>Refresh Nearby Services</Text>
          <Text style={styles.moreServicesIcon}>⌄</Text>
        </Pressable>
      </View>

      <Text style={styles.statusText}>{sosStatus}</Text>

      <Modal visible={showConfirm} transparent animationType="fade" onRequestClose={() => setShowConfirm(false)}>
        <View style={styles.modalBackdrop}><View style={styles.modalCard}>
          <View style={styles.demoBadge}><Text style={styles.demoBadgeText}>SIMULATION</Text></View>
          <Text style={styles.modalTitle}>{selectedService}</Text>
          <Text style={styles.modalText}>This demo records no incident and contacts no emergency service. In production, this confirmation will hand off to the client dispatch endpoint.</Text>
          <View style={styles.summaryRow}><Icon name="shareLocation" size={20} color={colors.emergency} /><Text style={styles.summaryText}>{gpsLive ? 'Current location will be included' : 'Location sharing is off'}</Text></View>
          <View style={styles.summaryRow}><Icon name="contacts" size={20} color={colors.emergency} /><Text style={styles.summaryText}>{data.profile.emergencyContacts.filter((item) => item.inSosCircle).length} SOS Circle contacts selected</Text></View>
          <View style={styles.modalActions}><Button label="Cancel" variant="outline" onPress={() => setShowConfirm(false)} /><Button label="Run demo SOS" color={colors.emergency} onPress={simulateSos} /></View>
          {emergencyNumber ? <Pressable onPress={callEmergency}><Text style={styles.callLink}>Call {emergencyNumber} using the phone dialler</Text></Pressable> : null}
        </View></View>
      </Modal>

      <Modal visible={showContacts} transparent animationType="fade" onRequestClose={() => setShowContacts(false)}>
        <View style={styles.modalBackdrop}><View style={styles.modalCard}>
          <Text style={styles.modalTitle}>Emergency Contacts</Text>
          <Text style={styles.modalText}>Choose which emergency contacts would be notified.</Text>
          {data.profile.emergencyContacts.map((contact) => <Pressable key={contact.id} style={styles.contactRow} onPress={() => data.toggleSosCircle(contact.id)}><View style={styles.grow}><Text style={styles.contactName}>{contact.name}</Text><Text style={styles.contactMeta}>{contact.relationship} · {contact.phone}</Text></View><Text style={styles.contactCheck}>{contact.inSosCircle ? '✓' : ''}</Text></Pressable>)}
          <TextInput style={styles.input} value={contactName} onChangeText={setContactName} placeholder="Contact name" placeholderTextColor={colors.textMuted} />
          <TextInput style={styles.input} value={contactPhone} onChangeText={setContactPhone} placeholder="Phone number" placeholderTextColor={colors.textMuted} keyboardType="phone-pad" />
          <View style={styles.modalActions}><Button label="Add contact" variant="outline" onPress={addContact} /><Button label="Done" onPress={() => setShowContacts(false)} /></View>
        </View></View>
      </Modal>

      <Modal visible={showProcess} transparent animationType="fade" onRequestClose={() => setShowProcess(false)}>
        <View style={styles.modalBackdrop}><View style={styles.modalCard}>
          <Text style={styles.modalTitle}>Emergency Services</Text>
          {['Confirm the trigger and requested service', 'Capture the latest available location', 'Create an incident with the dispatch provider', 'Notify selected SOS Circle contacts', 'Keep sharing incident updates until resolved'].map((step, index) => <View key={step} style={styles.processRow}><Text style={styles.processNumber}>{index + 1}</Text><Text style={styles.summaryText}>{step}</Text></View>)}
          <Text style={styles.modalText}>The current demo stops before dispatch and clearly reports that no help was contacted.</Text>
          <Button label="Close" onPress={() => setShowProcess(false)} />
        </View></View>
      </Modal>
    </Screen>
  );
}

function EmergencyAction({
  icon,
  title,
  color,
  onPress,
}: {
  icon: IconName;
  title: string;
  color: string;
  onPress: () => void;
}): React.JSX.Element {
  const { colors, isDark } = useAppTheme();
  const styles = React.useMemo(() => createStyles(colors, isDark), [colors, isDark]);

  return (
    <Pressable style={styles.quickAction} onPress={onPress}>
      <View style={[styles.quickIcon, { backgroundColor: withAlpha(color, 0.12) }]}>
        <Icon name={icon} size={32} color={color} />
      </View>
      <Text style={styles.quickTitle}>{title}</Text>
    </Pressable>
  );
}

function HealthService({
  icon,
  symbol,
  title,
  text,
  color,
  onPress,
}: {
  icon: IconName;
  symbol?: string;
  title: string;
  text: string;
  color: string;
  onPress: () => void;
}): React.JSX.Element {
  const { colors, isDark } = useAppTheme();
  const styles = React.useMemo(() => createStyles(colors, isDark), [colors, isDark]);

  return (
    <Pressable style={styles.healthRow} onPress={onPress}>
      <View style={[styles.healthIcon, { backgroundColor: color }]}>
        {symbol ? (
          <Text style={styles.healthIconText}>{symbol}</Text>
        ) : (
          <Icon name={icon} size={19} color={colors.onAccent} />
        )}
      </View>

      <View style={styles.grow}>
        <Text style={styles.healthTitle}>{title}</Text>
        <Text style={styles.healthText}>{text}</Text>
      </View>

      <Text style={styles.healthArrow}>›</Text>
    </Pressable>
  );
}

function createStyles(colors: ThemeColors, isDark: boolean) {
  return StyleSheet.create({
    sosBanner: {
      flexDirection: 'row',
      alignItems: 'center',
      justifyContent: 'space-between',
      minHeight: 140,
      backgroundColor: colors.emergency,
      borderRadius: radius.lg,
      paddingLeft: spacing.lg,
      paddingRight: spacing.md,
      overflow: 'hidden',
      ...cardShadow(colors, isDark),
    },
    sosBannerText: { flex: 1 },
    sosTitle: { color: colors.onAccent, fontSize: fontSize.lg, fontWeight: '800' },
    sosText: { color: colors.onAccent, fontSize: fontSize.xl, fontWeight: '800', marginTop: spacing.sm },

    sosOuterCircle: {
      width: 132,
      height: 132,
      borderRadius: 66,
      backgroundColor: withAlpha(colors.onAccent, 0.1),
      alignItems: 'center',
      justifyContent: 'center',
      marginRight: -8,
    },
    sosMiddleCircle: {
      width: 106,
      height: 106,
      borderRadius: 53,
      backgroundColor: withAlpha(colors.onAccent, 0.16),
      alignItems: 'center',
      justifyContent: 'center',
    },
    sosButton: {
      width: 80,
      height: 80,
      borderRadius: 40,
      backgroundColor: colors.onAccent,
      alignItems: 'center',
      justifyContent: 'center',
      ...cardShadow(colors, isDark),
    },
    sosButtonText: { color: colors.emergency, fontSize: fontSize.lg, fontWeight: '800' },

    sectionRow: {
      flexDirection: 'row',
      alignItems: 'center',
      justifyContent: 'space-between',
      marginTop: spacing.md,
      marginBottom: spacing.sm,
    },
    sectionTitle: { color: colors.text, fontSize: fontSize.lg, fontWeight: '800' },
    voiceText: { color: colors.emergency, fontSize: fontSize.sm, fontWeight: '700' },

    quickGrid: {
      flexDirection: 'row',
      flexWrap: 'wrap',
      justifyContent: 'space-between',
      gap: spacing.md,
    },
    quickAction: {
      width: '31%',
      minHeight: 126,
      backgroundColor: colors.surface,
      borderWidth: 1,
      borderColor: colors.border,
      borderRadius: radius.lg,
      alignItems: 'center',
      justifyContent: 'center',
      padding: spacing.md,
      ...cardShadow(colors, isDark),
    },
    quickIcon: {
      width: 56,
      height: 56,
      borderRadius: 28,
      alignItems: 'center',
      justifyContent: 'center',
      marginBottom: spacing.sm,
    },
    quickTitle: { color: colors.text, fontSize: fontSize.sm, fontWeight: '700', textAlign: 'center', lineHeight: 18 },

    healthSectionTitle: {
      color: colors.text,
      fontSize: fontSize.lg,
      fontWeight: '800',
      marginTop: spacing.md,
      marginBottom: spacing.sm,
    },
    healthCard: {
      backgroundColor: colors.surface,
      borderWidth: 1,
      borderColor: colors.border,
      borderRadius: radius.lg,
      overflow: 'hidden',
      ...cardShadow(colors, isDark),
    },
    healthRow: {
      flexDirection: 'row',
      alignItems: 'center',
      minHeight: 76,
      paddingHorizontal: spacing.md,
      paddingVertical: spacing.sm,
    },
    healthIcon: {
      width: 36,
      height: 36,
      borderRadius: 18,
      alignItems: 'center',
      justifyContent: 'center',
      marginRight: spacing.md,
    },
    healthIconText: { color: colors.onAccent, fontSize: fontSize.md, fontWeight: '800' },
    healthTitle: { color: colors.text, fontSize: fontSize.md, fontWeight: '700' },
    healthText: { color: colors.textMuted, fontSize: fontSize.sm, marginTop: 3 },
    healthArrow: { color: colors.text, fontSize: 28, marginLeft: spacing.sm },
    divider: { height: 1, backgroundColor: colors.border, marginLeft: 70 },

    moreServices: {
      flexDirection: 'row',
      alignItems: 'center',
      justifyContent: 'center',
      minHeight: 58,
      gap: spacing.sm,
    },
    moreServicesText: { color: colors.text, fontSize: fontSize.md, fontWeight: '700' },
    moreServicesIcon: { color: colors.textMuted, fontSize: fontSize.lg, fontWeight: '700' },

    statusText: { color: colors.textMuted, fontSize: fontSize.xs, textAlign: 'center', marginTop: spacing.md },

    grow: { flex: 1 },
    modalBackdrop: { flex: 1, backgroundColor: colors.scrim, justifyContent: 'center', alignItems: 'center', padding: spacing.lg },
    modalCard: { width: '100%', maxWidth: 480, maxHeight: '88%', backgroundColor: colors.card, borderRadius: radius.lg, borderWidth: 1, borderColor: colors.border, padding: spacing.lg, gap: spacing.md },
    modalTitle: { color: colors.text, fontSize: fontSize.xl, fontWeight: '800' },
    modalText: { color: colors.textMuted, fontSize: fontSize.sm, lineHeight: 20 },
    demoBadge: { alignSelf: 'flex-start', backgroundColor: withAlpha(colors.warning, 0.18), borderRadius: radius.pill, paddingHorizontal: spacing.sm, paddingVertical: spacing.xs },
    demoBadgeText: { color: colors.warning, fontSize: fontSize.xs, fontWeight: '800' },
    summaryRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
    summaryText: { flex: 1, color: colors.text, fontSize: fontSize.sm, lineHeight: 19 },
    modalActions: { flexDirection: 'row', justifyContent: 'flex-end', flexWrap: 'wrap', gap: spacing.sm },
    callLink: { color: colors.emergency, textAlign: 'center', fontSize: fontSize.sm, fontWeight: '700', paddingTop: spacing.xs },
    contactRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm, borderTopWidth: 1, borderTopColor: colors.border, paddingTop: spacing.sm },
    contactName: { color: colors.text, fontSize: fontSize.md, fontWeight: '700' },
    contactMeta: { color: colors.textMuted, fontSize: fontSize.xs, marginTop: 2 },
    contactCheck: { color: colors.emergency, fontSize: fontSize.lg, fontWeight: '800' },
    input: { backgroundColor: colors.background, color: colors.text, borderWidth: 1, borderColor: colors.border, borderRadius: radius.sm, padding: spacing.md },
    processRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
    processNumber: { width: 26, height: 26, textAlign: 'center', textAlignVertical: 'center', lineHeight: 26, borderRadius: 13, color: colors.onAccent, backgroundColor: colors.emergency, fontWeight: '800' },
  });
}