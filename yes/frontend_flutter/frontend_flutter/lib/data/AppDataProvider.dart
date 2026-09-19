import 'package:flutter/material.dart';
import 'repository.dart';
import 'fixtures.dart';
import 'types.dart';

typedef EmergencyContactInput = ({
  String name,
  String phone,
  String relationship,
  bool inSosCircle,
});

typedef FavouritePlaceInput = ({
  String? label,
  double latitude,
  double longitude,
});

class AppDataContextValue {
  final AppData data;
  final bool ready;
  final void Function(String name) addConnection;
  final void Function(String id) removeConnection;
  final void Function(String id) acceptRequest;
  final void Function(String id) declineRequest;
  final void Function(String name, List<String> memberIds) addGroup;
  final void Function(String id) removeGroup;
  final void Function(String connectionId, SharingMode? mode, [int? minutes]) setPermission;
  final void Function(EmergencyContactInput contact) addEmergencyContact;
  final void Function(String id) toggleSosCircle;
  final void Function(FavouritePlaceInput place) toggleFavourite;
  final Future<void> Function() resetDemo;

  AppDataContextValue({
    required this.data,
    required this.ready,
    required this.addConnection,
    required this.removeConnection,
    required this.acceptRequest,
    required this.declineRequest,
    required this.addGroup,
    required this.removeGroup,
    required this.setPermission,
    required this.addEmergencyContact,
    required this.toggleSosCircle,
    required this.toggleFavourite,
    required this.resetDemo,
  });

  UserProfile get profile => data.profile;
  List<Connection> get connections => data.connections;
  List<ConnectionGroup> get groups => data.groups;
  List<SharePermission> get permissions => data.permissions;
  List<SmartSuggestion> get suggestions => data.suggestions;
}

final fallback = AppDataContextValue(
  data: initialData,
  ready: false,
  addConnection: (name) {},
  removeConnection: (id) {},
  acceptRequest: (id) {},
  declineRequest: (id) {},
  addGroup: (name, memberIds) {},
  removeGroup: (id) {},
  setPermission: (connectionId, mode, [minutes]) {},
  addEmergencyContact: (contact) {},
  toggleSosCircle: (id) {},
  toggleFavourite: (place) {},
  resetDemo: () async {},
);

class _AppDataContext extends InheritedWidget {
  final AppDataContextValue value;

  const _AppDataContext({
    required this.value,
    required super.child,
  });

  static AppDataContextValue? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_AppDataContext>()?.value;
  }

  @override
  bool updateShouldNotify(_AppDataContext oldWidget) {
    return oldWidget.value != value;
  }
}

class AppDataProvider extends StatefulWidget {
  final Widget children;
  final AppRepository? repository;

  const AppDataProvider({
    super.key,
    required this.children,
    this.repository,
  });

  @override
  State<AppDataProvider> createState() => _AppDataProviderState();
}

class _AppDataProviderState extends State<AppDataProvider> {
  AppData data = initialData;
  bool ready = false;

  AppRepository get repository => widget.repository ?? mockRepository;

  @override
  void initState() {
    super.initState();

    repository.load().then((loaded) {
      if (!mounted) return;
      setState(() {
        data = loaded;
        ready = true;
      });
    });
  }

  @override
  void didUpdateWidget(AppDataProvider oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.repository != widget.repository) {
      repository.load().then((loaded) {
        if (!mounted) return;
        setState(() {
          data = loaded;
          ready = true;
        });
      });
    }
  }

  void update(AppData Function(AppData current) recipe) {
    setState(() {
      final next = recipe(data);
      repository.save(next);
      data = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final value = AppDataContextValue(
      data: data,
      ready: ready,
      addConnection: (name) {
        update((current) => AppData(
          profile: current.profile,
          connections: [...current.connections, Connection(
            id: 'c_${DateTime.now().millisecondsSinceEpoch}',
            name: name.trim(),
            status: 'pending_outgoing',
            isLive: false,
            lastUpdated: 'Request sent',
          )],
          groups: current.groups,
          permissions: current.permissions,
          suggestions: current.suggestions,
        ));
      },
      removeConnection: (id) {
        update((current) => AppData(
          profile: current.profile,
          connections: current.connections.where((item) => item.id != id).toList(),
          permissions: current.permissions.where((item) => item.connectionId != id).toList(),
          groups: current.groups.map((group) => ConnectionGroup(
            id: group.id,
            name: group.name,
            type: group.type,
            memberIds: group.memberIds.where((memberId) => memberId != id).toList(),
          )).toList(),
          suggestions: current.suggestions,
        ));
      },
      acceptRequest: (id) {
        update((current) => AppData(
          profile: current.profile,
          connections: current.connections.map((item) => item.id == id
            ? Connection(
                id: item.id,
                name: item.name,
                status: 'connected',
                isLive: item.isLive,
                lastUpdated: 'Connected today',
                location: item.location,
              )
            : item).toList(),
          groups: current.groups,
          permissions: current.permissions,
          suggestions: current.suggestions,
        ));
      },
      declineRequest: (id) {
        update((current) => AppData(
          profile: current.profile,
          connections: current.connections.where((item) => item.id != id).toList(),
          groups: current.groups,
          permissions: current.permissions,
          suggestions: current.suggestions,
        ));
      },
      addGroup: (name, memberIds) {
        final group = ConnectionGroup(
          id: 'g_${DateTime.now().millisecondsSinceEpoch}',
          name: name.trim(),
          type: 'custom',
          memberIds: memberIds,
        );
        update((current) => AppData(
          profile: current.profile,
          connections: current.connections,
          groups: [...current.groups, group],
          permissions: current.permissions,
          suggestions: current.suggestions,
        ));
      },
      removeGroup: (id) {
        update((current) => AppData(
          profile: current.profile,
          connections: current.connections,
          groups: current.groups.where((item) => item.id != id).toList(),
          permissions: current.permissions,
          suggestions: current.suggestions,
        ));
      },
      setPermission: (connectionId, mode, [minutes]) {
        update((current) => AppData(
          profile: current.profile,
          connections: current.connections,
          groups: current.groups,
          permissions: [
            ...current.permissions.where((item) => item.connectionId != connectionId),
            if (mode != null) SharePermission(
              connectionId: connectionId,
              mode: mode,
              expiresAt: mode == 'time_based'
                ? DateTime.now().add(Duration(minutes: minutes ?? 60)).toUtc().toIso8601String()
                : null,
            ),
          ],
          suggestions: current.suggestions,
        ));
      },
      addEmergencyContact: (contact) {
        update((current) => AppData(
          profile: UserProfile(
            id: current.profile.id,
            displayName: current.profile.displayName,
            savedPlaces: current.profile.savedPlaces,
            calendarEvents: current.profile.calendarEvents,
            emergencyContacts: [...current.profile.emergencyContacts, EmergencyContact(
              id: 'ec_${DateTime.now().millisecondsSinceEpoch}',
              name: contact.name,
              phone: contact.phone,
              relationship: contact.relationship,
              inSosCircle: contact.inSosCircle,
            )],
          ),
          connections: current.connections,
          groups: current.groups,
          permissions: current.permissions,
          suggestions: current.suggestions,
        ));
      },
      toggleSosCircle: (id) {
        update((current) => AppData(
          profile: UserProfile(
            id: current.profile.id,
            displayName: current.profile.displayName,
            savedPlaces: current.profile.savedPlaces,
            calendarEvents: current.profile.calendarEvents,
            emergencyContacts: current.profile.emergencyContacts.map((item) => item.id == id
              ? EmergencyContact(
                  id: item.id,
                  name: item.name,
                  phone: item.phone,
                  relationship: item.relationship,
                  inSosCircle: !item.inSosCircle,
                )
              : item).toList(),
          ),
          connections: current.connections,
          groups: current.groups,
          permissions: current.permissions,
          suggestions: current.suggestions,
        ));
      },
      toggleFavourite: (place) {
        update((current) {
          SavedPlace? exists;
          for (final item in current.profile.savedPlaces) {
            if (item.kind == 'favourite' && item.latitude == place.latitude && item.longitude == place.longitude) {
              exists = item;
              break;
            }
          }
          return AppData(
            profile: UserProfile(
              id: current.profile.id,
              displayName: current.profile.displayName,
              savedPlaces: exists != null
                ? current.profile.savedPlaces.where((item) => item.id != exists!.id).toList()
                : [...current.profile.savedPlaces, SavedPlace(
                    id: 'fav_${DateTime.now().millisecondsSinceEpoch}',
                    kind: 'favourite',
                    label: place.label ?? 'Saved place',
                    latitude: place.latitude,
                    longitude: place.longitude,
                  )],
              calendarEvents: current.profile.calendarEvents,
              emergencyContacts: current.profile.emergencyContacts,
            ),
            connections: current.connections,
            groups: current.groups,
            permissions: current.permissions,
            suggestions: current.suggestions,
          );
        });
      },
      resetDemo: () async {
        final reset = await repository.reset();
        if (!mounted) return;
        setState(() {
          data = reset;
        });
      },
    );

    return _AppDataContext(value: value, child: widget.children);
  }
}

AppDataContextValue useAppData(BuildContext context) {
  return _AppDataContext.maybeOf(context) ?? fallback;
}