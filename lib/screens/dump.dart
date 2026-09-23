import 'package:flutter/material.dart';

import '../channels/native.dart';
import '../data/item.dart';
import '../data/store.dart';
import '../theme/tokens.dart';
import '../widgets/editor.dart';
import '../widgets/ui.dart';
import 'segment_screen.dart';

/// 开始 = 暂存区。纯文字模式：输入框 + 倒进来圆钮，
/// 按行和句末标点（。！？；…）拆成多条 kindInbox 暂存（老版 DumpActivity 规则）。
/// 暂存条目只展示文本 + 编辑 + 删除；分类/拆词一律去「捋一捋」tab 操作。
class DumpScreen extends StatefulWidget {
  final String initial;
  const DumpScreen({super.key, this.initial = ''});

  @override
  State<DumpScreen> createState() => _DumpScreenState();
}

class _DumpScreenState extends State<DumpScreen> {
  final _ctl = TextEditingController();
  bool _empty = true;

  @override
  void initState() {
    super.initState();
    _ctl.text = widget.initial;
    _empty = _ctl.text.trim().isEmpty;
    _ctl.addListener(_sync);
    _loadShare();
  }

  void _sync() {
    final e = _ctl.text.trim().isEmpty;
    if (e != _empty) setState(() => _empty = e);
  }

  Future<void> _loadShare() async {
    if (widget.initial.isEmpty) {
      final t = await Native.initialShare();
      if (t != null && t.trim().isNotEmpty && mounted && _ctl.text.isEmpty) {
        _ctl.text = t;
      }
    }
  }

  @override
  void dispose() {
    _ctl.removeListener(_sync);
    _ctl.dispose();
    super.dispose();
  }

  /// 按行 + 句末标点（。！？；…）拆条；逗号不拆。
  List<String> _chunks(String raw) {
    final out = <String>[];
    for (final line in raw.split(RegExp(r'[\n\r]+'))) {
      final l = line.trim();
      if (l.isEmpty) continue;
      for (final p in l.split(RegExp(r'(?<=[。！？；…])'))) {
        final t = p.trim();
        if (t.isNotEmpty) out.add(t);
      }
    }
    return out;
  }

  /// 倒进来：拆成多条暂存，存完切到捋一捋整理（先存再捋）。
  Future<void> _dump() async {
    final chunks = _chunks(_ctl.text);
    if (chunks.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < chunks.length; i++) {
      await StartStore.I.put(
        Item(kind: Item.kindInbox, title: chunks[i], rank: -1, created: now + i),
        touchRank: true,
      );
    }
    _ctl.clear();
    if (!mounted) return;
    // 存完跳捋一捋整理。pushReplacement 替换本页，捋完返回回首页。
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => const SegmentScreen()));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: StartStore.I,
        builder: (context, _) => _build(context),
      );

  Widget _build(BuildContext context) {
    final c = ThemeTokens.of(context);
    final s = StartStore.I;
    final list = s.inboxTasks();

    return Scaffold(
      backgroundColor: c.paper,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHead('开始', count: list.length, onBack: () => Navigator.pop(context)),
            _inputPanel(c),
            Expanded(
              child: list.isEmpty
                  ? const EmptyView(
                      icon: Icons.inbox_outlined,
                      text: '空空如也，倒点东西进来',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(S.md, 0, S.md, S.lg + 16),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _InboxCard(it: list[i], onChange: () => setState(() {})),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 文字面板：输入框（自动聚焦）+ 倒进来圆钮（空=灰，有字=番茄红）。
  Widget _inputPanel(C c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(S.md, 0, S.md, S.sm),
      child: StartCard(
        padding: const EdgeInsets.fromLTRB(S.md, S.xs, S.xs, S.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _ctl,
                autofocus: widget.initial.isEmpty,
                minLines: 1,
                maxLines: 6,
                style: TextStyle(fontSize: S.textMd, color: c.ink, height: 1.4),
                decoration: InputDecoration(
                  hintText: '想到什么一股脑写下来',
                  hintStyle: TextStyle(color: c.inkSoft, fontSize: S.textSm),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: S.xs),
            Pressable(
              onTap: _empty ? null : _dump,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: S.xxs),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _empty ? c.cardAlt : c.accent,
                  ),
                  child: Icon(Icons.south, size: 20,
                      color: _empty ? c.inkSoft : Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 一条暂存条目：文本 + 铅笔编辑 + 删除。分类与拆词请去「捋一捋」。
class _InboxCard extends StatelessWidget {
  final Item it;
  final VoidCallback onChange;
  const _InboxCard({required this.it, required this.onChange});

  Future<void> _delete(BuildContext context) async {
    final removed = StartStore.I.delete(it.id, cascade: false);
    onChange();
    if (context.mounted) {
      UndoHost.show(context, '删了一条', () async => StartStore.I.restore(removed));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: S.xs),
      child: StartCard(
        padding: const EdgeInsets.symmetric(horizontal: S.md, vertical: S.xs),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: S.xs),
                child: Text(
                  it.title,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: S.textMd, color: c.ink, height: 1.4),
                ),
              ),
            ),
            IconBtn(Icons.edit_outlined, tip: '编辑', color: c.inkSoft,
                onTap: () => showTextEdit(context, it, onSaved: onChange)),
            IconBtn(Icons.delete_outline, tip: '删除', color: c.inkSoft, onTap: () => _delete(context)),
          ],
        ),
      ),
    );
  }
}
