import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/store.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';
import 'manual.dart';
import 'timetable_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    final s = StartStore.I;

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
                Icon(Icons.settings_outlined, color: c.inkSoft),
              ],
            ),
            const SizedBox(height: S.sm),
            _Group(c, label: '外观'),
            _DarkModeTile(),
            _FontTile(),
            _Group(c, label: '触感与音效'),
            _SwitchTile(
              title: '按压触感',
              value: s.prefBool('haptic', true),
              onChanged: (v) => s.setPref('haptic', v),
            ),
            _SwitchTile(
              title: '专注滴答声',
              value: s.prefBool('focus_tick', false),
              onChanged: (v) => s.setPref('focus_tick', v),
            ),
            _NotifyModeTile(),
            _VolumeTile(),
            _Group(c, label: '课表'),
            _NavTile(
              icon: Icons.calendar_today_outlined,
              title: '课表',
              onTap: () => Navigator.of(context, rootNavigator: true)
                  .push(MaterialPageRoute(builder: (_) => const TimetableScreen())),
            ),
            _Group(c, label: '数据（全在本机）'),
            _ExportTile(),
            _ImportTile(),
            _ClearTile(),
            _Group(c, label: '关于'),
            _NavTile(
              icon: Icons.menu_book_outlined,
              title: '说明书',
              onTap: () => Navigator.of(context, rootNavigator: true)
                  .push(MaterialPageRoute(builder: (_) => const ManualScreen())),
            ),
            Padding(
              padding: const EdgeInsets.all(S.sm),
              child: Center(
                child: Text('Start 3.0 · 本应用对个人非商业使用永久免费',
                    style: TextStyle(fontSize: S.textSm, color: c.inkSoft)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- 基础件 ----------------

class _Group extends StatelessWidget {
  final C c;
  final String label;
  const _Group(this.c, {required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(S.xxs, S.md, 0, S.xs),
      child: Text(label,
          style: TextStyle(fontSize: S.textSm, color: c.inkSoft, fontWeight: FontWeight.bold)),
    );
  }
}

class _Row extends StatelessWidget {
  final Widget child;
  const _Row({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: S.xs),
      child: StartCard(
        padding: const EdgeInsets.symmetric(horizontal: S.md, vertical: S.sm),
        child: child,
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchTile({required this.title, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    return _Row(
      child: Row(
        children: [
          Text(title, style: TextStyle(fontSize: S.textMd, color: c.ink)),
          const Spacer(),
          Switch(value: value, activeColor: c.accent, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _NavTile({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: S.xs),
      child: Pressable(
        onTap: onTap,
        child: StartCard(
          padding: const EdgeInsets.symmetric(horizontal: S.md, vertical: S.sm),
          child: Row(
            children: [
              Icon(icon, size: 20, color: c.ink),
              const SizedBox(width: S.sm),
              Text(title, style: TextStyle(fontSize: S.textMd, color: c.ink)),
              const Spacer(),
              Icon(Icons.chevron_right, size: 20, color: c.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- 具体设置项 ----------------

class _DarkModeTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    final s = StartStore.I;
    const opts = [('跟随系统', 0), ('开', 1), ('关', 2)];
    return _Row(
      child: Row(
        children: [
          Text('深色', style: TextStyle(fontSize: S.textMd, color: c.ink)),
          const Spacer(),
          Row(
            children: opts
                .map((o) => Padding(
                      padding: const EdgeInsets.only(left: S.xxs),
                      child: Pressable(
                        onTap: () => s.setPref('dark_mode', o.$2),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: S.sm, vertical: S.xxs),
                          decoration: BoxDecoration(
                            color: s.prefInt('dark_mode', 0) == o.$2 ? c.accent : c.cardAlt,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(o.$1,
                              style: TextStyle(
                                  fontSize: S.textSm,
                                  fontWeight: FontWeight.bold,
                                  color: s.prefInt('dark_mode', 0) == o.$2 ? Colors.white : c.ink)),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _FontTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    final s = StartStore.I;
    const opts = [('小', 0), ('中', 1), ('大', 2)];
    return _Row(
      child: Row(
        children: [
          Text('字号', style: TextStyle(fontSize: S.textMd, color: c.ink)),
          const Spacer(),
          Row(
            children: opts
                .map((o) => Padding(
                      padding: const EdgeInsets.only(left: S.xxs),
                      child: Pressable(
                        onTap: () => s.setPref('font_scale', AppThemes.fontScales[o.$2]),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: S.sm, vertical: S.xxs),
                          decoration: BoxDecoration(
                            color: (s.prefDouble('font_scale', 1.0) - AppThemes.fontScales[o.$2]).abs() < 0.01
                                ? c.accent
                                : c.cardAlt,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            o.$1,
                            style: TextStyle(
                              fontSize: S.textSm,
                              fontWeight: FontWeight.bold,
                              color: (s.prefDouble('font_scale', 1.0) - AppThemes.fontScales[o.$2]).abs() < 0.01
                                  ? Colors.white
                                  : c.ink,
                            ),
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _NotifyModeTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    final s = StartStore.I;
    const opts = [('声音', 0), ('震动', 1), ('静默', 2)];
    return _Row(
      child: Row(
        children: [
          Text('做完提示', style: TextStyle(fontSize: S.textMd, color: c.ink)),
          const Spacer(),
          Row(
            children: opts
                .map((o) => Padding(
                      padding: const EdgeInsets.only(left: S.xxs),
                      child: Pressable(
                        onTap: () => s.setPref('focus_notify', o.$2),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: S.sm, vertical: S.xxs),
                          decoration: BoxDecoration(
                            color: s.prefInt('focus_notify', 0) == o.$2 ? c.accent : c.cardAlt,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(o.$1,
                              style: TextStyle(
                                  fontSize: S.textSm,
                                  fontWeight: FontWeight.bold,
                                  color: s.prefInt('focus_notify', 0) == o.$2 ? Colors.white : c.ink)),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _VolumeTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    final s = StartStore.I;
    return _Row(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('提示音量', style: TextStyle(fontSize: S.textMd, color: c.ink)),
              const Spacer(),
              Text('${s.prefInt('sound_volume', 70)}',
                  style: TextStyle(
                      fontSize: S.textSm,
                      color: c.inkSoft,
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: c.accent,
              inactiveTrackColor: c.cardAlt,
              thumbColor: c.accent,
              overlayColor: c.accentRipple,
            ),
            child: Slider(
              min: 0,
              max: 100,
              divisions: 20,
              value: s.prefInt('sound_volume', 70).toDouble(),
              onChanged: (v) {
                s.prefs['sound_volume'] = v.round();
                s.refresh();
              },
              onChangeEnd: (v) => s.setPref('sound_volume', v.round()),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    return _Row(
      child: Pressable(
        onTap: () {
          final json = StartStore.I.exportJson();
          Clipboard.setData(ClipboardData(text: json));
          UndoHost.show(context, '全部数据已复制到剪贴板，粘到别处保存', () {});
        },
        child: Row(
          children: [
            Icon(Icons.file_upload_outlined, size: 20, color: c.ink),
            const SizedBox(width: S.sm),
            Text('导出：复制到剪贴板', style: TextStyle(fontSize: S.textMd, color: c.ink)),
          ],
        ),
      ),
    );
  }
}

class _ImportTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    return _Row(
      child: Pressable(
        onTap: () async {
          final ctl = TextEditingController();
          final ok = await showStartDialog<bool>(
            context,
            title: '导入：粘贴之前导出的内容',
            content: '',
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text('算了')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('导入', style: TextStyle(color: c.accent))),
            ],
          );
          if (ok != true || !context.mounted) return;
          final text = ctl.text;
          final snap = StartStore.I.exportJson();
          final r = await StartStore.I.restoreJson(text);
          if (context.mounted) {
            UndoHost.show(context, r ? '已导入' : '内容不对，没导入',
                () async => StartStore.I.restoreJson(snap));
          }
        },
        child: Row(
          children: [
            Icon(Icons.file_download_outlined, size: 20, color: c.ink),
            const SizedBox(width: S.sm),
            Text('导入：粘贴恢复', style: TextStyle(fontSize: S.textMd, color: c.ink)),
          ],
        ),
      ),
    );
  }
}

class _ClearTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    return _Row(
      child: Pressable(
        onTap: () async {
          final ok = await showStartDialog<bool>(
            context,
            title: '清空全部？',
            content: '清空前会自动留一份快照，6 秒内可撤销。',
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text('再想想')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('清空', style: TextStyle(color: c.accentDark))),
            ],
          );
          if (ok != true || !context.mounted) return;
          final snap = await StartStore.I.clearAll();
          if (context.mounted) {
            UndoHost.show(context, '已清空', () async => StartStore.I.restoreJson(snap));
          }
        },
        child: Row(
          children: [
            Icon(Icons.delete_outline, size: 20, color: c.accentDark),
            const SizedBox(width: S.sm),
            Text('清空全部', style: TextStyle(fontSize: S.textMd, color: c.accentDark)),
          ],
        ),
      ),
    );
  }
}
