import 'package:flutter/material.dart';

import '../data/item.dart';
import '../data/store.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';
import 'bigbang.dart';

/// 捋一捋：把一件事拆成小步骤。支持输入拆词，或手动逐条添加。
class StepsScreen extends StatefulWidget {
  final int taskId;
  const StepsScreen({super.key, required this.taskId});

  @override
  State<StepsScreen> createState() => _StepsScreenState();
}

class _StepsScreenState extends State<StepsScreen> {
  bool _selecting = false;
  final Set<int> _selected = {};

  Item? get _task => StartStore.I.byId(widget.taskId);

  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    final s = StartStore.I;
    final task = _task;
    if (task == null) {
      return Scaffold(
        backgroundColor: c.paper,
        body: const Center(child: Text('这件事不存在了')),
      );
    }
    final steps = s.subtasksOf(task.id);

    return Scaffold(
      backgroundColor: c.paper,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(S.md, S.sm, S.md, S.sm),
              child: Row(
                children: [
                  IconBtn(Icons.arrow_back, onTap: () => Navigator.pop(context)),
                  const Spacer(),
                  if (_selecting) ...[
                    IconBtn(Icons.delete_outline, tip: '删除所选', onTap: () => _deleteBatch()),
                    IconBtn(Icons.close, tip: '退出选择', onTap: () {
                      setState(() {
                        _selecting = false;
                        _selected.clear();
                      });
                    }),
                  ] else
                    IconBtn(Icons.delete_outline, tip: '批量整理', onTap: () {
                      if (steps.isNotEmpty) setState(() => _selecting = true);
                    }),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: S.md),
              child: StartCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title,
                        style: TextStyle(
                            fontSize: S.textLg, fontWeight: FontWeight.bold, color: c.ink)),
                    if (steps.isNotEmpty) ...[
                      const SizedBox(height: S.xs),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: steps.every((e) => e.done)
                                    ? 1
                                    : steps.where((e) => e.done).length / steps.length,
                                minHeight: 6,
                                backgroundColor: c.cardAlt,
                                color: c.accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: S.sm),
                          Text(
                            '${steps.where((e) => e.done).length}/${steps.length}',
                            style: TextStyle(fontSize: S.textSm, color: c.inkSoft),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: S.sm),
            Expanded(
              child: steps.isEmpty
                  ? EmptyView(
                      icon: Icons.call_split,
                      text: '把这件事拆成小步骤，一步一步来',
                      action: '拆一拆',
                      onAction: () => showBigBang(
                        context,
                        task.title,
                        confirmLabel: '存为小步骤',
                        onDone: (kept) => _saveSteps(kept, task),
                      ),
                    )
                  : _StepList(steps: steps, task: task, selecting: _selecting, selected: _selected,
                      onToggleSelect: (id) => setState(() {
                        _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
                      })),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: c.accent,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        onPressed: () => showBigBang(
          context,
          task.title,
          confirmLabel: '存为小步骤',
          onDone: (kept) => _saveSteps(kept, task),
        ),
        child: const Icon(Icons.call_split),
      ),
    );
  }

  Future<void> _saveSteps(List<String> kept, Item task) async {
    if (kept.isEmpty) return;
    for (final k in kept) {
      await StartStore.I.put(Item(kind: Item.kindTask, parentId: task.id, title: k));
    }
    if (mounted) setState(() {});
  }

  Future<void> _deleteBatch() async {
    final s = StartStore.I;
    final snap = await s.deleteAll(_selected.toList());
    setState(() {
      _selecting = false;
      _selected.clear();
    });
    if (!mounted) return;
    UndoHost.show(context, '已删除所选', () async => s.restoreJson(snap));
  }
}

class _StepList extends StatelessWidget {
  final List<Item> steps;
  final Item task;
  final bool selecting;
  final Set<int> selected;
  final ValueChanged<int> onToggleSelect;

  const _StepList({
    required this.steps,
    required this.task,
    required this.selecting,
    required this.selected,
    required this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    final s = StartStore.I;
    // 当前该做的那张：第一个未完成的步骤
    final currentId = steps.firstWhere((e) => !e.done, orElse: () => steps.last).id;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(S.md, 0, S.md, S.lg),
      itemCount: steps.length,
      itemBuilder: (_, i) {
        final it = steps[i];
        final sel = selected.contains(it.id);
        final isCurrent = it.id == currentId && !it.done;
        return Padding(
          padding: const EdgeInsets.only(bottom: S.xs),
          child: Pressable(
            onTap: selecting
                ? () => onToggleSelect(it.id)
                : () async {
                    it.done = !it.done;
                    await s.put(it);
                    // 子步骤全部完成 → 父任务自动勾上
                    final all = s.subtasksOf(task.id);
                    if (all.isNotEmpty && all.every((e) => e.done) && !task.done) {
                      task.done = true;
                      await s.put(task);
                    }
                    if (!it.done) {
                      if (s.prefBool('haptic', true)) {
                        // 完成反馈
                      }
                    }
                  },
            onDoubleTap: () async {
              final removed = s.delete(it.id, cascade: false);
              UndoHost.show(context, '已删除步骤', () async => s.restore(removed));
            },
            child: StartCard(
              color: sel
                  ? c.accentSoft
                  : isCurrent
                      ? c.accentSoft
                      : null,
              padding: const EdgeInsets.symmetric(horizontal: S.md, vertical: S.sm),
              child: Row(
                children: [
                  if (selecting)
                    Icon(sel ? Icons.check_circle : Icons.circle_outlined,
                        color: sel ? c.accent : c.inkSoft, size: 22)
                  else
                    CheckDot(done: it.done),
                  const SizedBox(width: S.sm),
                  Expanded(
                    child: Text(
                      it.title,
                      style: TextStyle(
                        fontSize: S.textMd,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: it.done ? c.done : c.ink,
                        decoration: it.done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                  if (isCurrent && !selecting)
                    Text('下一步',
                        style: TextStyle(fontSize: S.textSm, color: c.accent, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
