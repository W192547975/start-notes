import 'dart:async';

import 'package:flutter/material.dart';

import '../channels/native.dart';
import '../data/item.dart';
import '../data/store.dart';
import '../main.dart';
import '../theme/tokens.dart';
import '../widgets/editor.dart';
import '../widgets/ui.dart';
import 'search.dart';
import 'settings.dart';

/// 首页 = 今日（复刻老版 TodayScreen）。
/// 顶栏：Start 字标 + 搜索 + 设置。
/// 今日头条：大时钟（等宽数字）+ 日期 + 剩余计数 + 今日专注分钟。
/// 焦点 hero：占首屏，时间轴在首屏外滚动才出现。
/// 日程时间线：已排期任务按时间升序，左侧时间标签，过期任务显日期（不责备，不变红）。
/// 随手做：无时间任务，可拖动排序，选择态有 selectBar（计数/全选/完成/删除）。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _selecting = false;
  final Set<int> _selected = {};
  Timer? _clock;
  String _hhmm = '';
  String _dateLabel = '';
  int _nowMs = 0;
  List<Map<String, Object?>> _events = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tickClock();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) => _tickClock());
    _loadCalendar();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadCalendar();
  }

  Future<void> _loadCalendar() async {
    final ev = await Native.calendarToday();
    if (mounted) setState(() => _events = ev);
  }

  void _tickClock() {
    if (!mounted) return;
    final now = DateTime.now();
    setState(() {
      _hhmm = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      _dateLabel = _fullDate(now);
      _nowMs = now.millisecondsSinceEpoch;
    });
  }

  static String _fullDate(DateTime n) {
    const wk = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    return '${n.month}月${n.day}日 ${wk[n.weekday - 1]}';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    super.dispose();
  }

  /// 弹出快速记一件 sheet。优先用全局 navigator 上下文，确保在 IndexedStack 内也能弹出。
  void _quickAdd() {
    final ctx = StartApp.navigatorKey.currentContext ?? context;
    showQuickAdd(ctx);
  }

  /// 「选一件事」面板：今日未完成任务里挑一件设为焦点（ADHD：一次只做一件，降低决策负荷）。
  Future<void> _pickFocus() async {
    final s = StartStore.I;
    final list = s.openTasks().where((e) => !e.done).toList();
    if (list.isEmpty) {
      _quickAdd();
      return;
    }
    await showStartSheet(context, (ctx) {
      final c = ThemeTokens.of(ctx);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(S.md, S.md, S.md, S.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('今天只盯一件事',
                  style: TextStyle(
                      fontSize: S.textLg, fontWeight: FontWeight.bold, color: c.ink)),
              const SizedBox(height: S.xxs),
              Text('选一个，其他的先放一放',
                  style: TextStyle(fontSize: S.textSm, color: c.inkSoft)),
              const SizedBox(height: S.sm),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final it = list[i];
                    final timed = it.dueTime > 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: S.xs),
                      child: Pressable(
                        onTap: () async {
                          await s.setFocus(it.id);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: StartCard(
                          color: s.todayFocus()?.id == it.id ? c.accentSoft : null,
                          padding: const EdgeInsets.symmetric(
                              horizontal: S.md, vertical: S.sm),
                          child: Row(
                            children: [
                              Icon(
                                timed ? Icons.schedule_outlined : Icons.checklist_outlined,
                                size: 16,
                                color: c.inkSoft,
                              ),
                              const SizedBox(width: S.sm),
                              Expanded(
                                child: Text(
                                  it.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: S.textMd,
                                      fontWeight: FontWeight.bold,
                                      color: c.ink),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  /// 合并日程任务与手机日历事件，按 begin 升序。被任务 eventId 消费的事件跳过。
  List<Map<String, Object?>> _timelineEntries(List<Item> schedule) {
    final consumed = schedule.map((e) => e.eventId).where((e) => e > 0).toSet();
    final entries = <Map<String, Object?>>[];
    for (final it in schedule) {
      entries.add({'kind': 'task', 'item': it, 'time': it.dueTime});
    }
    for (final ev in _events) {
      final id = (ev['id'] as num?)?.toInt() ?? 0;
      if (consumed.contains(id)) continue;
      entries.add({'kind': 'event', 'event': ev, 'time': ev['begin'] as int? ?? 0});
    }
    entries.sort((a, b) => (a['time'] as int).compareTo(b['time'] as int));
    return entries;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: StartStore.I,
        builder: (context, _) => _build(context),
      );

  Widget _build(BuildContext context) {
    final c = ThemeTokens.of(context);
    final s = StartStore.I;
    final focus = s.todayFocus();
    final schedule = s.openTasks().where((it) => it.dueTime > 0).toList()
      ..sort((a, b) => a.dueTime.compareTo(b.dueTime));
    final anytime = s.anytimeTasks();
    final list = [...schedule, ...anytime];
    final remaining = list.length;
    final focusMin = s.todayFocusMinutes();
    final viewH = MediaQuery.sizeOf(context).height;

    return SafeArea(
      child: Column(
        children: [
          if (_selecting) _selectBar(c, list) else const _TopBar(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(S.md, 0, S.md, S.xl + 16),
              children: [
                _TodayHead(
                  hhmm: _hhmm,
                  date: _dateLabel,
                  remaining: remaining,
                  focusMin: focusMin,
                ),
                // 焦点 hero 占首屏：时间轴在首屏外滚动才出现。
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (viewH - 220).clamp(260.0, viewH),
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.only(bottom: S.md),
                    child: focus != null
                        ? HeroCard(focus: focus, onPick: _pickFocus)
                        : _FocusEmpty(onPick: _pickFocus, onAdd: _quickAdd),
                  ),
                ),
                if (schedule.isNotEmpty || _events.isNotEmpty) ...[
                  const _SectionLabel('日程'),
                  _TimelineColumn(
                    entries: _timelineEntries(schedule),
                    nowMs: _nowMs,
                    selecting: _selecting,
                    selected: _selected,
                    onChange: () => setState(() {}),
                    onEnterSelect: () => setState(() => _selecting = true),
                  ),
                ],
                _SectionLabel(
                  '随手做',
                  trailing: Pressable(
                    onTap: _quickAdd,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: S.xs, vertical: S.xxs),
                      child: Icon(Icons.add, size: 20, color: c.accent),
                    ),
                  ),
                ),
                if (anytime.isEmpty)
                  _EmptyAdd(onTap: _quickAdd)
                else
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: true,
                    proxyDecorator: (child, i, a) => ScaleTransition(scale: a, child: child),
                    itemCount: anytime.length,
                    onReorder: (o, n) async {
                      final ids = anytime.map((e) => e.id).toList();
                      if (n > o) n--;
                      ids.insert(n, ids.removeAt(o));
                      await s.reorder(ids);
                    },
                    itemBuilder: (_, i) {
                      final it = anytime[i];
                      return Container(
                        key: ValueKey(it.id),
                        child: _TaskCard(
                          it: it,
                          selecting: _selecting,
                          selected: _selected,
                          onChange: () => setState(() {}),
                          onEnterSelect: () => setState(() {
                            _selecting = true;
                            _selected.add(it.id);
                          }),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 选择态顶栏：关闭 + 计数 + 全选 + 完成 + 删除（老版 buildAnytimeSelectBar）。
  Widget _selectBar(C c, List<Item> list) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(S.md, S.sm, S.md, S.sm),
      child: Row(
        children: [
          IconBtn(Icons.close, tip: '退出选择', onTap: () {
            setState(() {
              _selecting = false;
              _selected.clear();
            });
          }),
          const SizedBox(width: S.sm),
          Text('已选 ${_selected.length}',
              style: TextStyle(
                  fontSize: S.textMd,
                  fontWeight: FontWeight.bold,
                  color: c.ink,
                  fontFeatures: const [FontFeature.tabularFigures()])),
          const Spacer(),
          IconBtn(Icons.select_all_outlined, tip: '全选', onTap: () {
            setState(() {
              _selected.length == list.length
                  ? _selected.clear()
                  : _selected.addAll(list.map((e) => e.id));
            });
          }),
          IconBtn(Icons.check_circle_outline, tip: '完成', onTap: _batchComplete),
          IconBtn(Icons.delete_outline, tip: '删除', onTap: _batchDelete),
        ],
      ),
    );
  }

  Future<void> _batchComplete() async {
    if (_selected.isEmpty) return;
    final s = StartStore.I;
    final snap = await s.deleteAll(_selected.toList(), complete: true);
    setState(() {
      _selecting = false;
      _selected.clear();
    });
    if (!mounted) return;
    UndoHost.show(context, '完成了', () async => s.restoreJson(snap));
  }

  Future<void> _batchDelete() async {
    if (_selected.isEmpty) return;
    final s = StartStore.I;
    final snap = await s.deleteAll(_selected.toList());
    setState(() {
      _selecting = false;
      _selected.clear();
    });
    if (!mounted) return;
    UndoHost.show(context, '已删除', () async => s.restoreJson(snap));
  }
}

/// 顶栏：Start 字标 + 搜索 + 设置。
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(S.md, S.sm, S.md, S.sm),
      child: Row(
        children: [
          Text('Start',
              style: TextStyle(
                  fontSize: S.textLg, fontWeight: FontWeight.bold, color: c.ink)),
          const Spacer(),
          IconBtn(Icons.search_outlined, tip: '搜索', onTap: () {
            Navigator.of(context, rootNavigator: true)
                .push(MaterialPageRoute(builder: (_) => const SearchScreen()));
          }),
          IconBtn(Icons.settings_outlined, tip: '设置', onTap: () {
            Navigator.of(context, rootNavigator: true)
                .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
          }),
        ],
      ),
    );
  }
}

/// 今日头条：左列大时钟（等宽）+ 日期；右列剩余计数 + 今日专注分钟（点击进专注）。
class _TodayHead extends StatelessWidget {
  final String hhmm;
  final String date;
  final int remaining;
  final int focusMin;
  const _TodayHead({
    required this.hhmm,
    required this.date,
    required this.remaining,
    required this.focusMin,
  });

  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(S.md, S.xs, S.md, S.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(hhmm,
                  style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    color: c.ink,
                    fontFamily: 'monospace',
                    fontFeatures: const [FontFeature.tabularFigures()],
                    height: 1.0,
                    letterSpacing: -1,
                  )),
              const SizedBox(height: S.xxs),
              Text(date, style: TextStyle(fontSize: S.textSm, color: c.inkSoft)),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$remaining',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: c.accent,
                      height: 1.0,
                      fontFeatures: const [FontFeature.tabularFigures()])),
              const SizedBox(height: S.xxs),
              Text('件未完成',
                  style: TextStyle(fontSize: 11, color: c.inkSoft)),
              const SizedBox(height: S.xs),
              Pressable(
                onTap: () => Navigator.of(context, rootNavigator: true).pushNamed('/focus'),
                child: Text(
                  focusMin > 0 ? '专注 $focusMin 分' : '去专注',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: c.inkSoft,
                      fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const _SectionLabel(this.text, {this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(S.xxs, S.md, 0, S.xs),
      child: Row(
        children: [
          Text(text,
              style: TextStyle(
                  fontSize: S.textSm, color: c.inkSoft, fontWeight: FontWeight.bold)),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 日程时间线：左侧时间标签（番茄红，固定宽），右侧任务卡/事件卡，行间竖线连接成轴。
/// 过期任务（未完成且时间已过）显日期+时刻两行，不责备、不变红。
class _TimelineColumn extends StatelessWidget {
  final List<Map<String, Object?>> entries;
  final int nowMs;
  final bool selecting;
  final Set<int> selected;
  final VoidCallback onChange;
  final VoidCallback onEnterSelect;
  const _TimelineColumn({
    required this.entries,
    required this.nowMs,
    required this.selecting,
    required this.selected,
    required this.onChange,
    required this.onEnterSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          _entryRow(entries[i]),
          if (i < entries.length - 1) const SizedBox(height: S.xs),
        ],
      ],
    );
  }

  Widget _entryRow(Map<String, Object?> e) {
    if (e['kind'] == 'event') {
      final ev = e['event'] as Map<String, Object?>;
      final begin = (ev['begin'] as num?)?.toInt() ?? 0;
      return _EventRow(event: ev, overdue: begin > 0 && begin < nowMs);
    }
    final it = e['item'] as Item;
    return _TimelineRow(
      it: it,
      overdue: !it.done && it.dueTime > 0 && it.dueTime < nowMs,
      selecting: selecting,
      selected: selected,
      onChange: onChange,
      onEnterSelect: onEnterSelect,
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final Item it;
  final bool overdue;
  final bool selecting;
  final Set<int> selected;
  final VoidCallback onChange;
  final VoidCallback onEnterSelect;
  const _TimelineRow({
    required this.it,
    required this.overdue,
    required this.selecting,
    required this.selected,
    required this.onChange,
    required this.onEnterSelect,
  });

  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    final sel = selected.contains(it.id);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 时间标签 + 竖线
          SizedBox(
            width: 54,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (overdue)
                  Text(
                    _mmdd(it.dueTime),
                    style: TextStyle(
                      fontSize: 11,
                      color: c.inkSoft,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                Text(
                  _hm(it.dueTime),
                  style: TextStyle(
                    fontSize: overdue ? 11 : S.textSm,
                    fontWeight: FontWeight.bold,
                    color: overdue ? c.inkSoft : c.accent,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: Container(
                    width: 1.5,
                    color: c.line,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: S.sm),
          Expanded(
            child: _TaskCard(
              it: it,
              selecting: selecting,
              selected: selected,
              onChange: onChange,
              onEnterSelect: onEnterSelect,
            ),
          ),
        ],
      ),
    );
  }

  static String _hm(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  static String _mmdd(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.month}/${d.day}';
  }
}

/// 手机日历事件行：无勾选圈，标题 + 来源「手机日历」，点按打开系统日历。
class _EventRow extends StatelessWidget {
  final Map<String, Object?> event;
  final bool overdue;
  const _EventRow({required this.event, required this.overdue});

  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    final begin = (event['begin'] as num?)?.toInt() ?? 0;
    final title = (event['title'] as String?) ?? '';
    final calName = (event['calName'] as String?) ?? '';
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 54,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (overdue)
                  Text(_mmdd(begin),
                      style: TextStyle(
                          fontSize: 11,
                          color: c.inkSoft,
                          fontFeatures: const [FontFeature.tabularFigures()])),
                Text(_hm(begin),
                    style: TextStyle(
                        fontSize: overdue ? 11 : S.textSm,
                        fontWeight: FontWeight.bold,
                        color: overdue ? c.inkSoft : c.accent,
                        fontFeatures: const [FontFeature.tabularFigures()])),
                const SizedBox(height: 2),
                Expanded(child: Container(width: 1.5, color: c.line)),
              ],
            ),
          ),
          const SizedBox(width: S.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: S.xs),
              child: Pressable(
                onTap: () => Native.openUrl('content://com.android.calendar/time/$begin'),
                child: StartCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: S.md, vertical: S.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: S.textMd,
                              fontWeight: FontWeight.bold,
                              color: c.ink)),
                      const SizedBox(height: S.xxs),
                      Row(
                        children: [
                          Icon(Icons.event_outlined, size: 13, color: c.inkSoft),
                          const SizedBox(width: S.xxs),
                          Text('手机日历${calName.isEmpty ? '' : ' · $calName'}',
                              style: TextStyle(
                                  fontSize: S.textSm, color: c.inkSoft)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _hm(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  static String _mmdd(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.month}/${d.day}';
  }
}

/// 通用任务卡：勾选、标题、子步骤进度、时间、编辑、双击删除、长按进选择态。
class _TaskCard extends StatelessWidget {
  final Item it;
  final bool selecting;
  final Set<int> selected;
  final VoidCallback onChange;
  final VoidCallback onEnterSelect;
  const _TaskCard({
    required this.it,
    required this.selecting,
    required this.selected,
    required this.onChange,
    required this.onEnterSelect,
  });

  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    final s = StartStore.I;
    final progress = s.subtaskProgress(it.id);
    final hasSub = progress[1] > 0;
    final sel = selected.contains(it.id);
    final isFocus = s.todayFocus()?.id == it.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: S.xs),
      child: Pressable(
        onTap: selecting
            ? () { selected.contains(it.id) ? selected.remove(it.id) : selected.add(it.id); onChange(); }
            : () => showItemEditor(context, it, onDeleted: onChange),
        onLongPress: selecting ? null : () { selected.add(it.id); onEnterSelect(); },
        child: StartCard(
          color: sel ? c.accentSoft : null,
          padding: const EdgeInsets.symmetric(horizontal: S.md, vertical: S.sm),
          child: Row(
            children: [
              if (selecting)
                Icon(
                  sel ? Icons.check_circle : Icons.circle_outlined,
                  color: sel ? c.accent : c.inkSoft,
                  size: 22,
                )
              else
                CheckDot(done: it.done, onTap: () async {
                  it.done = !it.done;
                  await s.put(it);
                  onChange();
                }),
              const SizedBox(width: S.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      it.title.isEmpty ? it.note.split('\n').first : it.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: S.textMd,
                        color: it.done ? c.done : c.ink,
                        decoration: it.done ? TextDecoration.lineThrough : null,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (hasSub)
                      Padding(
                        padding: const EdgeInsets.only(top: S.xxs),
                        child: Row(
                          children: [
                            Icon(Icons.call_split, size: 13, color: c.inkSoft),
                            const SizedBox(width: S.xxs),
                            Text('小步骤 ${progress[0]}/${progress[1]}',
                                style: TextStyle(fontSize: S.textSm, color: c.inkSoft)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (isFocus && !selecting)
                Padding(
                  padding: const EdgeInsets.only(left: S.xs),
                  child: Icon(Icons.star, size: 18, color: c.accent),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 今日焦点卡 = 首页操作台（ADHD 设计：一屏一事，进度可视，动作就地可及）。
/// 主按钮「只做它」进专注；完成/换一件/拆步骤/编辑就地操作；完成后给鼓励态。
class HeroCard extends StatelessWidget {
  final Item focus;
  final VoidCallback onPick;
  const HeroCard({super.key, required this.focus, required this.onPick});

  Future<void> _complete(BuildContext context) async {
    final s = StartStore.I;
    final snap = s.exportJson();
    focus.done = true;
    await s.put(focus);
    if (!context.mounted) return;
    UndoHost.show(context, '完成一件，漂亮', () async => s.restoreJson(snap));
  }

  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    final s = StartStore.I;
    final progress = s.subtaskProgress(focus.id);
    final done = focus.done;

    return Padding(
      padding: const EdgeInsets.only(bottom: S.md),
      child: StartCard(
        padding: const EdgeInsets.all(S.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(done ? Icons.verified_outlined : Icons.star,
                    size: 18, color: c.accent),
                const SizedBox(width: S.xs),
                Text(done ? '主线完成，漂亮' : '今天只盯这一件事',
                    style: TextStyle(
                        fontSize: S.textSm,
                        color: c.inkSoft,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: S.sm),
            Text(
              focus.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: S.textXl,
                  fontWeight: FontWeight.bold,
                  color: done ? c.done : c.ink,
                  decoration: done ? TextDecoration.lineThrough : null),
            ),
            if (progress[1] > 0) ...[
              const SizedBox(height: S.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress[1] == 0 ? 0 : progress[0] / progress[1],
                  minHeight: 6,
                  backgroundColor: c.cardAlt,
                  valueColor: AlwaysStoppedAnimation(c.accent),
                ),
              ),
              const SizedBox(height: S.xxs),
              Text('小步骤 ${progress[0]}/${progress[1]}',
                  style: TextStyle(
                      fontSize: S.textSm,
                      color: c.inkSoft,
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ],
            const SizedBox(height: S.md),
            if (!done) ...[
              Row(
                children: [
                  // 主钮：进专注。
                  Pressable(
                    onTap: () => Navigator.of(context, rootNavigator: true)
                        .pushNamed('/focus', arguments: focus.id),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: c.accent),
                      child: const Icon(Icons.play_arrow, size: 28, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: S.sm),
                  _HeroAct(
                      icon: Icons.check,
                      onTap: () => _complete(context)),
                  const SizedBox(width: S.xs),
                  _HeroAct(
                      icon: Icons.call_split,
                      onTap: () => Navigator.of(context, rootNavigator: true)
                          .pushNamed('/steps', arguments: focus.id)),
                  const SizedBox(width: S.xs),
                  _HeroAct(
                      icon: Icons.edit_outlined,
                      onTap: () => showItemEditor(context, focus)),
                  const Spacer(),
                  // 换一件：降低承诺压力，随时可以重新选。
                  _HeroAct(icon: Icons.swap_horiz, onTap: onPick),
                ],
              ),
            ] else
              // 完成态：给下一件事一个明确的起点。
              Center(
                child: Pressable(
                  onTap: onPick,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.cardAlt,
                        border: Border.all(color: c.line)),
                    child: Icon(Icons.arrow_forward, size: 24, color: c.ink),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 焦点卡上的圆形次操作钮。
class _HeroAct extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeroAct({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.cardAlt,
            border: Border.all(color: c.line)),
        child: Icon(icon, size: 20, color: c.ink),
      ),
    );
  }
}

class _FocusEmpty extends StatelessWidget {
  final VoidCallback onPick;
  final VoidCallback onAdd;
  const _FocusEmpty({required this.onPick, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: S.md),
      child: StartCard(
        padding: const EdgeInsets.all(S.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.star_outline, size: 18, color: c.inkSoft),
                const SizedBox(width: S.xs),
                Text('今天只盯一件事',
                    style: TextStyle(
                        fontSize: S.textSm,
                        color: c.inkSoft,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: S.sm),
            Text('选定一件，今天就不慌',
                style: TextStyle(
                    fontSize: S.textXl,
                    fontWeight: FontWeight.bold,
                    color: c.ink)),
            const SizedBox(height: S.md),
            Row(
              children: [
                // 主钮：选一件事（进选择面板）。
                Pressable(
                  onTap: onPick,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: c.accent),
                    child: const Icon(Icons.radio_button_checked,
                        size: 26, color: Colors.white),
                  ),
                ),
                const SizedBox(width: S.xs),
                // 快记一件。
                Pressable(
                  onTap: onAdd,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.cardAlt,
                        border: Border.all(color: c.line)),
                    child: Icon(Icons.add, size: 20, color: c.ink),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyAdd extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyAdd({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    return StartCard(
      child: SizedBox(
        height: 72,
        child: Center(
          child: Pressable(
            onTap: onTap,
            child: Icon(Icons.add, color: c.accent, size: 28),
          ),
        ),
      ),
    );
  }
}
