import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../theme/tokens.dart';
import '../widgets/ui.dart';

/// 说明书 / 用户协议 / GPL 许可证。
/// 开头第一句就是软件用途。
class ManualScreen extends StatefulWidget {
  final bool asDialog;
  final VoidCallback? onAccept;
  const ManualScreen({super.key, this.asDialog = false, this.onAccept});

  @override
  State<ManualScreen> createState() => _ManualScreenState();
}

class _ManualScreenState extends State<ManualScreen> {
  String _gpl = '加载中…';

  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/gpl.txt').then((v) {
      if (mounted) setState(() => _gpl = v);
    }).catchError((_) {
      if (mounted) setState(() => _gpl = '许可证文本缺失，请查阅项目根目录 LICENSE 文件。');
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    final body = ListView(
      padding: const EdgeInsets.all(S.md),
      children: [
        Text('Start 是把待办和念头拆成小步骤、帮你专注做完一件事的记事工具。数据只存在你手机里，不联网、不要账号。',
            style: TextStyle(fontSize: S.textMd, height: 1.6, color: c.ink)),
        const SizedBox(height: S.lg),
        _H('怎么用'),
        _P('念头：心里冒出什么随手丢进来。单击一条念头会把它捋一捋拆成几条，双击删除。'),
        _P('动手吧：一股脑全写下来，自动按句拆成几件，回头慢慢捋。'),
        _P('捋一捋：把一件事拆成小步骤，词芯片默认全选，点一下取消，双击删词，长按拖动换位。做完一步勾一步，全做完这件事自动打勾。'),
        _P('随手做：没定时间的事都待在这。长按卡片可以设为今日焦点，也可以拖动排序。'),
        _P('专注：空心圆环倒计时，结束有提示音。在设置里可以换滴答声、提示方式和音量。'),
        const SizedBox(height: S.lg),
        _H('用户协议'),
        _P('1. 本应用对个人非商业使用永久免费，商业使用需开发者的书面授权。'),
        _P('2. 本应用不联网、不收集任何数据，所有内容仅存储在你的设备本地；请自行备份，设备丢失或卸载造成的损失开发者不承担责任。'),
        _P('3. 本应用按"现状"提供，不作任何明示或暗示的担保。'),
        _P('4. 继续使用即表示同意本协议；协议有更新时会再次征求同意。'),
        const SizedBox(height: S.lg),
        _H('开源许可证（GPLv3）'),
        _P('本程序是自由软件，依据 GNU 通用公共许可证第 3 版发布，你可以据此重新分发或修改它。以下是许可证全文：'),
        const SizedBox(height: S.xs),
        SelectableText(_gpl, style: TextStyle(fontSize: 11, height: 1.4, color: c.inkSoft)),
        const SizedBox(height: S.lg),
        Center(
          child: Text('Start 3.0 · 个人开发者 王浩然',
              style: TextStyle(fontSize: S.textSm, color: c.inkSoft)),
        ),
        const SizedBox(height: S.xl),
      ],
    );

    if (!widget.asDialog) {
      return Scaffold(
        backgroundColor: c.paper,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(S.md, S.sm, S.md, 0),
                child: Row(
                  children: [
                    IconBtn(Icons.arrow_back, onTap: () => Navigator.pop(context)),
                    const Spacer(),
                    Icon(Icons.menu_book_outlined, color: c.inkSoft),
                  ],
                ),
              ),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }

    // 首次启动协议页
    return Scaffold(
      backgroundColor: c.paper,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(S.lg),
              child: Text('欢迎使用 Start',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: c.ink)),
            ),
            Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: S.md),
              child: body,
            )),
            Padding(
              padding: const EdgeInsets.all(S.md),
              child: Pressable(
                onTap: widget.onAccept,
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration:
                      BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(S.radius)),
                  child: const Text('同意并开始',
                      style: TextStyle(
                          color: Colors.white, fontSize: S.textMd, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _H extends StatelessWidget {
  final String t;
  const _H(this.t);
  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    return Text(t,
        style: TextStyle(fontSize: S.textLg, fontWeight: FontWeight.bold, color: c.ink));
  }
}

class _P extends StatelessWidget {
  final String t;
  const _P(this.t);
  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: S.xs),
      child: Text(t, style: TextStyle(fontSize: S.textMd, height: 1.6, color: c.ink)),
    );
  }
}
