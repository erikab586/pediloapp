import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

abstract final class NotificationSound {
  static DateTime? _lastPlayedAt;
  static const _cooldown = Duration(milliseconds: 2200);
  static final FlutterTts _tts = FlutterTts();

  static void play() {
    final now = DateTime.now();
    final lastPlayedAt = _lastPlayedAt;
    if (lastPlayedAt != null && now.difference(lastPlayedAt) < _cooldown) {
      return;
    }
    _lastPlayedAt = now;
    unawaited(_playPedilo());
  }

  static Future<void> _playPedilo() async {
    try {
      await _tts.setLanguage('es-ES');
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.05);
      await _tts.setVolume(0.55);
      await _tts.speak('Pedilooo');
    } on PlatformException catch (error) {
      if (kDebugMode) {
        debugPrint('[notification] no se pudo reproducir la voz: $error');
      }
    }
  }
}
