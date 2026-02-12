class OnboardingData {
  final String profileId;
  final String username;
  final String pairingCode;
  final String? avatarUrl;
  final String? joinedCode;
  final List<String> joinedCodes;

  const OnboardingData({
    required this.profileId,
    required this.username,
    required this.pairingCode,
    this.avatarUrl,
    this.joinedCode,
    this.joinedCodes = const [],
  });
}
