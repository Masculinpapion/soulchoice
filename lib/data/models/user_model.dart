class UserModel {
  final String id;
  final String phone;
  final String? countryCode;
  final String? language;
  final String name;
  final int age;
  final String gender;
  final String? cityId;
  final String? bio;
  final String? job;
  final String? education;
  final List<String> interests;
  final bool verified;
  final DateTime? verifiedAt;
  final String subscriptionStatus;
  final bool banned;
  final int warningCount;
  final DateTime createdAt;
  final DateTime? lastActiveAt;

  const UserModel({
    required this.id,
    required this.phone,
    this.countryCode,
    this.language,
    required this.name,
    required this.age,
    required this.gender,
    this.cityId,
    this.bio,
    this.job,
    this.education,
    this.interests = const [],
    this.verified = false,
    this.verifiedAt,
    this.subscriptionStatus = 'free',
    this.banned = false,
    this.warningCount = 0,
    required this.createdAt,
    this.lastActiveAt,
  });

  bool get isPremium => subscriptionStatus == 'active';

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        phone: json['phone'] as String,
        countryCode: json['country_code'] as String?,
        language: json['language'] as String?,
        name: json['name'] as String,
        age: json['age'] as int,
        gender: json['gender'] as String,
        cityId: json['city_id'] as String?,
        bio: json['bio'] as String?,
        job: json['job'] as String?,
        education: json['education'] as String?,
        interests: (json['interests'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        verified: json['verified'] as bool? ?? false,
        verifiedAt: json['verified_at'] != null
            ? DateTime.parse(json['verified_at'] as String)
            : null,
        subscriptionStatus:
            json['subscription_status'] as String? ?? 'free',
        banned: json['banned'] as bool? ?? false,
        warningCount: json['warning_count'] as int? ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
        lastActiveAt: json['last_active_at'] != null
            ? DateTime.parse(json['last_active_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'country_code': countryCode,
        'language': language,
        'name': name,
        'age': age,
        'gender': gender,
        'city_id': cityId,
        'bio': bio,
        'job': job,
        'education': education,
        'interests': interests,
        'verified': verified,
        'verified_at': verifiedAt?.toIso8601String(),
        'subscription_status': subscriptionStatus,
        'banned': banned,
        'warning_count': warningCount,
        'created_at': createdAt.toIso8601String(),
        'last_active_at': lastActiveAt?.toIso8601String(),
      };

  UserModel copyWith({
    String? id,
    String? phone,
    String? countryCode,
    String? language,
    String? name,
    int? age,
    String? gender,
    String? cityId,
    String? bio,
    String? job,
    String? education,
    List<String>? interests,
    bool? verified,
    DateTime? verifiedAt,
    String? subscriptionStatus,
    bool? banned,
    int? warningCount,
    DateTime? createdAt,
    DateTime? lastActiveAt,
  }) =>
      UserModel(
        id: id ?? this.id,
        phone: phone ?? this.phone,
        countryCode: countryCode ?? this.countryCode,
        language: language ?? this.language,
        name: name ?? this.name,
        age: age ?? this.age,
        gender: gender ?? this.gender,
        cityId: cityId ?? this.cityId,
        bio: bio ?? this.bio,
        job: job ?? this.job,
        education: education ?? this.education,
        interests: interests ?? this.interests,
        verified: verified ?? this.verified,
        verifiedAt: verifiedAt ?? this.verifiedAt,
        subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
        banned: banned ?? this.banned,
        warningCount: warningCount ?? this.warningCount,
        createdAt: createdAt ?? this.createdAt,
        lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      );
}
