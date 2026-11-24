
import 'dart:convert';
import 'dart:math';

class QrTokenService {
  QrTokenService._();

  static String generateSecureToken() {
    final random = Random.secure();

    // 16 bytes = 128 bits of randomness
    final bytes = List<int>.generate(
      16,
      (_) => random.nextInt(256),
    );

    final hexString = bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    // Use the complete token
    return 'ATT-${hexString.toUpperCase()}';
  }

  static String encodeQrPayload({
    required Object sessionId,
    required String token,
    required DateTime createdAt,
    required DateTime expiresAt,
  }) {
    return jsonEncode({
      'session_id': sessionId.toString(),
      'token': token,
      'created_at': createdAt.toUtc().toIso8601String(),
      'expires_at': expiresAt.toUtc().toIso8601String(),
    });
  }

  static Map<String, dynamic>? decodeQrPayload(String rawPayload) {
    try {
      final decoded = jsonDecode(rawPayload.trim());

      if (decoded is Map<String, dynamic> &&
          (decoded['session_id'] is String ||
              decoded['session_id'] is num) &&
          decoded['token'] is String &&
          decoded['expires_at'] != null) {
        return decoded;
      }

      return null;
    } catch (_) {
      return null;
    }
  }
}
