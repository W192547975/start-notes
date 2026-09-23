import 'package:flutter/material.dart';

import '../channels/native.dart';
import '../data/item.dart';
import '../data/store.dart';
import '../theme/tokens.dart';
import 'ui.dart';

/// 任务/念头编辑弹层：标题、备注、时间、焦点、拆步骤入口、删除。
Future<void> showItemEditor(BuildContext context, Item it, {VoidCallback? onDeleted}) {
  return showStartSheet(
    context,
    (_) => _EditorSheet(item: it, onDeleted: onDeleted),
  );
}

class _EditorSheet extends StatefulWidget {
  final Item item;
  final VoidCallback? onDeleted;
  const _EditorSheet({required this.item, this.onDeleted});

  @override
  State<_EditorSheet> createState() => _EditorSheetState();
}

class _EditorSheetState extends State<_EditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.item.title);
    _note = TextEditingController(text: widget.item.note);
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    final it = widget.item;
    final pad = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(left: S.md, right: S.md, top: S.md, bottom: pad + S.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: c.line, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: S.md),
          TextField(
            controller: _title,
            autofocus: it.title.isEmpty,
            style: TextStyle(fontSize: S.textLg, fontWeight: FontWeight.bold, color: c.ink),
            maxLines: null,
            decoration: InputDecoration(
              hintText: it.isIdea ? '想到什么，先记下来' : '这一步要做什么？',
              hintStyle: TextStyle(color: c.inkSoft),
              border: InputBorder.none,
            ),
          ),
          if (!it.isIdea)
            TextField(
              controller: _note,
              style: TextStyle(fontSize: S.textMd, color: c.ink),
              maxLines: null,
              decoration: InputDecoration(
                hintText: '备注（可选）',
                hintStyle: TextStyle(color: c.inkSoft),
                border: InputBorder.none,
              ),
            ),
          const SizedBox(height: S.sm),
          if (!it.isIdea)
            Row(
              children: [
                IconBtn(Icons.today_outlined,
                    tip: '安排时间', color: it.dueTime > 0 ? c.accent : c.ink, onTap: _pickDue),
                Text(
                  it.dueTime > 0 ? _fmtDue(it.dueTime) : '随时',
                  style: TextStyle(color: c.inkSoft, fontSize: S.textSm),
                ),
                const Spacer(),
                if (it.dueTime > 0)
                  IconBtn(Icons.close, tip: '清除时间', onTap: () async {
                    it.dueTime = 0;
                    await StartStore.I.put(it);
                  }),
              ],
            ),
          const SizedBox(height: S.xs),
          Wrap(
            spacing: S.xs,
            runSpacing: S.xs,
            children: [
              _Chip(label: '设为今日焦点', icon: Icons.star_outline, onTap: () async {
                await StartStore.I.setFocus(it.id);
                if (context.mounted) Navigator.pop(context);
              }),
              if (!it.isIdea)
                _Chip(label: '拆成小步骤', icon: Icons.call_split, onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context, rootNavigator: true)
                      .pushNamed('/steps', arguments: it.id);
                }),
              _Chip(label: '删除', icon: Icons.delete_outline, danger: true, onTap: () async {
                final removed = StartStore.I.delete(it.id, cascade: !it.isIdea);
                if (context.mounted) {
                  Navigator.pop(context);
                  widget.onDeleted?.call();
                  UndoHost.show(
                    context,
                    it.isIdea ? '已删除念头' : '已删除（含小步骤）',
                    () async => StartStore.I.restore(removed),
                  );
                }
              }),
            ],
          ),
          const SizedBox(height: S.md),
          Pressable(
            onTap: () async {
              it.title = _title.text.trim();
              it.note = _note.text.trim();
              if (it.isEmpty) {
                StartStore.I.delete(it.id);
              } else {
                await StartStore.I.put(it);
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(S.radius)),
              child: const Text('好了',
                  style: TextStyle(color: Colors.white, fontSize: S.textMd, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDue() async {
    final it = widget.item;
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: it.dueTime > 0 ? DateTime.fromMillisecondsSinceEpoch(widget.item.dueTime) : now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
          it.dueTime > 0 ? DateTime.fromMillisecondsSinceEpoch(widget.item.dueTime) : now),
    );
    if (t == null || !mounted) return;
    widget.item.dueTime =
        DateTime(d.year, d.month, d.day, t.hour, t.minute).millisecondsSinceEpoch;
    await StartStore.I.put(widget.item);
  }

  static String _fmtDue(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final day = DateTime(d.year, d.month, d.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = day.difference(today).inDays;
    final hm = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (diff == 0) return '今天 $hm';
    if (diff == 1) return '明天 $hm';
    return '${d.month}/${d.day} $hm';
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool danger;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.icon, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    final color = danger ? c.accentDark : c.ink;
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: S.sm, vertical: S.xs),
        decoration: BoxDecoration(
          color: c.cardAlt,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: S.xxs),
            Text(label, style: TextStyle(color: color, fontSize: S.textSm)),
          ],
        ),
      ),
    );
  }
}

/// 快速记一件：随手做任务 或 念头。
Future<void> showQuickAdd(BuildContext context, {bool idea = false}) {
  return showStartSheet(
    context,
    (_) => _QuickAdd(idea: idea),
  );
}

class _QuickAdd extends StatefulWidget {
  final bool idea;
  const _QuickAdd({required this.idea});

  @override
  State<_QuickAdd> createState() => _QuickAddState();
}

class _QuickAddState extends State<_QuickAdd> {
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    final pad = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(left: S.md, right: S.md, top: S.md, bottom: pad + S.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _ctl,
            autofocus: true,
            maxLines: null,
            style: TextStyle(fontSize: S.textLg, color: c.ink),
            decoration: InputDecoration(
              hintText: widget.idea ? '一个念头一句话' : '记一件要做的事',
              hintStyle: TextStyle(color: c.inkSoft),
              border: InputBorder.none,
            ),
          ),
          const SizedBox(height: S.md),
          Pressable(
            onTap: () async {
              final t = _ctl.text.trim();
              if (t.isNotEmpty) {
                final it = Item(
                  kind: widget.idea ? Item.kindIdea : Item.kindTask,
                  title: t,
                  rank: -1,
                );
                await StartStore.I.put(it, touchRank: true);
                if (widget.idea && StartStore.I.prefBool('haptic', true)) {
                  Native.vibrate(15);
                }
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(S.radius)),
              child: const Text('记下了',
                  style: TextStyle(color: Colors.white, fontSize: S.textMd, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
