import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple TTL-based persistent cache using SharedPreferences.
/// Usage: CacheManager.set("key", data, ttlMinutes: 5)
///        CacheManager.get("key") -> returns null if expired/missing
class CacheManager {
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> get _instance async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Store any JSON-serializable object with a TTL
  static Future<void> set(String key, dynamic data, {int ttlMinutes = 5}) async {
    final prefs = await _instance;
    final payload = jsonEncode({
      'data': data,
      'expiry': DateTime.now().add(Duration(minutes: ttlMinutes)).millisecondsSinceEpoch,
    });
    await prefs.setString('cache_$key', payload);
  }

  /// Get cached value — returns null if missing or expired
  static Future<dynamic> get(String key) async {
    final prefs = await _instance;
    final raw = prefs.getString('cache_$key');
    if (raw == null) return null;

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final expiry = map['expiry'] as int;
      if (DateTime.now().millisecondsSinceEpoch > expiry) {
        await prefs.remove('cache_$key');
        return null; // expired
      }
      return map['data'];
    } catch (_) {
      return null;
    }
  }

  /// Invalidate a specific key
  static Future<void> invalidate(String key) async {
    final prefs = await _instance;
    await prefs.remove('cache_$key');
  }

  /// Invalidate all cached data
  static Future<void> invalidateAll() async {
    final prefs = await _instance;
    final keys = prefs.getKeys().where((k) => k.startsWith('cache_')).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }

  /// Check if a key is cached and fresh
  static Future<bool> isFresh(String key) async {
    final data = await get(key);
    return data != null;
  }
}

/// Cache keys constants
class CacheKeys {
  static const userProfile = 'user_profile';
  static const recentNotes = 'recent_notes';
  static const banners = 'banners';
  static const notifCount = 'notif_count';
}
