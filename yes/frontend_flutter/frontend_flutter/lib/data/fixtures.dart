import '../api/client.dart';
import 'types.dart';

String todayAt(int hour, int minute) {
  final now = DateTime.now();
  var date = DateTime(now.year, now.month, now.day, hour, minute);
  if (date.isBefore(now)) date = date.add(const Duration(days: 1));
  return date.toUtc().toIso8601String();
}

final AppData initialData = AppData(
  profile: UserProfile(
    id: 'demo_user',
    displayName: 'Shivam R',
    savedPlaces: [
      SavedPlace(id: 'home', kind: 'home', label: 'Home', latitude: -37.8132, longitude: 144.9631),
      SavedPlace(id: 'work', kind: 'work', label: 'Work', latitude: -37.8183, longitude: 144.9525),
      SavedPlace(id: 'fav_1', kind: 'favourite', label: 'City Care Hospital', latitude: -37.8075, longitude: 144.9651),
      SavedPlace(id: 'recent_1', kind: 'recent', label: 'Melbourne Central', latitude: -37.8103, longitude: 144.9628),
    ],
    calendarEvents: [
      CalendarEvent(
        id: 'event_1',
        title: 'Dr. Sarah Johnson',
        subtitle: 'Cardiologist · City Care Hospital',
        startsAt: todayAt(14, 30),
        reminderMinutes: 30,
        location: GeoLocation(label: 'City Care Hospital', latitude: -37.8075, longitude: 144.9651),
      ),
      CalendarEvent(
        id: 'event_2',
        title: 'Product planning',
        subtitle: 'Work · Level 4',
        startsAt: todayAt(16, 0),
        reminderMinutes: 20,
        location: GeoLocation(label: 'Work', latitude: -37.8183, longitude: 144.9525),
      ),
    ],
    emergencyContacts: [
      EmergencyContact(id: 'ec_1', name: 'Mom', phone: '+61 400 000 001', relationship: 'Family', inSosCircle: true),
      EmergencyContact(id: 'ec_2', name: 'Dad', phone: '+61 400 000 002', relationship: 'Family', inSosCircle: true),
      EmergencyContact(id: 'ec_3', name: 'Rahul', phone: '+61 400 000 003', relationship: 'Friend', inSosCircle: false),
    ],
  ),
  connections: [
    Connection(id: 'c_mom', name: 'Mom', status: 'connected', isLive: true, lastUpdated: '2 min ago', location: GeoLocation(label: 'Carlton', latitude: -37.8001, longitude: 144.9671)),
    Connection(id: 'c_rahul', name: 'Rahul', status: 'connected', isLive: true, lastUpdated: '5 min away', location: GeoLocation(label: 'Docklands', latitude: -37.8148, longitude: 144.9467)),
    Connection(id: 'c_ananya', name: 'Ananya', status: 'connected', isLive: false, lastUpdated: '1 hour ago'),
    Connection(id: 'c_dad', name: 'Dad', status: 'connected', isLive: true, lastUpdated: '3 min away', location: GeoLocation(label: 'Fitzroy', latitude: -37.7984, longitude: 144.9783)),
    Connection(id: 'c_request', name: 'Maya Patel', status: 'pending_incoming', isLive: false, lastUpdated: 'Today'),
  ],
  groups: [
    ConnectionGroup(id: 'g_family', name: 'Family', type: 'family', memberIds: ['c_mom', 'c_dad']),
    ConnectionGroup(id: 'g_team', name: 'Product Team', type: 'business', memberIds: ['c_rahul', 'c_ananya']),
  ],
  permissions: [
    SharePermission(connectionId: 'c_mom', mode: 'permanent'),
    SharePermission(connectionId: 'c_dad', mode: 'emergency'),
  ],
  suggestions: [
    SmartSuggestion(id: 's_1', type: 'leave_earlier', title: 'Leave 10 minutes earlier', detail: 'Your 2:30 PM appointment has moderate traffic on the usual route.'),
    SmartSuggestion(id: 's_2', type: 'weather', title: 'Rain expected this afternoon', detail: 'Allow extra walking time and carry an umbrella.'),
    SmartSuggestion(id: 's_3', type: 'parking', title: 'Parking near City Care', detail: 'The east entrance car park is usually quieter after 2 PM.'),
  ],
);