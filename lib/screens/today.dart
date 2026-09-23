import 'package:flutter/material.dart';

import '../data/item.dart';
import '../data/store.dart';
import '../theme/tokens.dart';
import '../widgets/editor.dart';
import '../widgets/ui.dart';
import 'settings.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  bool _selecting = false;
  final Set<int> _selected = {};

  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    final s = StartStore.I;
    final focus = s.todayFocus();
    final open = s.openTasks();
    final anytime = s.anytimeTasks();

    return SafeArea(
      child: Column(
        children: [
          _Header(selecting: _selecting),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(S.md, 0, S.md, S.md),
              children: [
                HeroCard(focus: focus),
                if (open.isNotEmpty) ...[
                  const _SectionLabel('已排期'),
                  ...open.map(_buildTask),
                ],
                const _SectionLabel('随手做'),
                if (anytime.isEmpty)
                  StartCard(
                    child: SizedBox(
                      height: 72,
                      child: Center(
                        child: Pressable(
                          onTap: () => showQuickAdd(context),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, color: c.accent),
                              const SizedBox(width: S.xxs),
                              Text('记一件',
                                  style: TextStyle(
                                      color: c.accent, fontSize: S.textMd, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: true,
                    proxyDecorator: _lift,
                    itemCount: anytime.length,
                    onReorder: (oldIndex, newIndex) async {
                      final ids = anytime.map((e) => e.id).toList();
                      if (newIndex > oldIndex) newIndex--;
                      ids.insert(newIndex, ids.removeAt(oldIndex));
                      await s.reorder(ids);
                    },
                    itemBuilder: (_, i) {
                      final it = anytime[i];
                      return Container(
                        key: ValueKey(it.id),
                        child: _buildTask(it),
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

  Widget _lift(Widget child, int index, Animation<double> a) => ScaleTransition(scale: a, child: child);

  Widget _buildTask(Item it) {
    final c = ThemeTokens.of(context);
    final s = StartStore.I;
    final progress = s.subtaskProgress(it.id);
    final hasSub = progress[1] > 0;
    final selected = _selected.contains(it.id);

    final card = Pressable(
      onTap: _selecting
          ? () => setState(() => selected ? _selected.remove(it.id) : _selected.add(it.id))
          : () => showItemEditor(context, it, onDeleted: () => setState(() {})),
      onLongPress: _selecting
          ? null
          : () => setState(() {
                _selecting = true;
                _selected.add(it.id);
              }),
      child: StartCard(
        color: selected ? c.accentSoft : null,
        padding: const EdgeInsets.symmetric(horizontal: S.md, vertical: S.sm),
        child: Row(
          children: [
            if (_selecting)
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? c.accent : c.inkSoft,
                size: 22,
              )
            else
              CheckDot(done: it.done, onTap: () async {
                it.done = !it.done;
                await s.put(it);
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
            if (it.dueTime > 0 && !_selecting)
              Text(
                _fmtDue(it.dueTime),
                style: TextStyle(fontSize: S.textSm, color: c.inkSoft),
              ),
            if (s.todayFocus()?.id == it.id)
              Padding(
                padding: const EdgeInsets.only(left: S.xs),
                child: Icon(Icons.star, size: 18, color: c.accent),
              ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: S.xs),
      child: card,
    );
  }

  static String _fmtDue(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final hm = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final day = DateTime(d.year, d.month, d.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return hm;
    if (diff == 1) return '明天 $hm';
    return '${d.month}/${d.day}';
  }
}

class _Header extends StatelessWidget {
  final bool selecting;
  const _Header({required this.selecting});

  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    final now = DateTime.now();
    final label = '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(S.md, S.sm, S.md, S.sm),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: S.textXl, fontWeight: FontWeight.bold, color: c.ink)),
          const Spacer(),
          IconBtn(Icons.settings_outlined, tip: '设置', onTap: () {
            Navigator.of(context, rootNavigator: true)
                .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
          }),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(S.xxs, S.md, 0, S.xs),
      child: Text(text,
          style: TextStyle(fontSize: S.textSm, color: c.inkSoft, fontWeight: FontWeight.bold)),
    );
  }
}

/// 今日焦点卡。
class HeroCard extends StatelessWidget {
  final Item? focus;
  const HeroCard({super.key, this.focus});

  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    final s = StartStore.I;
    final it = focus;
    final progress = it == null ? [0, 0] : s.subtaskProgress(it.id);
    return StartCard(
      padding: const EdgeInsets.all(S.lg),
      child: it == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('今天先把一件事做完',
                    style: TextStyle(fontSize: S.textLg, fontWeight: FontWeight.bold, color: c.ink)),
                const SizedBox(height: S.xs),
                Text('随手做里长按一件，设为今日焦点',
                    style: TextStyle(fontSize: S.textSm, color: c.inkSoft)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.star, size: 16, color: c.accent),
                    const SizedBox(width: S.xxs),
                    Text('今日焦点',
                        style: TextStyle(
                            fontSize: S.textSm, color: c.accent, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: S.xs),
                Text(it.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: S.textXl, fontWeight: FontWeight.bold, color: c.ink)),
                if (progress[1] > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: S.xs),
                    child: Text('小步骤 ${progress[0]}/${progress[1]}',
                        style: TextStyle(fontSize: S.textSm, color: c.inkSoft)),
                  ),
                const SizedBox(height: S.md),
                Pressable(
                  onTap: () => Navigator.of(context, rootNavigator: true)
                      .pushNamed('/focus', arguments: it.id),
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: c.accent, borderRadius: BorderRadius.circular(S.radius)),
                    child: const Text('开始专注',
                        style: TextStyle(
                            color: Colors.white, fontSize: S.textMd, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
    );
  }
}
