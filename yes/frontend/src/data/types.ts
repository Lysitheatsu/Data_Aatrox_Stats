import type { GeoLocation } from '@/api/client';

export type SharingMode = 'time_based' | 'permanent' | 'emergency';
export type ConnectionStatus = 'connected' | 'pending_incoming' | 'pending_outgoing';
export type GroupType = 'family' | 'business' | 'custom';

export interface Connection {
  id: string;
  name: string;
  status: ConnectionStatus;
  isLive: boolean;
  lastUpdated: string;
  location?: GeoLocation;
}

export interface ConnectionGroup {
  id: string;
  name: string;
  type: GroupType;
  memberIds: string[];
}

export interface SharePermission {
  connectionId: string;
  mode: SharingMode;
  expiresAt?: string;
}

export interface CalendarEvent {
  id: string;
  title: string;
  subtitle: string;
  startsAt: string;
  location: GeoLocation;
  reminderMinutes: number;
}

export interface SavedPlace extends GeoLocation {
  id: string;
  kind: 'home' | 'work' | 'favourite' | 'recent';
}

export interface EmergencyContact {
  id: string;
  name: string;
  phone: string;
  relationship: string;
  inSosCircle: boolean;
}

export interface UserProfile {
  id: string;
  displayName: string;
  savedPlaces: SavedPlace[];
  calendarEvents: CalendarEvent[];
  emergencyContacts: EmergencyContact[];
}

export interface SmartSuggestion {
  id: string;
  type: 'leave_earlier' | 'traffic' | 'weather' | 'appointment' | 'parking' | 'route';
  title: string;
  detail: string;
}

export interface AppData {
  profile: UserProfile;
  connections: Connection[];
  groups: ConnectionGroup[];
  permissions: SharePermission[];
  suggestions: SmartSuggestion[];
}
