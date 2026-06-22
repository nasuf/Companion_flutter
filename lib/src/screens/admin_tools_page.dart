part of 'package:companion_flutter/main.dart';

class _ProfileAdminButton extends StatelessWidget {
  const _ProfileAdminButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = AppColors.of(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(96, 36),
      borderRadius: BorderRadius.circular(999),
      onPressed: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surfaceMuted.withValues(alpha: 0.70)
                  : Colors.white.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.76),
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: isDark ? 0.52 : 0.10),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Text(
              '管理员入口',
              maxLines: 1,
              style: TextStyle(
                color: isDark ? colors.accentDeep : colors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminToolsPage extends StatefulWidget {
  const AdminToolsPage({super.key, required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<AdminToolsPage> createState() => _AdminToolsPageState();
}

class _AdminToolsPageState extends State<AdminToolsPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motionController;
  bool _generatingActivity = false;

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _motionController.dispose();
    super.dispose();
  }

  Future<void> _triggerActivityGeneration() async {
    if (_generatingActivity) return;
    setState(() => _generatingActivity = true);

    var progressOpen = true;
    unawaited(
      showCupertinoDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _AdminProgressDialog(),
      ).whenComplete(() {
        progressOpen = false;
      }),
    );

    try {
      widget.api.authToken = widget.session.token;
      final activity = await widget.api.createOfflineActivityRecommendation(
        workspaceId: widget.session.workspaceId,
      );
      if (!mounted) return;
      if (progressOpen) Navigator.of(context, rootNavigator: true).pop();
      setState(() => _generatingActivity = false);
      if (activity == null) {
        await _showActivityResult(
          title: '暂时没有生成活动',
          message: '请确认当前账号已经授权定位，并且有可用的聊天会话。',
        );
        return;
      }
      await _showActivityResult(
        title: '活动已生成',
        message: '已主动生成「${activity.title}」，可以去活动页查看卡片效果。',
        activityCreated: true,
      );
    } catch (error) {
      if (!mounted) return;
      if (progressOpen) Navigator.of(context, rootNavigator: true).pop();
      setState(() => _generatingActivity = false);
      await _showActivityResult(title: '生成失败', message: _asMessage(error));
    }
  }

  Future<void> _showActivityResult({
    required String title,
    required String message,
    bool activityCreated = false,
  }) async {
    if (!mounted) return;
    final action = await showCupertinoDialog<String>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop('ok'),
              child: const Text('知道了'),
            ),
            if (activityCreated)
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.of(context).pop('open'),
                child: const Text('去活动页'),
              ),
          ],
        );
      },
    );
    if (!mounted || action != 'open') return;
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => OfflineActivityPage(
          api: widget.api,
          session: widget.session,
          hasLocation: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CupertinoPageScaffold(
      backgroundColor: Colors.transparent,
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: _motionController,
          builder: (context, _) {
            return Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _ProfileBackgroundPainter(
                    progress: _motionController.value,
                    isDark: isDark,
                  ),
                ),
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    18,
                    media.padding.top + 12,
                    18,
                    126,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 48,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: _AppNavCircleButton(
                                icon: CupertinoIcons.chevron_left,
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ),
                            Text(
                              'Admin',
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.text
                                    : const Color(0xFF12171B),
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _ProfileSectionV6(
                        title: '管理员工具',
                        trailing: '仅用于本地测试',
                        child: Column(
                          children: [
                            _ProfileSettingRowV6(
                              icon: CupertinoIcons.bolt_fill,
                              title: _generatingActivity
                                  ? '正在生成测试活动'
                                  : '测试主动生成活动',
                              subtitle: '为当前登录用户生成一张线下活动推荐卡',
                              accent: const Color(0xFF2D73FF),
                              enabled: !_generatingActivity,
                              onTap: _triggerActivityGeneration,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AdminProgressDialog extends StatelessWidget {
  const _AdminProgressDialog();

  @override
  Widget build(BuildContext context) {
    return const CupertinoAlertDialog(
      title: Text('正在生成活动'),
      content: Padding(
        padding: EdgeInsets.only(top: 14),
        child: Column(
          children: [
            CupertinoActivityIndicator(radius: 12),
            SizedBox(height: 12),
            Text('正在搜索附近活动并生成推荐卡...'),
          ],
        ),
      ),
    );
  }
}
