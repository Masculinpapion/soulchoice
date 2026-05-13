class AppConstants {
  AppConstants._();

  static const String appName = 'SoulChoice';
  static const String appSlogan = 'Choose Your Night';

  // Age limits
  static const int minAge = 21;
  static const int maxAge = 60;

  // Invitation
  static const Duration invitationDuration = Duration(hours: 24);
  static const Duration selectionTimeout = Duration(hours: 1);
  static const int maxActiveInvitations = 1;
  static const int maxActiveApplications = 20;

  // Photos
  static const int minPhotos = 3;
  static const int maxPhotos = 6;

  // Bio
  static const int maxBioLength = 200;

  // Warnings
  static const int maxCancellationsPerMonth = 3;
  static const int warningsBeforeBan = 3;

  // Support
  static const String supportEmail = 'support@soulchoice.app';
}
