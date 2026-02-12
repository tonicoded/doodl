import 'dart:math';

String generateShortCode({int length = 8}) {
  const chars = 'abcdefghjkmnpqrstuvwxyz23456789';
  final rnd = Random.secure();
  return List.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();
}
