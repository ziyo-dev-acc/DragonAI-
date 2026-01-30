import 'package:intl/intl.dart';

import '../models/intent.dart';
import '../platform/android_bridge.dart';
import '../storage/document_index_store.dart';

class SkillEngine {
  SkillEngine({DocumentIndexStore? documentIndexStore})
      : _documentIndexStore = documentIndexStore;

  final DocumentIndexStore? _documentIndexStore;

  Future<IntentResult> execute(IntentMatch match) async {
    switch (match.type) {
      case IntentType.findLatestFile:
        return _findLatest(match);
      case IntentType.findFile:
        return _findFile(match);
      case IntentType.shareFileToTelegram:
        return _shareToTelegram(match);
      case IntentType.openApp:
        return _openApp(match);
      case IntentType.openCameraSelfie:
        await AndroidBridge.openCameraSelfie();
        return const IntentResult(
          type: IntentType.openCameraSelfie,
          success: true,
          response: 'Camera opened.',
        );
      case IntentType.setTimer:
        final minutes = match.slots['minutes'] as int?;
        if (minutes == null) {
          return const IntentResult(
            type: IntentType.setTimer,
            success: false,
            response: 'Could not determine timer duration.',
          );
        }
        await AndroidBridge.setTimer(minutes);
        return IntentResult(
          type: IntentType.setTimer,
          success: true,
          response: 'Timer set for $minutes minutes.',
        );
      case IntentType.setAlarm:
        final time = match.slots['time'] as String?;
        if (time == null) {
          return const IntentResult(
            type: IntentType.setAlarm,
            success: false,
            response: 'Could not determine alarm time.',
          );
        }
        await AndroidBridge.setAlarm(time);
        return IntentResult(
          type: IntentType.setAlarm,
          success: true,
          response: 'Alarm set for $time.',
        );
      case IntentType.getTime:
        final now = await AndroidBridge.getTime() ??
            DateFormat.Hm().format(DateTime.now());
        return IntentResult(
          type: IntentType.getTime,
          success: true,
          response: 'It is $now.',
        );
      case IntentType.getBatteryPercent:
        final battery = await AndroidBridge.getBatteryPercent();
        if (battery == null) {
          return const IntentResult(
            type: IntentType.getBatteryPercent,
            success: false,
            response: 'Could not get battery status.',
          );
        }
        return IntentResult(
          type: IntentType.getBatteryPercent,
          success: true,
          response: 'Battery is at $battery%.',
        );
      case IntentType.getStorageFree:
        final mb = await AndroidBridge.getStorageFreeMb();
        if (mb == null) {
          return const IntentResult(
            type: IntentType.getStorageFree,
            success: false,
            response: 'Could not get storage info.',
          );
        }
        return IntentResult(
          type: IntentType.getStorageFree,
          success: true,
          response: 'Free space: $mb MB.',
        );
      case IntentType.flashlight:
        final on = match.slots['on'] as bool? ?? false;
        final ok = await AndroidBridge.setFlashlight(on);
        return IntentResult(
          type: IntentType.flashlight,
          success: ok,
          response:
              ok ? 'Flashlight toggled.' : 'Could not control flashlight.',
        );
      case IntentType.setBrightness:
        final percent = match.slots['percent'] as int?;
        if (percent == null) {
          return const IntentResult(
            type: IntentType.setBrightness,
            success: false,
            response: 'Could not determine brightness level.',
          );
        }
        final ok = await AndroidBridge.setBrightness(percent);
        return IntentResult(
          type: IntentType.setBrightness,
          success: ok,
          response:
              ok ? 'Brightness set.' : 'Permission required for brightness.',
        );
      case IntentType.setVolume:
        final level = match.slots['level'] as int?;
        if (level == null) {
          return const IntentResult(
            type: IntentType.setVolume,
            success: false,
            response: 'Could not determine volume level.',
          );
        }
        final ok = await AndroidBridge.setVolume(level);
        return IntentResult(
          type: IntentType.setVolume,
          success: ok,
          response: ok ? 'Volume set.' : 'Permission required for volume.',
        );
      case IntentType.wifiSettings:
        await AndroidBridge.openWifiSettings();
        return const IntentResult(
          type: IntentType.wifiSettings,
          success: true,
          response: 'Opened Wi-Fi settings.',
        );
      case IntentType.bluetoothSettings:
        await AndroidBridge.openBluetoothSettings();
        return const IntentResult(
          type: IntentType.bluetoothSettings,
          success: true,
          response: 'Opened Bluetooth settings.',
        );
      case IntentType.readLastTelegramNotification:
        final sender = match.slots['senderContains'] as String?;
        final notif = await AndroidBridge.getLastTelegramNotification(
            senderContains: sender);
        if (notif == null) {
          return const IntentResult(
            type: IntentType.readLastTelegramNotification,
            success: false,
            response: 'Telegram message not found.',
          );
        }
        final text = notif['text'] ?? 'Message available.';
        return IntentResult(
          type: IntentType.readLastTelegramNotification,
          success: true,
          response: text,
          data: notif,
        );
      case IntentType.unknown:
        return const IntentResult(
          type: IntentType.unknown,
          success: false,
          response: 'I did not understand the command.',
        );
    }
  }

  Future<IntentResult> _findLatest(IntentMatch match) async {
    final type = match.slots['type'] as String? ?? 'any';
    if (type == 'pdf' && _documentIndexStore != null) {
      final doc = await _documentIndexStore.latestPdf();
      if (doc != null) {
        return IntentResult(
          type: IntentType.findLatestFile,
          success: true,
          response: 'Latest PDF found: ${doc['name']}',
          data: doc,
        );
      }
    }
    final file = await AndroidBridge.getLatestFile(type);
    if (file == null) {
      return const IntentResult(
        type: IntentType.findLatestFile,
        success: false,
        response: 'Latest file not found.',
      );
    }
    return IntentResult(
      type: IntentType.findLatestFile,
      success: true,
      response: 'Latest file found: ${file['name']}',
      data: file,
    );
  }

  Future<IntentResult> _findFile(IntentMatch match) async {
    final query = match.slots['query'] as String? ?? '';
    if (query.isEmpty) {
      return const IntentResult(
        type: IntentType.findFile,
        success: false,
        response: 'Search query required.',
      );
    }
    final type = match.slots['type'] as String?;
    if (type == 'pdf' && _documentIndexStore != null) {
      final rows = await _documentIndexStore.search(query);
      if (rows.isNotEmpty) {
        return IntentResult(
          type: IntentType.findFile,
          success: true,
          response: 'Document found: ${rows.first['name']}',
          data: {'results': rows},
        );
      }
    }
    final results = await AndroidBridge.searchFiles(query: query, type: type);
    if (results.isEmpty) {
      return const IntentResult(
        type: IntentType.findFile,
        success: false,
        response: 'File not found.',
      );
    }
    return IntentResult(
      type: IntentType.findFile,
      success: true,
      response: 'One file found: ${results.first['name']}',
      data: {'results': results},
    );
  }

  Future<IntentResult> _shareToTelegram(IntentMatch match) async {
    final file = match.slots['fileUri'] as String?;
    if (file == null) {
      return const IntentResult(
        type: IntentType.shareFileToTelegram,
        success: false,
        response: 'File to share not found.',
      );
    }
    await AndroidBridge.shareToTelegram(file);
    return const IntentResult(
      type: IntentType.shareFileToTelegram,
      success: true,
      response: 'Opened Telegram share dialog.',
    );
  }

  Future<IntentResult> _openApp(IntentMatch match) async {
    final alias = match.slots['appAlias'] as String?;
    if (alias == null || alias.isEmpty) {
      return const IntentResult(
        type: IntentType.openApp,
        success: false,
        response: 'App name required.',
      );
    }
    await AndroidBridge.openApp(alias);
    return IntentResult(
      type: IntentType.openApp,
      success: true,
      response: 'Opening $alias.',
    );
  }
}
