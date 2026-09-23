import 'package:flutter/material.dart';

import '../channels/native.dart';
import '../data/item.dart';
import '../data/store.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';

/// 动手吧：一股脑输入，按行和句末标点（。！？；…）拆成小步骤预览，确认后各存一条念头。
class DumpScreen extends StatefulWidget {
  final String initial;
  const DumpScreen({super.key, this.initial = ''});

  @override
  State<DumpScreen> createState() => _DumpScreenState();
}

class _DumpScreenState extends State<DumpScreen> {
  final _ctl = TextEditingController();
  List<String> _preview = [];

  @override
  void initState() {
    super.initState();
    _ctl.text = widget.initial;
    _ctl.addListener(_rebuild);
    _rebuild();
    _loadShare();
  }

  Future<void> _loadShare() async {
    if (widget.initial.isEmpty) {
      final t = await Native.initialShare();
      if (t != null && t.trim().isNotEmpty && mounted && _ctl.text.isEmpty) {
        _ctl.text = t;
      }
    }
  }

  void _rebuild() {
    setState(() => _preview = splitSentences(_ctl.text));
  }

  /// 按行和句末标点拆分（不按逗号），移植自老版 DumpActivity。
  static List<String> splitSentences(String text) {
    final out = <String>[];
    final lines = text.split(RegExp(r'\r?\n'));
    final enders = RegExp(r'[。！？；…]');
    for (final line in lines) {
      var buf = StringBuffer();
      for (final ch in line.characters) {
        buf.write(ch);
        if (enders.hasMatch(ch)) {
          final s = buf.toString().trim();
          if (s.isNotEmpty) out.add(s);
          buf = StringBuffer();
        }
      }
      final rest = buf.toString().trim();
      if (rest.isNotEmpty) out.add(rest);
    }
    return out;
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    final pad = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      backgroundColor: c.paper,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(S.md, S.sm, S.md, S.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconBtn(Icons.arrow_back, onTap: () => Navigator.pop(context)),
                  const Spacer(),
                  Text('动手吧',
                      style: TextStyle(fontSize: S.textLg, fontWeight: FontWeight.bold, color: c.ink)),
                  const Spacer(),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: S.sm),
              Expanded(
                flex: _preview.isEmpty ? 3 : 2,
                child: StartCard(
                  child: TextField(
                    controller: _ctl,
                    autofocus: true,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: TextStyle(fontSize: S.textLg, color: c.ink, height: 1.5),
                    decoration: InputDecoration(
                      hintText: '想到什么一股脑写下来，回头再拆',
                      hintStyle: TextStyle(color: c.inkSoft),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              if (_preview.isNotEmpty) ...[
                const SizedBox(height: S.sm),
                Text('将拆成 ${_preview.length} 件',
                    style: TextStyle(fontSize: S.textSm, color: c.inkSoft)),
                const SizedBox(height: S.xs),
                Expanded(
                  flex: 1,
                  child: ListView.builder(
                    itemCount: _preview.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: S.xxs),
                      child: Row(
                        children: [
                          Text('·',
                              style: TextStyle(color: c.accent, fontWeight: FontWeight.bold)),
                          const SizedBox(width: S.xs),
                          Expanded(
                            child: Text(_preview[i],
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: S.textMd, color: c.ink)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              SizedBox(
                height: 48,
                child: Pressable(
                  onTap: _preview.isEmpty ? null : () async {
                    final n = _preview.length;
                    for (var i = 0; i < n; i++) {
                      await StartStore.I.put(
                        Item(kind: Item.kindIdea, title: _preview[i], rank: -1),
                        touchRank: true,
                      );
                    }
                    if (!mounted) return;
                    UndoHost.show(context, '记下了 $n 件，去念头页捋一捋', () {});
                    Navigator.pop(context);
                  },
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _preview.isEmpty ? c.cardAlt : c.accent,
                      borderRadius: BorderRadius.circular(S.radius),
                    ),
                    child: Text(
                      _preview.isEmpty ? '先写点什么' : '拆成 ${_preview.length} 件',
                      style: TextStyle(
                        color: _preview.isEmpty ? c.inkSoft : Colors.white,
                        fontSize: S.textMd,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
