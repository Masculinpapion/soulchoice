import 'package:soulchoice/l10n/app_localizations.dart';

import 'user_model.dart';

enum InvitationFlowType { invite, request }
enum InvitationStatus { active, matched, closed, cancelled }
enum InvitationCategory {
  food,
  bar,
  concert,
  travel,
  culture,
  cinema,
  theater,
  coffee,
  gift,
}

extension InvitationCategoryExt on InvitationCategory {
  String labelFor(AppLocalizations l10n) {
    switch (this) {
      case InvitationCategory.food:
        return l10n.category_food;
      case InvitationCategory.bar:
        return l10n.category_bar;
      case InvitationCategory.concert:
        return l10n.category_concert;
      case InvitationCategory.travel:
        return l10n.category_travel;
      case InvitationCategory.culture:
        return l10n.category_culture;
      case InvitationCategory.cinema:
        return l10n.category_cinema;
      case InvitationCategory.theater:
        return l10n.category_theater;
      case InvitationCategory.coffee:
        return l10n.category_coffee;
      case InvitationCategory.gift:
        return l10n.category_gift;
    }
  }

  String get emoji {
    switch (this) {
      case InvitationCategory.food:
        return '🍽';
      case InvitationCategory.bar:
        return '🥂';
      case InvitationCategory.concert:
        return '♫';
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
      case InvitationCategory.gift:
        return '🎁';
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
  final String? ownerPhotoUrl;
  final List<String> applicantPhotoUrls;
  final String? cityName;

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
    this.ownerPhotoUrl,
    this.applicantPhotoUrls = const [],
    this.cityName,
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
        cityId: json['city_id'] as String? ?? '',
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

  InvitationModel copyWith({
    UserModel? owner,
    int? applicationCount,
    String? ownerPhotoUrl,
    List<String>? applicantPhotoUrls,
    String? cityName,
  }) =>
      InvitationModel(
        id: id,
        ownerId: ownerId,
        flowType: flowType,
        category: category,
        title: title,
        description: description,
        venueName: venueName,
        venueLat: venueLat,
        venueLng: venueLng,
        eventDate: eventDate,
        cityId: cityId,
        slotsTotal: slotsTotal,
        status: status,
        createdAt: createdAt,
        expiresAt: expiresAt,
        owner: owner ?? this.owner,
        applicationCount: applicationCount ?? this.applicationCount,
        ownerPhotoUrl: ownerPhotoUrl ?? this.ownerPhotoUrl,
        applicantPhotoUrls: applicantPhotoUrls ?? this.applicantPhotoUrls,
        cityName: cityName ?? this.cityName,
      );
}

