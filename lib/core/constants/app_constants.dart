class AppConstants {
  AppConstants._();

  static const String appName = 'SoulChoice';
  static const String appSlogan = 'Choose Your Moment';

  // Age limits
  static const int minAge = 21;
  static const int maxAge = 60;

  // Invitation
  static const Duration invitationDuration = Duration(hours: 24);
  static const Duration selectionTimeout = Duration(hours: 1);
  static const int maxActiveInvitations = 1;
  static const int maxActiveApplications = 20;

  // Photos
  // 02.09.2026 (Mustafa): 3 zorunlu fotoğraf kayıtta kopuş noktasıydı (Гоша 28.08,
  // Александр 01.09 — ikisi de bu ekranda pes etti). Devam için 1 fotoğraf yeter;
  // kalanlar profilden sonra eklenir.
  static const int minPhotos = 1;
  static const int maxPhotos = 6;

  // Bio
  static const int maxBioLength = 200;

  // Warnings
  static const int maxCancellationsPerMonth = 3;
  static const int warningsBeforeBan = 3;

  // Support
  static const String supportEmail = 'support@soulchoice.app';
}
