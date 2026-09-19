import type { AppData } from '@/data/types';

const todayAt = (hour: number, minute: number) => {
  const date = new Date();
  date.setHours(hour, minute, 0, 0);
  if (date.getTime() < Date.now()) date.setDate(date.getDate() + 1);
  return date.toISOString();
};

export const initialData: AppData = {
  profile: {
    id: 'demo_user',
    displayName: 'Shivam R',
    savedPlaces: [
      { id: 'home', kind: 'home', label: 'Home', latitude: -37.8132, longitude: 144.9631 },
      { id: 'work', kind: 'work', label: 'Work', latitude: -37.8183, longitude: 144.9525 },
      { id: 'fav_1', kind: 'favourite', label: 'City Care Hospital', latitude: -37.8075, longitude: 144.9651 },
      { id: 'recent_1', kind: 'recent', label: 'Melbourne Central', latitude: -37.8103, longitude: 144.9628 },
    ],
    calendarEvents: [
      {
        id: 'event_1',
        title: 'Dr. Sarah Johnson',
        subtitle: 'Cardiologist · City Care Hospital',
        startsAt: todayAt(14, 30),
        reminderMinutes: 30,
        location: { label: 'City Care Hospital', latitude: -37.8075, longitude: 144.9651 },
      },
      {
        id: 'event_2',
        title: 'Product planning',
        subtitle: 'Work · Level 4',
        startsAt: todayAt(16, 0),
        reminderMinutes: 20,
        location: { label: 'Work', latitude: -37.8183, longitude: 144.9525 },
      },
    ],
    emergencyContacts: [
      { id: 'ec_1', name: 'Mom', phone: '+61 400 000 001', relationship: 'Family', inSosCircle: true },
      { id: 'ec_2', name: 'Dad', phone: '+61 400 000 002', relationship: 'Family', inSosCircle: true },
      { id: 'ec_3', name: 'Rahul', phone: '+61 400 000 003', relationship: 'Friend', inSosCircle: false },
    ],
  },
  connections: [
    { id: 'c_mom', name: 'Mom', status: 'connected', isLive: true, lastUpdated: '2 min ago', location: { label: 'Carlton', latitude: -37.8001, longitude: 144.9671 } },
    { id: 'c_rahul', name: 'Rahul', status: 'connected', isLive: true, lastUpdated: '5 min away', location: { label: 'Docklands', latitude: -37.8148, longitude: 144.9467 } },
    { id: 'c_ananya', name: 'Ananya', status: 'connected', isLive: false, lastUpdated: '1 hour ago' },
    { id: 'c_dad', name: 'Dad', status: 'connected', isLive: true, lastUpdated: '3 min away', location: { label: 'Fitzroy', latitude: -37.7984, longitude: 144.9783 } },
    { id: 'c_request', name: 'Maya Patel', status: 'pending_incoming', isLive: false, lastUpdated: 'Today' },
  ],
  groups: [
    { id: 'g_family', name: 'Family', type: 'family', memberIds: ['c_mom', 'c_dad'] },
    { id: 'g_team', name: 'Product Team', type: 'business', memberIds: ['c_rahul', 'c_ananya'] },
  ],
  permissions: [
    { connectionId: 'c_mom', mode: 'permanent' },
    { connectionId: 'c_dad', mode: 'emergency' },
  ],
  suggestions: [
    { id: 's_1', type: 'leave_earlier', title: 'Leave 10 minutes earlier', detail: 'Your 2:30 PM appointment has moderate traffic on the usual route.' },
    { id: 's_2', type: 'weather', title: 'Rain expected this afternoon', detail: 'Allow extra walking time and carry an umbrella.' },
    { id: 's_3', type: 'parking', title: 'Parking near City Care', detail: 'The east entrance car park is usually quieter after 2 PM.' },
  ],
};
