import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class AlertSoundService {
  AlertSoundService._();

  static final instance = AlertSoundService._();

  static const _nativeChannel = MethodChannel('horse_club/audio');

  final AudioPlayer _player = AudioPlayer();
  bool _configured = false;

  Future<void> _configure() async {
    if (_configured) return;
    await _player.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          stayAwake: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.alarm,
          audioFocus: AndroidAudioFocus.gain,
        ),
      ),
    );
    await _player.setVolume(1);
    _configured = true;
  }

  Future<bool> play({bool loop = false}) async {
    try {
      final nativePlayed = await _nativeChannel.invokeMethod<bool>(
        'playAlert',
        {'loop': loop},
      );
      if (nativePlayed == true) return true;
    } on MissingPluginException {
      // يُستخدم مشغل Flutter كحل احتياطي على المنصات غير أندرويد.
    } on PlatformException {
      // فشل المشغل الأصلي؛ نتابع تلقائياً إلى الحل الاحتياطي أدناه.
    }
    try {
      await _configure();
      await _player.stop();
      await _player.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
      await _player.play(AssetSource('sounds/alert.mp3'), volume: 1);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _nativeChannel.invokeMethod<bool>('stopAlert');
    } on MissingPluginException {
      // لا توجد قناة أندرويد على المنصات الأخرى.
    } on PlatformException {
      // يستمر إيقاف المشغل الاحتياطي حتى إذا لم تستجب القناة الأصلية.
    }
    try {
      await _player.stop();
    } catch (_) {
      // لا يعطل التنبيه إذا أغلق نظام الصوت المشغل بالفعل.
    }
  }
}
