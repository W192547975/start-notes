import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../theme/tokens.dart';
import '../widgets/ui.dart';

/// 文本页通用骨架：返回 + 标题 + 图标 + 正文。
class TextPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  const TextPage({super.key, required this.icon, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
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
                  Expanded(
                    child: Text(title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: S.textLg, fontWeight: FontWeight.bold, color: c.ink)),
                  ),
                  Icon(icon, color: c.inkSoft),
                ],
              ),
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.all(S.md), children: children),
            ),
          ],
        ),
      ),
    );
  }
}

/// 说明书：软件用途开头 + 怎么用 + 页脚致敬。
class ManualScreen extends StatelessWidget {
  const ManualScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    return TextPage(
      icon: Icons.menu_book_outlined,
      title: '说明书',
      children: [
        Text('Start 把待办和念头拆成小步骤，帮你一次只做好一件事。为 ADHD 人群设计：措辞鼓励、低阻力、不责备。数据只存在你手机里，唯一的联网行为是检查更新。',
            style: TextStyle(fontSize: S.textMd, height: 1.6, color: c.ink)),
        const SizedBox(height: S.lg),
        const _H('快速上手'),
        const _P('1. 点底栏中央的「开始」，一股脑全写下来——会自动按行和句末标点拆成几件。'),
        const _P('2. 去「捋一捋」，把每条分到念头 / 日程 / 随手做。'),
        const _P('3. 回首页，从今日焦点里选一件事，点圆钮开做。'),
        const SizedBox(height: S.lg),
        const _H('首页'),
        const _P('大时钟 + 今日焦点：一屏只放一件事，大按钮直接进专注，完成就地有鼓励；不想做这件就换一件。'),
        const _P('日程：定时间的任务按时间线排列，到点弹横幅提醒；过期的只安静标出日期，不变红、不责备。'),
        const _P('随手做：没定时间的事都待在这，可拖动排序；批量勾选可整批完成或删除，删错了 6 秒内可撤回。'),
        const _P('小步骤：点今日焦点的拆步骤图标进入——输入条写一步存一步，回车换行多写几步，保存时按行自动拆成多条；写的内容点拆词图标，还能捋一捋拆词。'),
        const SizedBox(height: S.lg),
        const _H('念头'),
        const _P('心里冒出什么随手丢进来。单击一条念头把它捋一捋拆成几条，双击删除，长按多选，铅笔编辑。'),
        const SizedBox(height: S.lg),
        const _H('开始'),
        const _P('底栏中央的红色键。不用想分类，先写下来再说；写完点「倒进来」，内容自动拆条进捋一捋。'),
        const SizedBox(height: S.lg),
        const _H('捋一捋'),
        const _P('分类：每条暂存可分类为念头 / 日程（设日期时间）/ 随手做；长按进批量，可全选、整批分类或删除。'),
        const _P('拆词：把一句话按词拆开重组（词芯片默认全选，点一下取消，双击删词，长按拖动换位），词、句、混写都能分辨。'),
        const _P('思维导图：点导图图标进入——点按选中节点，可加子枝、加同级、编辑、删除，按住拖动自由摆放，双指缩放，可恢复自动布局。'),
        const _P('右上角加号可直接新建暂存。'),
        const SizedBox(height: S.lg),
        const _H('专注与统计'),
        const _P('专注：空心圆环倒计时，结束有提示音。滴答声、提示方式和音量都在设置里调。'),
        const _P('统计：完成数与专注分钟，看得见自己的进展。'),
        const SizedBox(height: S.lg),
        const _H('数据与提醒'),
        const _P('数据全在本机：设置里可导出一个 JSON 文件带走，恢复前会自动快照、可撤销；卸载即删，记得先导出。'),
        const _P('到点提醒与常驻通知都在手机本机完成；重启手机会自动重排提醒。首页日程还会合并显示手机日历当天事件（可拒绝授权）。'),
        const SizedBox(height: S.lg),
        const _H('关于交互'),
        const _P('我是锤子手机用户，深受 Smartisan OS 影响：闪念胶囊变成念头，大爆炸变成捋一捋，一步变成开始——先记录，后整理，想法要有一抬手就够得着的容器。'),
        const SizedBox(height: S.lg),
        Center(
          child: Text('Start', style: TextStyle(fontSize: S.textSm, color: c.inkSoft)),
        ),
        const SizedBox(height: S.sm),
        Center(
          child: Text('── 工匠的骄傲与喜悦 · PRIDE & JOY ──',
              style: TextStyle(fontSize: 11, letterSpacing: 1, color: c.inkSoft)),
        ),
        const SizedBox(height: S.xl),
      ],
    );
  }
}

/// 用户协议 / 隐私政策：设置页独立入口。
class AgreeScreen extends StatelessWidget {
  final bool privacy;
  const AgreeScreen({super.key, required this.privacy});

  @override
  Widget build(BuildContext context) {
    return TextPage(
      icon: privacy ? Icons.privacy_tip_outlined : Icons.description_outlined,
      title: privacy ? '隐私政策' : '用户协议',
      children: privacy
          ? const [
              _P('1. 不收集、不上传：没有账户、没有广告、没有统计 SDK，所有内容只存在你的手机里。'),
              _P('2. 唯一联网：检查更新时访问代码托管平台的公开接口，仅取回最新版本号，不携带你的任何数据。'),
              _P('3. 日程与随手做的到点提醒、常驻通知，全部在你手机本机完成，不经过任何服务器。'),
              _P('4. 卸载应用即彻底删除全部数据；想留底请先用导出功能。'),
              _P('5. 对本政策有疑问，可通过设置里的「联系作者」咨询开发者。'),
            ]
          : const [
              _P('1. 本应用对个人非商业使用永久免费，商业使用需开发者的书面授权。'),
              _P('2. 本应用由个人开发者借助人工智能工具开发，开发者不编写程序代码。应用按"现状"提供，不作任何明示或暗示的担保。'),
              _P('3. 你的所有内容仅存储在设备本地；唯一联网行为是检查软件更新（访问代码托管平台的公开接口，不发送你的任何数据）。'),
              _P('4. 请使用设置里的导出功能自行备份；设备丢失、损坏或卸载造成的数据损失，开发者不承担责任。'),
              _P('5. 继续使用即表示同意本协议；协议有更新时会再次征求你的同意。'),
            ],
    );
  }
}

/// 开源协议：GPLv3 全文（assets/gpl.txt）。
class LicenseScreen extends StatefulWidget {
  const LicenseScreen({super.key});

  @override
  State<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends State<LicenseScreen> {
  String _gpl = '加载中…';

  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/gpl.txt').then((v) {
      if (mounted) setState(() => _gpl = v);
    }).catchError((_) {
      if (mounted) setState(() => _gpl = '许可证文本缺失，请查阅项目仓库 LICENSE 文件。');
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    return TextPage(
      icon: Icons.gavel_outlined,
      title: '开源协议（GPLv3）',
      children: [
        const _P('本程序是自由软件，依据 GNU 通用公共许可证第 3 版发布，你可以据此重新分发或修改它。以下是许可证全文：'),
        const SizedBox(height: S.sm),
        SelectableText(_gpl, style: TextStyle(fontSize: 11, height: 1.4, color: c.inkSoft)),
        const SizedBox(height: S.xl),
      ],
    );
  }
}

/// 首次启动欢迎页：只展示用户协议与隐私条款，无外链。
class FirstRunScreen extends StatelessWidget {
  final VoidCallback onAccept;
  const FirstRunScreen({super.key, required this.onAccept});

  @override
  Widget build(BuildContext context) {
    final c = ThemeTokens.of(context);
    return Scaffold(
      backgroundColor: c.paper,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(S.lg),
              child: Text('欢迎使用 Start',
                  style:
                      TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: c.ink)),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: S.md),
                children: const [
                  _P('Start 把待办和念头拆成小步骤，帮你一次只做好一件事。数据只存在你手机里，不带走你任何数据。'),
                  SizedBox(height: S.lg),
                  _H('用户协议'),
                  _P('1. 本应用对个人非商业使用永久免费，商业使用需开发者的书面授权。'),
                  _P('2. 本应用由个人开发者借助人工智能工具开发，开发者不编写程序代码。应用按"现状"提供，不作任何明示或暗示的担保。'),
                  _P('3. 你的所有内容仅存储在设备本地；唯一联网行为是检查软件更新（访问代码托管平台的公开接口，不发送你的任何数据）。'),
                  _P('4. 请使用设置里的导出功能自行备份；设备丢失、损坏或卸载造成的数据损失，开发者不承担责任。'),
                  _P('5. 继续使用即表示同意本协议；协议有更新时会再次征求你的同意。'),
                  SizedBox(height: S.lg),
                  _H('隐私政策'),
                  _P('1. 不收集、不上传：没有账户、没有广告、没有统计 SDK，所有内容只存在你的手机里。'),
                  _P('2. 唯一联网：检查更新时访问代码托管平台的公开接口，仅取回最新版本号，不携带你的任何数据。'),
                  _P('3. 日程与随手做的到点提醒、常驻通知，全部在你手机本机完成，不经过任何服务器。'),
                  _P('4. 卸载应用即彻底删除全部数据；想留底请先用导出功能。'),
                  _P('5. 对本政策有疑问，可通过设置里的「联系作者」咨询开发者。'),
                  SizedBox(height: S.xl),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(S.md),
              child: Pressable(
                onTap: onAccept,
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: c.accent, borderRadius: BorderRadius.circular(S.radius)),
                  child: const Text('同意并开始',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: S.textMd,
                          fontWeight: FontWeight.bold)),
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
