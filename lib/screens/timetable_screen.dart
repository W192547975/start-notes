import 'package:flutter/material.dart';

import '../data/store.dart';
import '../data/timetable.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';

/// 课表：本周视图 + 文本导入 + 开学日期。
class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    final tt = Timetable.I;
    final week = tt.currentWeek();
    final weekday = DateTime.now().weekday; // 1=周一
    final todayCourses = tt.coursesOn(weekday, week);

    return Scaffold(
      backgroundColor: c.paper,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(S.md),
          children: [
            Row(
              children: [
                IconBtn(Icons.arrow_back, onTap: () => Navigator.pop(context)),
                const Spacer(),
                Icon(Icons.calendar_today_outlined, color: c.inkSoft),
              ],
            ),
            const SizedBox(height: S.sm),
            Row(
              children: [
                Text(week > 0 ? '第 $week 周' : '还没设开学日',
                    style: TextStyle(
                        fontSize: S.textXl, fontWeight: FontWeight.bold, color: c.ink)),
                const Spacer(),
                Pressable(
                  onTap: () => _pickTermStart(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: S.sm, vertical: S.xxs),
                    decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: c.line),
                    ),
                    child: Text('开学日',
                        style: TextStyle(fontSize: S.textSm, color: c.ink)),
                  ),
                ),
                const SizedBox(width: S.xs),
                Pressable(
                  onTap: () => _importText(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: S.sm, vertical: S.xxs),
                    decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: c.line),
                    ),
                    child: Text('导入',
                        style: TextStyle(fontSize: S.textSm, color: c.ink)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: S.md),
            Text('今天',
                style: TextStyle(fontSize: S.textSm, color: c.inkSoft, fontWeight: FontWeight.bold)),
            const SizedBox(height: S.xs),
            if (todayCourses.isEmpty)
              StartCard(
                child: SizedBox(
                  height: 56,
                  child: Center(
                    child: Text('今天没课',
                        style: TextStyle(fontSize: S.textMd, color: c.inkSoft)),
                  ),
                ),
              )
            else
              ...todayCourses.map((co) => Padding(
                    padding: const EdgeInsets.only(bottom: S.xs),
                    child: StartCard(
                      padding:
                          const EdgeInsets.symmetric(horizontal: S.md, vertical: S.sm),
                      child: Row(
                        children: [
                          Text(_hm(co.startMin),
                              style: TextStyle(
                                  fontSize: S.textMd,
                                  fontWeight: FontWeight.bold,
                                  color: c.accent)),
                          const SizedBox(width: S.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(co.name,
                                    style: TextStyle(
                                        fontSize: S.textMd,
                                        fontWeight: FontWeight.bold,
                                        color: c.ink)),
                                if (co.place.isNotEmpty)
                                  Text(co.place,
                                      style:
                                          TextStyle(fontSize: S.textSm, color: c.inkSoft)),
                              ],
                            ),
                          ),
                          Text(_hm(co.endMin),
                              style: TextStyle(fontSize: S.textSm, color: c.inkSoft)),
                        ],
                      ),
                    ),
                  )),
            const SizedBox(height: S.md),
            for (var d = 1; d <= 7; d++) ..._daySection(tt, week, d, today: d == weekday),
          ],
        ),
      ),
    );
  }

  List<Widget> _daySection(Timetable tt, int week, int d, {required bool today}) {
    final c = ThemeTokens.of(context);
    final list = tt.coursesOn(d, week);
    if (list.isEmpty) return [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(S.xxs, S.xs, 0, S.xs),
        child: Text('周${'一二三四五六日'[d - 1]}',
            style: TextStyle(
                fontSize: S.textSm,
                color: today ? c.accent : c.inkSoft,
                fontWeight: FontWeight.bold)),
      ),
      ...list.map((co) => Padding(
            padding: const EdgeInsets.only(bottom: S.xxs, left: S.sm),
            child: Text('${_hm(co.startMin)}–${_hm(co.endMin)}  ${co.name}${co.place.isEmpty ? '' : '  ${co.place}'}',
                style: TextStyle(fontSize: S.textSm, color: c.ink)),
          )),
    ];
  }

  static String _hm(int min) =>
      '${(min ~/ 60).toString().padLeft(2, '0')}:${(min % 60).toString().padLeft(2, '0')}';

  Future<void> _pickTermStart(BuildContext context) async {
    final tt = Timetable.I;
    final cur = tt.termStartEpochDay();
    final d = await showDatePicker(
      context: context,
      initialDate: cur > 0
          ? DateTime(1970, 1, 1).add(Duration(days: cur))
          : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (d == null) return;
    await tt.setTermStartEpochDay(StartStore.epochDay(d));
    if (context.mounted) setState(() {});
  }

  Future<void> _importText(BuildContext context) async {
    final ctl = TextEditingController();
    final ok = await showStartDialog<bool>(
      context,
      title: '粘贴课表文本',
      content: '每行一门课，例如：\n周一 8:00-9:40 高数 教一101',
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text('算了')),
        TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('导入', style: TextStyle(color: ThemeTokens.of(context).accent))),
      ],
    );
    if (ok != true || !context.mounted) return;
    final list = Timetable.parseText(ctl.text);
    if (list.isEmpty) {
      if (context.mounted) UndoHost.show(context, '没解析出课程', () {});
      return;
    }
    await Timetable.I.replaceAll(list);
    if (context.mounted) {
      setState(() {});
      UndoHost.show(context, '导入了 ${list.length} 门课', () {});
    }
  }
}
