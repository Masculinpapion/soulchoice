import 'user_model.dart';

enum InvitationFlowType { invite, request }
enum InvitationStatus { active, matched, closed, cancelled }
enum InvitationCategory {
  food,
  concert,
  travel,
  culture,
  cinema,
  theater,
  coffee,
}

extension InvitationCategoryExt on InvitationCategory {
  String get label {
    switch (this) {
      case InvitationCategory.food:
        return 'Yemek';
      case InvitationCategory.concert:
        return 'Konser';
      case InvitationCategory.travel:
        return 'Seyahat';
      case InvitationCategory.culture:
        return 'Kültür';
      case InvitationCategory.cinema:
        return 'Sinema';
      case InvitationCategory.theater:
        return 'Tiyatro';
      case InvitationCategory.coffee:
        return 'Kahve';
    }
  }

  String get emoji {
    switch (this) {
      case InvitationCategory.food:
        return '🍽';
      case InvitationCategory.concert:
        return '🎵';
      case InvitationCategory.travel:
        return '✈️';
      case InvitationCategory.culture:
        return '🎨';
      case InvitationCategory.cinema:
        return '🎬';
      case InvitationCategory.theater:
        return '🎭';
      case InvitationCategory.coffee:
        return '☕';
    }
  }
}

class InvitationModel {
  final String id;
  final String ownerId;
  final InvitationFlowType flowType;
  final InvitationCategory category;
  final String title;
  final String? description;
  final String? venueName;
  final double? venueLat;
  final double? venueLng;
  final DateTime? eventDate;
  final String cityId;
  final int slotsTotal;
  final InvitationStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;

  // Joined data
  final UserModel? owner;
  final int? applicationCount;

  const InvitationModel({
    required this.id,
    required this.ownerId,
    required this.flowType,
    required this.category,
    required this.title,
    this.description,
    this.venueName,
    this.venueLat,
    this.venueLng,
    this.eventDate,
    required this.cityId,
    this.slotsTotal = 1,
    this.status = InvitationStatus.active,
    required this.createdAt,
    required this.expiresAt,
    this.owner,
    this.applicationCount,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  Duration get timeRemaining => expiresAt.difference(DateTime.now());

  factory InvitationModel.fromJson(Map<String, dynamic> json) =>
      InvitationModel(
        id: json['id'] as String,
        ownerId: json['owner_id'] as String,
        flowType: json['flow_type'] == 'invite'
            ? InvitationFlowType.invite
            : InvitationFlowType.request,
        category: InvitationCategory.values.firstWhere(
          (c) => c.name == json['category'],
          orElse: () => InvitationCategory.food,
        ),
        title: json['title'] as String,
        description: json['description'] as String?,
        venueName: json['venue_name'] as String?,
        venueLat: (json['venue_lat'] as num?)?.toDouble(),
        venueLng: (json['venue_lng'] as num?)?.toDouble(),
        eventDate: json['event_date'] != null
            ? DateTime.parse(json['event_date'] as String)
            : null,
        cityId: json['city_id'] as String,
        slotsTotal: json['slots_total'] as int? ?? 1,
        status: InvitationStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => InvitationStatus.active,
        ),
        createdAt: DateTime.parse(json['created_at'] as String),
        expiresAt: DateTime.parse(json['expires_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'owner_id': ownerId,
        'flow_type': flowType.name,
        'category': category.name,
        'title': title,
        'description': description,
        'venue_name': venueName,
        'venue_lat': venueLat,
        'venue_lng': venueLng,
        'event_date': eventDate?.toIso8601String(),
        'city_id': cityId,
        'slots_total': slotsTotal,
        'status': status.name,
      };
}

