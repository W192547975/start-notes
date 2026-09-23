import 'dart:convert';
import 'dart:io';

import '../channels/native.dart';
import '../data/store.dart';

/// 课表：一门课 = 名称 + 多选星期 + 起止分钟 + 教室 + 周次范围。
/// 数据与老版 start_courses.json / start_timetable(term_start) 完全兼容。
class Course {
  int id;
  String name;
  String place;
  String teacher;
  int weekday; // 1=周一…7=周日（单日，向后兼容）
  Set<int> weekdays; // 多选星期
  int startMin; // 从 0 点起的分钟数
  int endMin;
  int weekStart; // 0 表示每周都上
  int weekEnd;

  Course({
    this.id = 0,
    this.name = '',
    this.place = '',
    this.teacher = '',
    this.weekday = 1,
    Set<int>? weekdays,
    this.startMin = 0,
    this.endMin = 0,
    this.weekStart = 0,
    this.weekEnd = 0,
  }) : weekdays = weekdays ?? {};

  bool hasDay(int day) => weekdays.isNotEmpty ? weekdays.contains(day) : weekday == day;

  bool hitWeek(int week) {
    if (week <= 0) return true;
    if (weekStart <= 0 && weekEnd <= 0) return true;
    if (weekStart > 0 && week < weekStart) return false;
    if (weekEnd > 0 && week > weekEnd) return false;
    return true;
  }

  factory Course.fromJson(Map<String, dynamic> j) => Course(
        id: _i(j['id']),
        name: j['name'] as String? ?? '',
        place: j['place'] as String? ?? '',
        teacher: j['teacher'] as String? ?? '',
        weekday: _i(j['weekday'], _i(j['day'], 1)),
        weekdays: (j['weekdays'] as List<dynamic>? ?? []).map((e) => _i(e)).toSet(),
        startMin: _i(j['startMin'], _i(j['start'], 0)),
        endMin: _i(j['endMin'], _i(j['end'], 0)),
        weekStart: _i(j['weekStart']),
        weekEnd: _i(j['weekEnd']),
      );

  static int _i(Object? v, [int d = 0]) => v is int ? v : (int.tryParse('${v ?? ''}') ?? d);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'place': place,
        'teacher': teacher,
        'weekday': weekday,
        if (weekdays.isNotEmpty) 'weekdays': weekdays.toList(),
        'startMin': startMin,
        'endMin': endMin,
        'weekStart': weekStart,
        'weekEnd': weekEnd,
      };
}

class Timetable {
  static const prefsName = 'start_timetable';
  static const fileJson = 'start_courses.json';
  static const _term = 'term_start';

  final List<Course> courses = [];
  String _dir = '';

  static final Timetable I = Timetable._();
  Timetable._();

  Future<void> init(String dir) async {
    _dir = dir;
    try {
      final f = await _file();
      if (await f.exists()) {
        final root = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        final arr = root['courses'] as List<dynamic>? ?? [];
        courses
          ..clear()
          ..addAll(arr.whereType<Map<String, dynamic>>().map(Course.fromJson));
      }
    } catch (_) {}
  }

  Future<File> _file() async => File('$_dir/$fileJson');

  Future<void> persist() async {
    try {
      final f = await _file();
      await f.writeAsString(jsonEncode({'courses': courses.map((c) => c.toJson()).toList()}),
          flush: true);
    } catch (_) {}
  }

  int termStartEpochDay() => StartStore.I.prefInt(_term, 0);

  Future<void> setTermStartEpochDay(int day) async {
    StartStore.I.prefs[_term] = day;
    await Prefs.set(_term, day, prefsName);
  }

  /// 当前是第几周，未设开学日期返回 0。
  int currentWeek() {
    final t = termStartEpochDay();
    if (t <= 0) return 0;
    final today = StartStore.epochDay();
    if (today < t) return 0;
    return ((today - t) ~/ 7) + 1;
  }

  List<Course> coursesOn(int weekday, int week) {
    final r = courses.where((c) => c.hasDay(weekday) && c.hitWeek(week)).toList()
      ..sort((a, b) => a.startMin.compareTo(b.startMin));
    return r;
  }

  Future<void> add(Course c) async {
    c.id = (courses.isEmpty ? 0 : courses.map((e) => e.id).reduce((a, b) => a > b ? a : b)) + 1;
    courses.add(c);
    await persist();
  }

  Future<void> remove(int id) async {
    courses.removeWhere((c) => c.id == id);
    await persist();
  }

  Future<void> replaceAll(List<Course> list) async {
    courses
      ..clear()
      ..addAll(list);
    await persist();
  }

  // ---------------- 文本导入（与老版格式一致） ----------------

  static final _clock = RegExp(r'(\d{1,2})[:：点](\d{2})?\s*[-–—~至到]\s*(\d{1,2})[:：点](\d{2})?');
  static final _weekRange = RegExp(r'第?\s*(\d{1,2})\s*[-–—~]\s*(\d{1,2})\s*周');

  static int _toMin(String h, String? m) =>
      int.parse(h) * 60 + (m == null || m.isEmpty ? 0 : int.parse(m));

  /// 解析导入文本：支持 JSON {courses:[...]} 或每行一段描述。
  static List<Course> parseText(String text) {
    final out = <Course>[];
    final trimmed = text.trim();
    if (trimmed.startsWith('{')) {
      try {
        final arr = (jsonDecode(trimmed) as Map<String, dynamic>)['courses'] as List<dynamic>?;
        if (arr != null) {
          for (final e in arr) {
            if (e is Map<String, dynamic>) out.add(Course.fromJson(e));
          }
          return out;
        }
      } catch (_) {}
    }
    for (final raw in text.split(RegExp(r'\r?\n'))) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final wd = _parseWeekday(line);
      if (wd <= 0) continue;

      var start = -1, end = -1;
      final cm = _clock.firstMatch(line);
      if (cm != null) {
        start = _toMin(cm.group(1)!, cm.group(2));
        end = _toMin(cm.group(3)!, cm.group(4));
      }
      if (start < 0 || end <= start) continue;

      final ws = _weekRange.firstMatch(line);
      final c = Course(
        weekday: wd,
        startMin: start,
        endMin: end,
        weekStart: ws == null ? 0 : int.parse(ws.group(1)!),
        weekEnd: ws == null ? 0 : int.parse(ws.group(2)!),
      );
      // 名称：去掉时间段/星期/周次后的剩余文本
      var name = line
          .replaceAll(_clock, ' ')
          .replaceAll(_weekRange, ' ')
          .replaceAll(RegExp(r'(周|星期|礼拜)\s*[一二三四五六日天1-7]'), ' ');
      // 教室/教师 heuristic：老版用空格分段，首段为名称，其余合并为地点
      final parts = name.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
      c.name = parts.isNotEmpty ? parts.first : '课程';
      c.place = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      out.add(c);
    }
    return out;
  }

  static int _parseWeekday(String line) {
    if (line.contains('周日') ||
        line.contains('周天') ||
        line.contains('星期日') ||
        line.contains('星期天') ||
        line.contains('礼拜日') ||
        line.contains('礼拜天')) {
      return 7;
    }
    const keys = ['一', '二', '三', '四', '五', '六'];
    for (var i = 0; i < keys.length; i++) {
      if (line.contains('周${keys[i]}') ||
          line.contains('星期${keys[i]}') ||
          line.contains('礼拜${keys[i]}')) {
        return i + 1;
      }
    }
    final m = RegExp(r'(?:周|星期|礼拜)\s*([1-7])').firstMatch(line);
    if (m != null) return int.parse(m.group(1)!);
    return -1;
  }
}
