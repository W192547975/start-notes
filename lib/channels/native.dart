import 'package:flutter/services.dart';

/// 原生偏好读写：直接操作同名 SharedPreferences，保证与老版数据兼容。
/// 注意：不能用 shared_preferences 插件（它会给键加 "flutter." 前缀）。
class Prefs {
  static const _ch = MethodChannel('start/prefs');

  static Future<Map<String, Object?>> getAll([String name = 'start_prefs']) async {
    final r = await _ch.invokeMethod<dynamic>('getAll', {'name': name});
    return (r as Map<Object?, Object?>? ?? {}).cast<String, Object?>();
  }

  static Future<void> set(String key, Object? value, [String name = 'start_prefs']) =>
      _ch.invokeMethod('set', {'name': name, 'key': key, 'value': value});
}

/// 系统能力：路径 / 震动 / 屏幕常亮 / 分享接收 / 分词 / 音效。
class Native {
  static const _sys = MethodChannel('start/system');
  static const _seg = MethodChannel('start/segment');
  static const _snd = MethodChannel('start/sound');

  static Future<String> filesDir() async =>
      (await _sys.invokeMethod<String>('filesDir')) ?? '';

  static Future<void> vibrate([int ms = 20]) => _sys.invokeMethod('vibrate', {'ms': ms});

  static Future<void> keepScreenOn(bool on) => _sys.invokeMethod('keepScreenOn', {'on': on});

  static Future<String?> initialShare() => _sys.invokeMethod<String>('initialShare');

  /// 词级分词（ICU 词典，BreakIterator Locale.CHINA），返回去掉首尾标点的词列表。
  static Future<List<String>> words(String text) async {
    final r = await _seg.invokeMethod<List<Object?>>('words', {'text': text});
    return (r ?? []).map((e) => e.toString()).toList();
  }

  static Future<void> tick(int volume) => _snd.invokeMethod('tick', {'volume': volume});

  static Future<void> chime() => _snd.invokeMethod('chime');

  static Future<void> stopChime() => _snd.invokeMethod('stopChime');
}
