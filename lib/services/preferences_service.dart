import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:android_id/android_id.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PreferencesService {
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _introShownKey = 'intro_shown';
  static const _contactsCreatedKey = 'contacts_created_count';
  static const _purchaseUnlockedKey = 'purchase_unlocked';

  // ── Public API ──────────────────────────────────────────────────────────────

  static Future<bool> hasShownIntro() async {
    return await _storage.read(key: _introShownKey) == 'true';
  }

  static Future<void> setIntroShown({required bool value}) async {
    await _storage.write(key: _introShownKey, value: value.toString());
  }

  static Future<int> getContactsCreated() async {
    return int.tryParse(await _storage.read(key: _contactsCreatedKey) ?? '') ??
        0;
  }

  static Future<void> incrementContactsCreated() async {
    final newCount = await getContactsCreated() + 1;
    await _storage.write(key: _contactsCreatedKey, value: newCount.toString());
    if (Platform.isAndroid) {
      unawaited(_backupToFirestore(contactsCreated: newCount));
    }
  }

  static Future<bool> isPurchaseUnlocked() async {
    return await _storage.read(key: _purchaseUnlockedKey) == 'true';
  }

  static Future<void> setPurchaseUnlocked() async {
    await _storage.write(key: _purchaseUnlockedKey, value: 'true');
  }

  /// Call once during app startup. On Android, checks Firestore for a backed-up
  /// count and restores it if higher than the local value — recovers the count
  /// after a reinstall, since EncryptedSharedPreferences is wiped on reinstall
  /// while ANDROID_ID (the Firestore key) is not.
  static Future<void> syncFromFirestoreIfNeeded() async {
    if (!Platform.isAndroid) return;
    try {
      final deviceId = await _androidDeviceId();
      final doc = await FirebaseFirestore.instance
          .collection('device_limits')
          .doc(deviceId)
          .get();
      if (!doc.exists) return;
      final remote = (doc.data()?['contacts_created'] as num?)?.toInt() ?? 0;
      final local = await getContactsCreated();
      if (remote > local) {
        await _storage.write(
            key: _contactsCreatedKey, value: remote.toString());
      }
    } catch (_) {
      // Offline or Firestore unavailable — local value is source of truth.
    }
  }

  // ── Testing helpers ─────────────────────────────────────────────────────────

  @visibleForTesting
  static void resetForTesting() {}

  // ── Internals ────────────────────────────────────────────────────────────────

  static Future<String> _androidDeviceId() async {
    return await const AndroidId().getId() ?? _newUuid();
  }

  static Future<void> _backupToFirestore({required int contactsCreated}) async {
    try {
      final deviceId = await _androidDeviceId();
      await FirebaseFirestore.instance
          .collection('device_limits')
          .doc(deviceId)
          .set(
        {'contacts_created': contactsCreated},
        SetOptions(merge: true),
      );
    } catch (_) {
      // Best effort — local value is source of truth.
    }
  }

  static String _newUuid() {
    final b = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((v) => v.toRadixString(16).padLeft(2, '0')).toList();
    return '${h.sublist(0, 4).join()}-${h.sublist(4, 6).join()}-'
        '${h.sublist(6, 8).join()}-${h.sublist(8, 10).join()}-'
        '${h.sublist(10, 16).join()}';
  }
}
