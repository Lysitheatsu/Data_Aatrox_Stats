import React from 'react';
import { mockRepository, type AppRepository } from '@/data/repository';
import { initialData } from '@/data/fixtures';
import type { AppData, ConnectionGroup, EmergencyContact, SharingMode } from '@/data/types';

interface AppDataContextValue extends AppData {
  ready: boolean;
  addConnection(name: string): void;
  removeConnection(id: string): void;
  acceptRequest(id: string): void;
  declineRequest(id: string): void;
  addGroup(name: string, memberIds: string[]): void;
  removeGroup(id: string): void;
  setPermission(connectionId: string, mode: SharingMode | null, minutes?: number): void;
  addEmergencyContact(contact: Omit<EmergencyContact, 'id'>): void;
  toggleSosCircle(id: string): void;
  toggleFavourite(place: { label?: string | null; latitude: number; longitude: number }): void;
  resetDemo(): Promise<void>;
}

const fallback: AppDataContextValue = {
  ...initialData,
  ready: false,
  addConnection: () => undefined,
  removeConnection: () => undefined,
  acceptRequest: () => undefined,
  declineRequest: () => undefined,
  addGroup: () => undefined,
  removeGroup: () => undefined,
  setPermission: () => undefined,
  addEmergencyContact: () => undefined,
  toggleSosCircle: () => undefined,
  toggleFavourite: () => undefined,
  resetDemo: async () => undefined,
};

const AppDataContext = React.createContext<AppDataContextValue>(fallback);

export function AppDataProvider({
  children,
  repository = mockRepository,
}: {
  children: React.ReactNode;
  repository?: AppRepository;
}): React.JSX.Element {
  const [data, setData] = React.useState<AppData>(initialData);
  const [ready, setReady] = React.useState(false);

  React.useEffect(() => {
    repository.load().then((loaded) => {
      setData(loaded);
      setReady(true);
    });
  }, [repository]);

  const update = React.useCallback((recipe: (current: AppData) => AppData) => {
    setData((current) => {
      const next = recipe(current);
      void repository.save(next);
      return next;
    });
  }, [repository]);

  const value = React.useMemo<AppDataContextValue>(() => ({
    ...data,
    ready,
    addConnection(name) {
      update((current) => ({
        ...current,
        connections: [...current.connections, {
          id: `c_${Date.now()}`,
          name: name.trim(),
          status: 'pending_outgoing',
          isLive: false,
          lastUpdated: 'Request sent',
        }],
      }));
    },
    removeConnection(id) {
      update((current) => ({
        ...current,
        connections: current.connections.filter((item) => item.id !== id),
        permissions: current.permissions.filter((item) => item.connectionId !== id),
        groups: current.groups.map((group) => ({
          ...group,
          memberIds: group.memberIds.filter((memberId) => memberId !== id),
        })),
      }));
    },
    acceptRequest(id) {
      update((current) => ({
        ...current,
        connections: current.connections.map((item) => item.id === id
          ? { ...item, status: 'connected', lastUpdated: 'Connected today' }
          : item),
      }));
    },
    declineRequest(id) {
      update((current) => ({ ...current, connections: current.connections.filter((item) => item.id !== id) }));
    },
    addGroup(name, memberIds) {
      const group: ConnectionGroup = { id: `g_${Date.now()}`, name: name.trim(), type: 'custom', memberIds };
      update((current) => ({ ...current, groups: [...current.groups, group] }));
    },
    removeGroup(id) {
      update((current) => ({ ...current, groups: current.groups.filter((item) => item.id !== id) }));
    },
    setPermission(connectionId, mode, minutes) {
      update((current) => ({
        ...current,
        permissions: [
          ...current.permissions.filter((item) => item.connectionId !== connectionId),
          ...(mode ? [{
            connectionId,
            mode,
            expiresAt: mode === 'time_based'
              ? new Date(Date.now() + (minutes ?? 60) * 60_000).toISOString()
              : undefined,
          }] : []),
        ],
      }));
    },
    addEmergencyContact(contact) {
      update((current) => ({
        ...current,
        profile: {
          ...current.profile,
          emergencyContacts: [...current.profile.emergencyContacts, { ...contact, id: `ec_${Date.now()}` }],
        },
      }));
    },
    toggleSosCircle(id) {
      update((current) => ({
        ...current,
        profile: {
          ...current.profile,
          emergencyContacts: current.profile.emergencyContacts.map((item) => item.id === id
            ? { ...item, inSosCircle: !item.inSosCircle }
            : item),
        },
      }));
    },
    toggleFavourite(place) {
      update((current) => {
        const exists = current.profile.savedPlaces.find((item) => item.kind === 'favourite' && item.latitude === place.latitude && item.longitude === place.longitude);
        return {
          ...current,
          profile: {
            ...current.profile,
            savedPlaces: exists
              ? current.profile.savedPlaces.filter((item) => item.id !== exists.id)
              : [...current.profile.savedPlaces, { ...place, label: place.label ?? 'Saved place', id: `fav_${Date.now()}`, kind: 'favourite' }],
          },
        };
      });
    },
    async resetDemo() {
      setData(await repository.reset());
    },
  }), [data, ready, repository, update]);

  return <AppDataContext.Provider value={value}>{children}</AppDataContext.Provider>;
}

export function useAppData(): AppDataContextValue {
  return React.useContext(AppDataContext);
}
