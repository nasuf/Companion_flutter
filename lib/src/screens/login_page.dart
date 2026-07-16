part of 'package:companion_flutter/main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onAuthenticated});

  final void Function(CompanionApi api, AuthSession session) onAuthenticated;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _apiBaseController = TextEditingController(text: defaultApiBaseUrl);
  final _wechatLoginService = WeChatLoginService();
  late final AnimationController _breathController;
  late final Animation<double> _breathAnimation;
  bool _wechatSubmitting = false;
  bool _acceptedTerms = false;
  String? _wechatError;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7600),
    )..repeat(reverse: true);
    _breathAnimation = CurvedAnimation(
      parent: _breathController,
      curve: Curves.easeInOutSine,
    );
  }

  @override
  void dispose() {
    _breathController.dispose();
    _apiBaseController.dispose();
    super.dispose();
  }

  void _showUnavailableLogin(String method) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('暂未开放'),
        content: Text('$method功能正在准备中，敬请期待。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _loginWithWechat() async {
    if (_wechatSubmitting) return;
    if (!_ensureTermsAccepted()) return;
    FocusScope.of(context).unfocus();
    final baseUrl = _apiBaseController.text.trim().replaceAll(
      RegExp(r'/$'),
      '',
    );
    if (baseUrl.isEmpty) return;

    setState(() {
      _wechatSubmitting = true;
      _wechatError = null;
    });
    try {
      final api = CompanionApi(baseUrl: baseUrl);
      // Device metadata lets the backend tag first-time logins with the
      // signup source (users.signup_* columns); best-effort, never blocking.
      final clientInfo = await ClientInfo.load();
      final loggedIn = await _wechatLoginService.login(
        api: api,
        platform: clientInfo.platform,
        osVersion: clientInfo.osVersion,
        appVersion: clientInfo.appVersion,
      );
      final session = await api.ensureConversation(loggedIn);
      if (!mounted) return;
      widget.onAuthenticated(api, session);
    } catch (error) {
      if (mounted) setState(() => _wechatError = _asMessage(error));
    } finally {
      if (mounted) setState(() => _wechatSubmitting = false);
    }
  }

  bool _ensureTermsAccepted() {
    if (_acceptedTerms) return true;
    setState(() => _wechatError = '请先阅读并同意《用户协议》和《隐私协议》');
    return false;
  }

  void _toggleTerms() {
    setState(() {
      _acceptedTerms = !_acceptedTerms;
      if (_acceptedTerms) _wechatError = null;
    });
  }

  void _openLegalDocument({required String title, required String assetPath}) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => _LegalDocumentPage(title: title, assetPath: assetPath),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const backgroundTop = Color(0xFFEDFEFC);
    const backgroundBottom = Color(0xFFDCFFF7);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: backgroundBottom,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: ColoredBox(
        color: backgroundBottom,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [backgroundTop, backgroundBottom],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: 390,
                    height: 844,
                    child: _LoginCanvas(
                      animation: _breathAnimation,
                      acceptedTerms: _acceptedTerms,
                      wechatLoading: _wechatSubmitting,
                      errorMessage: _wechatError,
                      onWechatTap: _loginWithWechat,
                      onUnavailableLogin: _showUnavailableLogin,
                      onTermsToggle: _toggleTerms,
                      onServiceAgreementTap: () => _openLegalDocument(
                        title: '用户协议',
                        assetPath: 'assets/legal/service_agreement.txt',
                      ),
                      onPrivacyAgreementTap: () => _openLegalDocument(
                        title: '隐私协议',
                        assetPath: 'assets/legal/privacy_policy.txt',
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LoginCanvas extends StatelessWidget {
  const _LoginCanvas({
    required this.animation,
    required this.acceptedTerms,
    required this.wechatLoading,
    required this.errorMessage,
    required this.onWechatTap,
    required this.onUnavailableLogin,
    required this.onTermsToggle,
    required this.onServiceAgreementTap,
    required this.onPrivacyAgreementTap,
  });

  final Animation<double> animation;
  final bool acceptedTerms;
  final bool wechatLoading;
  final String? errorMessage;
  final VoidCallback onWechatTap;
  final ValueChanged<String> onUnavailableLogin;
  final VoidCallback onTermsToggle;
  final VoidCallback onServiceAgreementTap;
  final VoidCallback onPrivacyAgreementTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 8,
          top: 12,
          width: 112,
          height: 112,
          child: _FloatingElement(
            animation: animation,
            xAmplitude: 3,
            yAmplitude: 5,
            scaleAmplitude: 0.018,
            child: const _MintOrb(color: Color(0xFFA8EDDE)),
          ),
        ),
        Positioned(
          left: 250,
          top: 704,
          width: 132,
          height: 132,
          child: _FloatingElement(
            animation: animation,
            xAmplitude: -4,
            yAmplitude: -5,
            scaleAmplitude: 0.014,
            child: const _MintOrb(color: Color(0xFF9DEAD9)),
          ),
        ),
        Positioned(
          left: 106,
          top: 159,
          width: 282,
          height: 214,
          child: _FloatingElement(
            animation: animation,
            xAmplitude: -2,
            yAmplitude: -5,
            scaleAmplitude: 0.016,
            child: Image.asset(
              'assets/login/login-planet.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        Positioned(
          left: 306,
          top: 62,
          width: 48,
          height: 48,
          child: _FloatingElement(
            animation: animation,
            yAmplitude: -4,
            rotation: 15 * math.pi / 180,
            rotationAmplitude: 3 * math.pi / 180,
            child: SvgPicture.asset('assets/login/star-large.svg'),
          ),
        ),
        Positioned(
          left: 40,
          top: 375,
          width: 36,
          height: 36,
          child: _FloatingElement(
            animation: animation,
            xAmplitude: 2,
            yAmplitude: 5,
            rotation: -15 * math.pi / 180,
            rotationAmplitude: -4 * math.pi / 180,
            child: SvgPicture.asset('assets/login/star-medium.svg'),
          ),
        ),
        Positioned(
          left: 299,
          top: 423,
          width: 24,
          height: 24,
          child: _FloatingElement(
            animation: animation,
            xAmplitude: -2,
            yAmplitude: -3,
            rotation: 11 * math.pi / 180,
            rotationAmplitude: 5 * math.pi / 180,
            child: SvgPicture.asset('assets/login/star-small.svg'),
          ),
        ),
        Positioned(
          left: 19,
          top: 140,
          child: _FloatingElement(
            animation: animation,
            xAmplitude: -2,
            yAmplitude: 3,
            child: const _HelloBubble(),
          ),
        ),
        Positioned(
          left: 35,
          top: 485,
          width: 320,
          height: 52,
          child: _WechatPrimaryButton(
            loading: wechatLoading,
            onTap: onWechatTap,
          ),
        ),
        Positioned(
          left: 35,
          top: 554,
          width: 320,
          child: _PrivacyAgreement(
            accepted: acceptedTerms,
            onToggle: onTermsToggle,
            onServiceAgreementTap: onServiceAgreementTap,
            onPrivacyAgreementTap: onPrivacyAgreementTap,
          ),
        ),
        if (errorMessage != null)
          Positioned(
            left: 35,
            top: 594,
            width: 320,
            child: Text(
              errorMessage!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFD84E4E),
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const Positioned(
          left: 35,
          top: 651,
          width: 320,
          child: _OtherLoginDivider(),
        ),
        Positioned(
          left: 75,
          top: 691,
          width: 240,
          child: _SecondaryLoginRow(
            onAppleTap: () => onUnavailableLogin('苹果登录'),
            onQqTap: () => onUnavailableLogin('QQ登录'),
            onPhoneTap: () => onUnavailableLogin('手机号登录'),
          ),
        ),
      ],
    );
  }
}

class _FloatingElement extends StatelessWidget {
  const _FloatingElement({
    required this.animation,
    required this.child,
    this.xAmplitude = 0,
    this.yAmplitude = 0,
    this.scaleAmplitude = 0,
    this.rotation = 0,
    this.rotationAmplitude = 0,
  });

  final Animation<double> animation;
  final Widget child;
  final double xAmplitude;
  final double yAmplitude;
  final double scaleAmplitude;
  final double rotation;
  final double rotationAmplitude;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: RepaintBoundary(child: child),
      builder: (context, child) {
        final phase = animation.value * 2 - 1;
        return Transform.translate(
          offset: Offset(xAmplitude * phase, yAmplitude * phase),
          child: Transform.rotate(
            angle: rotation + rotationAmplitude * phase,
            child: Transform.scale(
              scale: 1 + scaleAmplitude * phase,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _MintOrb extends StatelessWidget {
  const _MintOrb({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _HelloBubble extends StatelessWidget {
  const _HelloBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(3),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF06C893).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Text(
        'Hello',
        style: TextStyle(
          color: Color(0xFF111111),
          fontSize: 36,
          height: 1,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _WechatPrimaryButton extends StatelessWidget {
  const _WechatPrimaryButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF06C893).withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: CupertinoButton(
        minimumSize: Size.zero,
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(999),
        color: const Color(0xFF06C893),
        pressedOpacity: 0.82,
        onPressed: loading ? null : onTap,
        child: loading
            ? const CupertinoActivityIndicator(color: Colors.white)
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FaIcon(
                    FontAwesomeIcons.weixin,
                    color: Colors.white,
                    size: 23,
                  ),
                  SizedBox(width: 9),
                  Text(
                    '微信登录',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _PrivacyAgreement extends StatelessWidget {
  const _PrivacyAgreement({
    required this.accepted,
    required this.onToggle,
    required this.onServiceAgreementTap,
    required this.onPrivacyAgreementTap,
  });

  final bool accepted;
  final VoidCallback onToggle;
  final VoidCallback onServiceAgreementTap;
  final VoidCallback onPrivacyAgreementTap;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF06C893);
    const regularStyle = TextStyle(
      color: Color(0xFF111111),
      fontSize: 12,
      height: 1.35,
      fontWeight: FontWeight.w400,
    );
    const linkStyle = TextStyle(
      color: accent,
      fontSize: 12,
      height: 1.35,
      fontWeight: FontWeight.w600,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          checked: accepted,
          label: '同意用户协议和隐私协议',
          child: CupertinoButton(
            minimumSize: Size.zero,
            padding: EdgeInsets.zero,
            onPressed: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: accepted ? accent : Colors.white,
                border: Border.all(color: accent),
                borderRadius: BorderRadius.circular(4),
              ),
              child: accepted
                  ? const Icon(
                      CupertinoIcons.check_mark,
                      color: Colors.white,
                      size: 12,
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              GestureDetector(
                onTap: onToggle,
                child: const Text('我已阅读并同意', style: regularStyle),
              ),
              GestureDetector(
                onTap: onServiceAgreementTap,
                child: const Text('《用户协议》', style: linkStyle),
              ),
              const Text(' & ', style: regularStyle),
              GestureDetector(
                onTap: onPrivacyAgreementTap,
                child: const Text('《隐私协议》', style: linkStyle),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OtherLoginDivider extends StatelessWidget {
  const _OtherLoginDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: Color(0xFFD5DBDA), height: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '其他登录方式',
            style: TextStyle(
              color: Color(0xFF8D908F),
              fontSize: 12,
              height: 1.3,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        Expanded(child: Divider(color: Color(0xFFD5DBDA), height: 1)),
      ],
    );
  }
}

class _SecondaryLoginRow extends StatelessWidget {
  const _SecondaryLoginRow({
    required this.onAppleTap,
    required this.onQqTap,
    required this.onPhoneTap,
  });

  final VoidCallback onAppleTap;
  final VoidCallback onQqTap;
  final VoidCallback onPhoneTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _SecondaryLoginButton(
          label: '苹果登录',
          onTap: onAppleTap,
          icon: const FaIcon(
            FontAwesomeIcons.apple,
            color: Colors.white,
            size: 25,
          ),
        ),
        _SecondaryLoginButton(
          label: 'QQ登录',
          onTap: onQqTap,
          icon: const FaIcon(
            FontAwesomeIcons.qq,
            color: Colors.white,
            size: 23,
          ),
        ),
        _SecondaryLoginButton(
          label: '手机号登录',
          onTap: onPhoneTap,
          icon: const Icon(
            CupertinoIcons.device_phone_portrait,
            color: Colors.white,
            size: 24,
          ),
        ),
      ],
    );
  }
}

class _SecondaryLoginButton extends StatelessWidget {
  const _SecondaryLoginButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: CupertinoButton(
        minimumSize: Size.zero,
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0xFF63DEC5),
            shape: BoxShape.circle,
          ),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(child: ExcludeSemantics(child: icon)),
          ),
        ),
      ),
    );
  }
}
