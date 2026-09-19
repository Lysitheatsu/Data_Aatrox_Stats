import '../api/client.dart';

typedef SharingMode = String;
typedef ConnectionStatus = String;
typedef GroupType = String;

class Connection {
  String id;
  String name;
  ConnectionStatus status;
  bool isLive;
  String lastUpdated;
  GeoLocation? location;

  Connection({
    required this.id,
    required this.name,
    required this.status,
    required this.isLive,
    required this.lastUpdated,
    this.location,
  });

  factory Connection.fromJson(Map<String, dynamic> json) {
    return Connection(
      id: json['id'],
      name: json['name'],
      status: json['status'],
      isLive: json['isLive'],
      lastUpdated: json['lastUpdated'],
      location: json['location'] != null ? GeoLocation.fromJson(json['location']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status,
      'isLive': isLive,
      'lastUpdated': lastUpdated,
      if (location != null) 'location': location!.toJson(),
    };
  }
}

class ConnectionGroup {
  String id;
  String name;
  GroupType type;
  List<String> memberIds;

  ConnectionGroup({
    required this.id,
    required this.name,
    required this.type,
    required this.memberIds,
  });

  factory ConnectionGroup.fromJson(Map<String, dynamic> json) {
    return ConnectionGroup(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      memberIds: List<String>.from(json['memberIds']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'memberIds': memberIds,
    };
  }
}

class SharePermission {
  String connectionId;
  SharingMode mode;
  String? expiresAt;

  SharePermission({
    required this.connectionId,
    required this.mode,
    this.expiresAt,
  });

  factory SharePermission.fromJson(Map<String, dynamic> json) {
    return SharePermission(
      connectionId: json['connectionId'],
      mode: json['mode'],
      expiresAt: json['expiresAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'connectionId': connectionId,
      'mode': mode,
      if (expiresAt != null) 'expiresAt': expiresAt,
    };
  }
}

class CalendarEvent {
  String id;
  String title;
  String subtitle;
  String startsAt;
  GeoLocation location;
  int reminderMinutes;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.startsAt,
    required this.location,
    required this.reminderMinutes,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'],
      title: json['title'],
      subtitle: json['subtitle'],
      startsAt: json['startsAt'],
      location: GeoLocation.fromJson(json['location']),
      reminderMinutes: (json['reminderMinutes'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'startsAt': startsAt,
      'location': location.toJson(),
      'reminderMinutes': reminderMinutes,
    };
  }
}

class SavedPlace extends GeoLocation {
  String id;
  String kind;

  SavedPlace({
    required this.id,
    required this.kind,
    super.label,
    super.address,
    required super.latitude,
    required super.longitude,
  });

  factory SavedPlace.fromJson(Map<String, dynamic> json) {
    return SavedPlace(
      id: json['id'],
      kind: json['kind'],
      label: json['label'],
      address: json['address'],
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'id': id,
      'kind': kind,
    };
  }
}

class EmergencyContact {
  String id;
  String name;
  String phone;
  String relationship;
  bool inSosCircle;

  EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.relationship,
    required this.inSosCircle,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      relationship: json['relationship'],
      inSosCircle: json['inSosCircle'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'relationship': relationship,
      'inSosCircle': inSosCircle,
    };
  }
}

class UserProfile {
  String id;
  String displayName;
  List<SavedPlace> savedPlaces;
  List<CalendarEvent> calendarEvents;
  List<EmergencyContact> emergencyContacts;

  UserProfile({
    required this.id,
    required this.displayName,
    required this.savedPlaces,
    required this.calendarEvents,
    required this.emergencyContacts,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      displayName: json['displayName'],
      savedPlaces: (json['savedPlaces'] as List)
        .map((item) => SavedPlace.fromJson(item))
        .toList(),
      calendarEvents: (json['calendarEvents'] as List)
        .map((item) => CalendarEvent.fromJson(item))
        .toList(),
      emergencyContacts: (json['emergencyContacts'] as List)
        .map((item) => EmergencyContact.fromJson(item))
        .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'savedPlaces': savedPlaces.map((item) => item.toJson()).toList(),
      'calendarEvents': calendarEvents.map((item) => item.toJson()).toList(),
      'emergencyContacts': emergencyContacts.map((item) => item.toJson()).toList(),
    };
  }
}

class SmartSuggestion {
  String id;
  String type;
  String title;
  String detail;

  SmartSuggestion({
    required this.id,
    required this.type,
    required this.title,
    required this.detail,
  });

  factory SmartSuggestion.fromJson(Map<String, dynamic> json) {
    return SmartSuggestion(
      id: json['id'],
      type: json['type'],
      title: json['title'],
      detail: json['detail'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'detail': detail,
    };
  }
}

class AppData {
  UserProfile profile;
  List<Connection> connections;
  List<ConnectionGroup> groups;
  List<SharePermission> permissions;
  List<SmartSuggestion> suggestions;

  AppData({
    required this.profile,
    required this.connections,
    required this.groups,
    required this.permissions,
    required this.suggestions,
  });

  factory AppData.fromJson(Map<String, dynamic> json) {
    return AppData(
      profile: UserProfile.fromJson(json['profile']),
      connections: (json['connections'] as List)
        .map((item) => Connection.fromJson(item))
        .toList(),
      groups: (json['groups'] as List)
        .map((item) => ConnectionGroup.fromJson(item))
        .toList(),
      permissions: (json['permissions'] as List)
        .map((item) => SharePermission.fromJson(item))
        .toList(),
      suggestions: (json['suggestions'] as List)
        .map((item) => SmartSuggestion.fromJson(item))
        .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'profile': profile.toJson(),
      'connections': connections.map((item) => item.toJson()).toList(),
      'groups': groups.map((item) => item.toJson()).toList(),
      'permissions': permissions.map((item) => item.toJson()).toList(),
      'suggestions': suggestions.map((item) => item.toJson()).toList(),
    };
  }
}