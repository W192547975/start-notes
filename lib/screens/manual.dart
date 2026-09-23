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
        Text('Start 把待办和念头拆成小步骤，帮你一次只做好一件事。数据只存在你手机里；唯一的联网行为是检查更新，不带走你任何数据。',
            style: TextStyle(fontSize: S.textMd, height: 1.6, color: c.ink)),
        const SizedBox(height: S.lg),
        _H('怎么用'),
        _P('念头：心里冒出什么随手丢进来。单击一条念头会把它捋一捋拆成几条，双击删除。'),
        _P('开始：一股脑全写下来，自动按行和句号拆成几件，倒进来后去捋一捋慢慢整理。'),
        _P('捋一捋：每条暂存可分类为念头/日程/随手做，点导图图标进入思维导图——点按选中节点，可加子枝、加同级、编辑、删除，按住拖动自由摆放；也可拆词（词芯片默认全选，点一下取消，双击删词，长按拖动换位）。'),
        _P('随手做：没定时间的事都待在这。长按卡片可以设为今日焦点，也可以拖动排序。'),
        _P('专注：空心圆环倒计时，结束有提示音。在设置里可以换滴答声、提示方式和音量。'),
        const SizedBox(height: S.lg),
        _H('用户协议'),
        _P('1. 本应用对个人非商业使用永久免费，商业使用需开发者的书面授权。'),
        _P('2. 本应用由个人开发者借助人工智能工具开发，开发者不编写程序代码。应用按"现状"提供，不作任何明示或暗示的担保。'),
        _P('3. 你的所有内容仅存储在设备本地；唯一联网行为是检查软件更新（访问代码托管平台的公开接口，不发送你的任何数据）。'),
        _P('4. 请使用设置里的导出功能自行备份；设备丢失、损坏或卸载造成的数据损失，开发者不承担责任。'),
        _P('5. 继续使用即表示同意本协议；协议有更新时会再次征求你的同意。'),
        const SizedBox(height: S.lg),
        _H('隐私政策'),
        _P('1. 不收集、不上传：没有账户、没有广告、没有统计 SDK，所有内容只存在你的手机里。'),
        _P('2. 唯一联网：检查更新时访问代码托管平台的公开接口，仅取回最新版本号，不携带你的任何数据。'),
        _P('3. 日程与随手做的到点提醒、常驻通知，全部在你手机本机完成，不经过任何服务器。'),
        _P('4. 卸载应用即彻底删除全部数据；想留底请先用导出功能。'),
        _P('5. 对本政策有疑问，欢迎在代码托管平台的项目页留言。'),
        const SizedBox(height: S.lg),
        _H('开源许可证（GPLv3）'),
        _P('本程序是自由软件，依据 GNU 通用公共许可证第 3 版发布，你可以据此重新分发或修改它。以下是许可证全文：'),
        const SizedBox(height: S.xs),
        SelectableText(_gpl, style: TextStyle(fontSize: 11, height: 1.4, color: c.inkSoft)),
        const SizedBox(height: S.lg),
        Center(
          child: Text('Start V1 · 个人开发者 王浩然',
              style: TextStyle(fontSize: S.textSm, color: c.inkSoft)),
        ),
        const SizedBox(height: S.sm),
        Center(
          child: Text('── 工匠的骄傲与喜悦 · PRIDE & JOY ──',
              style: TextStyle(fontSize: 11, letterSpacing: 1, color: c.inkSoft)),
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
