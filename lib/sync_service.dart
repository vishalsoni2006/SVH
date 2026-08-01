import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'db_helper.dart';

class SyncService {
  static Future<int> syncPendingReadings() async {
    final pending = await DBHelper.getPendingReadings();
    debugPrint('SyncService: found ${pending.length} pending reading(s)');
    int syncedCount = 0;

    for (final reading in pending) {
      final id = reading['id'] as int;
      try {
        final photoPath = reading['photo_path'] as String?;

        if (photoPath == null || !File(photoPath).existsSync()) {
          debugPrint('SyncService: reading id=$id has no valid photo file at "$photoPath" — skipping');
          continue;
        }

        debugPrint('SyncService: uploading photo for reading id=$id from $photoPath');
        final ref = FirebaseStorage.instance.ref('photos/reading_$id.jpg');
        await ref.putFile(File(photoPath));
        final photoUrl = await ref.getDownloadURL();
        debugPrint('SyncService: photo uploaded, url=$photoUrl');

        await FirebaseFirestore.instance.collection('readings').add({
          'local_id': id,
          'site_id': reading['site_id'],
          'value': reading['value'],
          'lat': reading['lat'],
          'lng': reading['lng'],
          'timestamp': reading['timestamp'],
          'photo_url': photoUrl,
          'capture_hash': reading['capture_hash'],
          'previous_hash': reading['previous_hash'],
          'had_mismatch': reading['had_mismatch'],
          'verification_status': 'pending', // supervisor will change this
          'uploaded_at': FieldValue.serverTimestamp(),
        });

        await DBHelper.markSynced(id);
        syncedCount++;
        debugPrint('SyncService: successfully synced reading id=$id');
      } catch (e, stack) {
        debugPrint('SyncService ERROR on reading id=$id: $e');
        debugPrint('Stack: $stack');
        // stays pending_sync, retried next time
      }
    }
    debugPrint('SyncService: sync complete, $syncedCount reading(s) synced');
    return syncedCount;
  }
}