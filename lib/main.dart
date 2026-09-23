import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/store.dart';
import 'data/timetable.dart';
import 'screens/focus.dart';
import 'screens/idea.dart';
import 'screens/manual.dart';
import 'screens/search.dart';
import 'screens/stats.dart';
import 'screens/steps.dart';
import 'screens/today.dart';
import 'theme/tokens.dart';
import 'widgets/ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StartStore.I.init();
  await Timetable.I.init(StartStore.I.dir);
  runApp(const StartApp());
}

class StartApp extends StatefulWidget {
  const StartApp({super.key});

  static final navigatorKey = GlobalKey<NavigatorState>();

  @override
  State<StartApp> createState() => _StartAppState();
}

class _StartAppState extends State<StartApp> {
  @override
  void initState() {
    super.initState();
    StartStore.I.addListener(_onChange);
  }

  void _onChange() {
    if (!mounted) return;
    // 触感开关等即时生效无需处理；深色/字号由 ListenableBuilder 重建
  }

  @override
  void dispose() {
    StartStore.I.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: StartStore.I,
      builder: (context, _) {
        final s = StartStore.I;
        final darkMode = s.prefInt('dark_mode', 0); // 0=跟随 1=开 2=关
        final themeMode = switch (darkMode) {
          1 => ThemeMode.dark,
          2 => ThemeMode.light,
          _ => ThemeMode.system,
        };
        final scale = s.prefDouble('font_scale', 1.0);
        final platformDark =
            WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
        final c = (themeMode == ThemeMode.dark || (themeMode == ThemeMode.system && platformDark))
            ? C.dark
            : C.light;

        return ThemeTokens(
          c: c,
          child: MaterialApp(
            title: 'Start',
            debugShowCheckedModeBanner: false,
            navigatorKey: StartApp.navigatorKey,
            theme: AppThemes.build(C.light, Brightness.light),
            darkTheme: AppThemes.build(C.dark, Brightness.dark),
            themeMode: themeMode,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
              ),
              child: child!,
            ),
            home: const EulaGate(child: Root()),
            onGenerateRoute: (settings) {
              switch (settings.name) {
                case '/steps':
                  return MaterialPageRoute(
                    builder: (_) => StepsScreen(taskId: settings.arguments as int),
                  );
                case '/focus':
                  final arg = settings.arguments;
                  return MaterialPageRoute(
                    builder: (_) => FocusScreen(taskId: arg is int ? arg : null),
                  );
              }
              return null;
            },
          ),
        );
      },
    );
  }
}

/// 首次启动/协议更新时先同意再进主界面（覆盖安装老版已同意则直接进）。
class EulaGate extends StatefulWidget {
  final Widget child;
  const EulaGate({super.key, required this.child});

  @override
  State<EulaGate> createState() => _EulaGateState();
}

class _EulaGateState extends State<EulaGate> {
  bool? _ok;

  @override
  void initState() {
    super.initState();
    _ok = StartStore.I.prefInt('eula_accepted_version', 0) >= StartStore.eulaVersion;
  }

  @override
  Widget build(BuildContext context) {
    if (_ok == true) return widget.child;
    return ManualScreen(asDialog: true, onAccept: () async {
      await StartStore.I.setPref('eula_accepted_version', StartStore.eulaVersion);
      setState(() => _ok = true);
    });
  }
}

/// 主骨架：五键无字图标底栏 + 撤销条。
class Root extends StatefulWidget {
  const Root({super.key});

  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  int _tab = 0;

  static const _icons = [
    Icons.today_outlined,
    Icons.lightbulb_outline,
    Icons.search_outlined,
    Icons.timer_outlined,
    Icons.align_horizontal_left_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    final pages = [
      const TodayScreen(),
      const IdeaScreen(),
      const SearchScreen(),
      const FocusScreen(),
      const StatsScreen(),
    ];
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _tab, children: pages),
          const UndoHost(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 60,
          margin: const EdgeInsets.symmetric(horizontal: S.md, vertical: S.xs),
          padding: const EdgeInsets.symmetric(horizontal: S.lg),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(S.radius),
            border: Border.all(color: c.line),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_icons.length, (i) {
              final selected = _tab == i;
              return Pressable(
                scale: 0.9,
                onTap: () => setState(() => _tab = i),
                child: Padding(
                  padding: const EdgeInsets.all(S.xs),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: S.md, vertical: S.xxs),
                    decoration: BoxDecoration(
                      color: selected ? c.accentSoft : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Icon(
                      _icons[i],
                      size: 24,
                      color: selected ? c.accent : c.inkSoft,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
