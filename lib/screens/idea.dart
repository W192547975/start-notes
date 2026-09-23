import 'package:flutter/material.dart';

import '../channels/native.dart';
import '../data/item.dart';
import '../data/store.dart';
import '../theme/tokens.dart';
import '../widgets/editor.dart';
import '../widgets/ui.dart';
import 'bigbang.dart';
import 'dump.dart';

class IdeaScreen extends StatefulWidget {
  const IdeaScreen({super.key});

  @override
  State<IdeaScreen> createState() => _IdeaScreenState();
}

class _IdeaScreenState extends State<IdeaScreen> {
  bool _selecting = false;
  final Set<int> _selected = {};

  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    final s = StartStore.I;
    final list = s.ideas();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(S.md, S.sm, S.md, S.sm),
              child: Row(
                children: [
                  Text('念头',
                      style: TextStyle(
                          fontSize: S.textXl, fontWeight: FontWeight.bold, color: c.ink)),
                  const Spacer(),
                  if (_selecting) ...[
                    IconBtn(Icons.select_all_outlined, tip: '全选', onTap: () {
                      setState(() {
                        _selected.length == list.length
                            ? _selected.clear()
                            : _selected.addAll(list.map((e) => e.id));
                      });
                    }),
                    IconBtn(Icons.done_all_outlined,
                        tip: '完成', onTap: () => _finishBatch(true)),
                    IconBtn(Icons.delete_outline, tip: '删除', onTap: () => _finishBatch(false)),
                    IconBtn(Icons.close, tip: '退出选择', onTap: () {
                      setState(() {
                        _selecting = false;
                        _selected.clear();
                      });
                    }),
                  ] else ...[
                    IconBtn(Icons.delete_outline, tip: '批量整理', onTap: () {
                      if (list.isNotEmpty) setState(() => _selecting = true);
                    }),
                    IconBtn(Icons.add, tip: '记一个念头', onTap: () => showQuickAdd(context, idea: true)),
                    IconBtn(Icons.fork_right_outlined, tip: '一股脑丢进来', onTap: _openDump),
                  ],
                ],
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? EmptyView(
                      icon: Icons.lightbulb_outline,
                      text: '心里冒出什么，随手丢进来',
                      action: '记一个念头',
                      onAction: () => showQuickAdd(context, idea: true),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(S.md, 0, S.md, S.md),
                      proxyDecorator: (child, i, a) => ScaleTransition(scale: a, child: child),
                      itemCount: list.length,
                      onReorder: (o, n) async {
                        final ids = list.map((e) => e.id).toList();
                        if (n > o) n--;
                        ids.insert(n, ids.removeAt(o));
                        await s.reorder(ids);
                      },
                      itemBuilder: (_, i) {
                        final it = list[i];
                        final sel = _selected.contains(it.id);
                        return Padding(
                          key: ValueKey(it.id),
                          padding: const EdgeInsets.only(bottom: S.xs),
                          child: Pressable(
                            onTap: _selecting
                                ? () => setState(
                                    () => sel ? _selected.remove(it.id) : _selected.add(it.id))
                                : () => showBigBang(context, it.title, onDone: (kept) async {
                                      // 拆词成独立念头：选中词各存一条，替换原念头
                                      if (kept.length <= 1) return;
                                      final now = DateTime.now().millisecondsSinceEpoch;
                                      for (var k = 0; k < kept.length; k++) {
                                        await s.put(Item(kind: Item.kindIdea, title: kept[k], rank: -1, created: now + k),
                                            touchRank: true);
                                      }
                                      await s.delete(it.id, cascade: false);
                                      if (context.mounted) {
                                        UndoHost.show(context, '拆成了 ${kept.length} 条', () async {
                                          await s.restore([it]);
                                          for (final e in s.ideas()) {
                                            if (kept.contains(e.title) && e.id > it.id) {
                                              s.delete(e.id, cascade: false);
                                            }
                                          }
                                        });
                                      }
                                    }),
                            onDoubleTap: () async {
                              final removed = s.delete(it.id, cascade: false);
                              UndoHost.show(context, '已删除念头', () async => s.restore(removed));
                            },
                            onLongPress: _selecting
                                ? null
                                : () => setState(() {
                                      _selecting = true;
                                      _selected.add(it.id);
                                    }),
                            child: StartCard(
                              color: sel ? c.accentSoft : null,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: S.md, vertical: S.sm),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(it.title,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: S.textMd,
                                            fontWeight: FontWeight.bold,
                                            color: c.ink)),
                                  ),
                                  if (_selecting)
                                    Icon(
                                      sel ? Icons.check_circle : Icons.circle_outlined,
                                      color: sel ? c.accent : c.inkSoft,
                                      size: 22,
                                    )
                                  else
                                    Icon(Icons.north_west_outlined, size: 16, color: c.inkSoft),
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
  }

  Future<void> _finishBatch(bool complete) async {
    if (_selected.isEmpty) return;
    final s = StartStore.I;
    final snap = await s.deleteAll(_selected.toList(), complete: complete);
    setState(() {
      _selecting = false;
      _selected.clear();
    });
    if (!mounted) return;
    UndoHost.show(context, complete ? '已标记完成' : '已删除所选',
        () async => s.restoreJson(snap));
  }

  void _openDump() {
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => const DumpScreen()));
  }
}

// 避免 unused import（Native 用于触感）
// ignore: unused_element
var _ = Native;
