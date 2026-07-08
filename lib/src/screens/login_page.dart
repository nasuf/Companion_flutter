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
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();
  final _wechatLoginService = WeChatLoginService();
  late final AnimationController _breathController;
  bool _wechatSubmitting = false;
  String? _wechatError;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathController.dispose();
    _apiBaseController.dispose();
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _openBackendLogin() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x33101824),
      builder: (sheetContext) {
        final bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: _BackendLoginSheet(
            apiBaseController: _apiBaseController,
            accountController: _accountController,
            passwordController: _passwordController,
            onAuthenticated: widget.onAuthenticated,
          ),
        );
      },
    );
  }

  Future<void> _loginWithWechat() async {
    if (_wechatSubmitting) return;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: AnimatedBuilder(
        animation: _breathController,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_breathController.value);
          return Stack(
            children: [
              _LoginBackdrop(progress: t),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxHeight < 620;
                    final heroHeight = compact ? 292.0 : 360.0;
                    final topPadding = compact ? 24.0 : 74.0;
                    final brandTop = compact ? 6.0 : 24.0;
                    final titleTop = compact ? 126.0 : 180.0;
                    final orbTop = compact ? 150.0 : 196.0;
                    return Padding(
                      padding: EdgeInsets.fromLTRB(30, topPadding, 30, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: heroHeight,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned(
                                  left: 0,
                                  top: brandTop,
                                  child: _BrandLockup(),
                                ),
                                Positioned(
                                  left: 0,
                                  top: titleTop,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '从一句话开始',
                                        style: TextStyle(
                                          color: AppColors.text,
                                          fontSize: 43,
                                          height: 1.02,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0,
                                        ),
                                      ),
                                      SizedBox(height: 18),
                                      Text(
                                        '在没有终点的路上，\n我们慢慢走，慢慢说。',
                                        style: TextStyle(
                                          color: Color(0x8A181F26),
                                          fontSize: 17,
                                          height: 1.66,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  right: -18 + 10 * t,
                                  top: orbTop + 14 * (0.5 - t),
                                  child: _BreathingGlassOrb(progress: t),
                                ),
                              ],
                            ),
                          ),
                          if (compact)
                            const SizedBox(height: 12)
                          else
                            const Spacer(),
                          _PhoneLoginButton(onTap: _openBackendLogin),
                          const SizedBox(height: 18),
                          const _LoginDivider(),
                          const SizedBox(height: 22),
                          _SocialLoginRow(
                            onAppleTap: () {
                              Navigator.of(context).push(
                                CupertinoPageRoute<void>(
                                  builder: (_) => const AgentCreatePage(),
                                ),
                              );
                            },
                            onWechatTap: _loginWithWechat,
                            wechatLoading: _wechatSubmitting,
                          ),
                          if (_wechatError != null) ...[
                            SizedBox(height: compact ? 8 : 12),
                            Text(
                              _wechatError!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFFD95B5B),
                                fontSize: compact ? 12 : 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          SizedBox(height: compact ? 14 : 26),
                          const _PrivacyLine(),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LoginBackdrop extends StatelessWidget {
  const _LoginBackdrop({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.page,
            Color.lerp(colors.page, colors.surfaceMuted, 0.42)!,
            Color.lerp(colors.page, colors.accentSoft, 0.24)!,
          ],
          stops: [0, 0.52, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -150 + 16 * progress,
            top: 64 + 22 * progress,
            child: _AuraBlob(
              width: 360,
              height: 420,
              opacity: 0.58 + 0.20 * progress,
              colors: const [Color(0x4D58A8FF), Color(0x2918C6C0)],
            ),
          ),
          Positioned(
            left: -190 - 14 * progress,
            bottom: 20 + 18 * progress,
            child: _AuraBlob(
              width: 420,
              height: 360,
              opacity: 0.50 + 0.12 * (1 - progress),
              colors: const [Color(0x33FFD6B8), Color(0x1F18C6C0)],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuraBlob extends StatelessWidget {
  const _AuraBlob({
    required this.width,
    required this.height,
    required this.opacity,
    required this.colors,
  });

  final double width;
  final double height;
  final double opacity;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: RadialGradient(
              center: const Alignment(-0.15, -0.52),
              radius: 0.72,
              colors: [colors.first, Colors.transparent],
            ),
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: RadialGradient(
              center: const Alignment(0.42, 0.40),
              radius: 0.78,
              colors: [colors.last, Colors.transparent],
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentDeep.withValues(alpha: 0.16),
                blurRadius: 48,
                offset: const Offset(0, 18),
              ),
              const BoxShadow(color: Colors.white, offset: Offset(0, 1)),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset('assets/prototype/logo.png', fit: BoxFit.cover),
        ),
        const SizedBox(width: 22),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '「伴生」',
              style: TextStyle(
                color: AppColors.accentDeep,
                fontSize: 21,
                height: 1.05,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Ban Sheng',
              style: TextStyle(
                color: Color(0x7A181F26),
                fontSize: 17,
                height: 1.2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BreathingGlassOrb extends StatelessWidget {
  const _BreathingGlassOrb({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final scale = 0.98 + 0.05 * progress;
    return Transform.rotate(
      angle: (7.5 + 2.5 * progress) * math.pi / 180,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: 168,
          height: 144,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xB718D3C2), Color(0xE01F6FFF)],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.22),
                blurRadius: 42,
                offset: const Offset(0, 24),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: 28,
                top: 18,
                child: Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.26),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.26),
                        blurRadius: 28,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: Center(
                  child: Container(
                    width: 110,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.46),
                      ),
                    ),
                  ),
                ),
              ),
              const _OrbDot(left: 34, top: 34),
              const _OrbDot(right: 26, top: 58),
              const _OrbDot(left: 68, bottom: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrbDot extends StatelessWidget {
  const _OrbDot({this.left, this.top, this.right, this.bottom});

  final double? left;
  final double? top;
  final double? right;
  final double? bottom;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      child: Container(
        width: 13,
        height: 13,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xDDE8FFFF),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.36),
              blurRadius: 12,
            ),
          ],
        ),
      ),
    );
  }
}

class _PhoneLoginButton extends StatelessWidget {
  const _PhoneLoginButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [AppColors.accentDeep, AppColors.accentCyan],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentDeep.withValues(alpha: 0.24),
              blurRadius: 46,
              offset: const Offset(0, 18),
            ),
            BoxShadow(
              color: AppColors.accentCyan.withValues(alpha: 0.12),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.device_phone_portrait, size: 23),
              SizedBox(width: 16),
              Text(
                '手机号登录',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginDivider extends StatelessWidget {
  const _LoginDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: Divider(color: Color(0x1A181F26), height: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            'or',
            style: TextStyle(
              color: Color(0x66181F26),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(child: Divider(color: Color(0x1A181F26), height: 1)),
      ],
    );
  }
}

class _SocialLoginRow extends StatelessWidget {
  const _SocialLoginRow({
    required this.onAppleTap,
    required this.onWechatTap,
    required this.wechatLoading,
  });

  final VoidCallback onAppleTap;
  final VoidCallback onWechatTap;
  final bool wechatLoading;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SocialButton.apple(onTap: onAppleTap),
        const SizedBox(width: 20),
        const _SocialButton.douyin(),
        const SizedBox(width: 20),
        _SocialButton.wechat(onTap: onWechatTap, loading: wechatLoading),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton.apple({this.onTap})
    : color = const Color(0xFF0D1117),
      icon = null,
      text = '\uF8FF',
      wechatIcon = false,
      loading = false;

  const _SocialButton.douyin()
    : color = const Color(0xFF1B2028),
      icon = CupertinoIcons.music_note_2,
      text = null,
      wechatIcon = false,
      loading = false,
      onTap = null;

  const _SocialButton.wechat({required this.onTap, this.loading = false})
    : color = const Color(0xFF14BA1A),
      icon = null,
      text = null,
      wechatIcon = true;

  final Color color;
  final IconData? icon;
  final String? text;
  final bool wechatIcon;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      onPressed: loading ? null : (onTap ?? () {}),
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: Colors.white.withValues(alpha: 0.74)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF233040).withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Center(
          child: loading
              ? const CupertinoActivityIndicator(color: Colors.white)
              : text != null
              ? Text(
                  text!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : wechatIcon
              ? Semantics(
                  label: '微信',
                  child: const FaIcon(
                    FontAwesomeIcons.weixin,
                    color: Colors.white,
                    size: 27,
                  ),
                )
              : Icon(icon, color: Colors.white, size: 25),
        ),
      ),
    );
  }
}

class _PrivacyLine extends StatelessWidget {
  const _PrivacyLine();

  @override
  Widget build(BuildContext context) {
    return const Text.rich(
      TextSpan(
        text: '登录即表示同意 ',
        children: [
          TextSpan(
            text: '隐私协议',
            style: TextStyle(
              color: Color(0x99181F26),
              fontWeight: FontWeight.w800,
              decoration: TextDecoration.underline,
            ),
          ),
          TextSpan(text: ' · 数据可删除'),
        ],
      ),
      textAlign: TextAlign.center,
      style: TextStyle(color: Color(0x75181F26), fontSize: 12),
    );
  }
}

enum _BackendAuthMode { login, register }

class _AuthModeSwitch extends StatelessWidget {
  const _AuthModeSwitch({required this.mode, required this.onChanged});

  final _BackendAuthMode mode;
  final ValueChanged<_BackendAuthMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.hairline),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / 2;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                left: mode == _BackendAuthMode.login ? 0 : segmentWidth,
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF315B88).withValues(alpha: 0.10),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  _AuthModeButton(
                    label: '登录',
                    selected: mode == _BackendAuthMode.login,
                    onTap: () => onChanged(_BackendAuthMode.login),
                  ),
                  _AuthModeButton(
                    label: '注册',
                    selected: mode == _BackendAuthMode.register,
                    onTap: () => onChanged(_BackendAuthMode.register),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AuthModeButton extends StatelessWidget {
  const _AuthModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        borderRadius: BorderRadius.circular(999),
        onPressed: onTap,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.text : AppColors.muted,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _BackendLoginSheet extends StatefulWidget {
  const _BackendLoginSheet({
    required this.apiBaseController,
    required this.accountController,
    required this.passwordController,
    required this.onAuthenticated,
  });

  final TextEditingController apiBaseController;
  final TextEditingController accountController;
  final TextEditingController passwordController;
  final void Function(CompanionApi api, AuthSession session) onAuthenticated;

  @override
  State<_BackendLoginSheet> createState() => _BackendLoginSheetState();
}

class _BackendLoginSheetState extends State<_BackendLoginSheet> {
  final _passwordFocus = FocusNode();
  final _confirmPasswordController = TextEditingController();
  final _confirmPasswordFocus = FocusNode();
  var _mode = _BackendAuthMode.login;
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _confirmPasswordController.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final baseUrl = widget.apiBaseController.text.trim().replaceAll(
      RegExp(r'/$'),
      '',
    );
    final account = widget.accountController.text.trim();
    final password = widget.passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    if (baseUrl.isEmpty || account.isEmpty || password.isEmpty) return;
    if (_mode == _BackendAuthMode.register) {
      if (account.length < 2 || account.length > 30) {
        setState(() => _error = '账号需为 2-30 个字符。');
        return;
      }
      if (password.length < 6) {
        setState(() => _error = '密码至少需要 6 个字符。');
        return;
      }
      if (password != confirmPassword) {
        setState(() => _error = '两次输入的密码不一致。');
        return;
      }
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final api = CompanionApi(baseUrl: baseUrl);
      AuthSession loggedIn;
      if (_mode == _BackendAuthMode.register) {
        final clientInfo = await ClientInfo.load();
        loggedIn = await api.register(
          account,
          password,
          platform: clientInfo.platform,
          osVersion: clientInfo.osVersion,
          appVersion: clientInfo.appVersion,
        );
      } else {
        loggedIn = await api.login(account, password);
      }
      final session = await api.ensureConversation(loggedIn);
      if (!mounted) return;
      final onAuthenticated = widget.onAuthenticated;
      Navigator.of(context).pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onAuthenticated(api, session);
      });
    } catch (error) {
      if (mounted) setState(() => _error = _asMessage(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0x22181F26),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '连接 Companion_server',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AuthModeSwitch(
                    mode: _mode,
                    onChanged: (mode) {
                      if (_submitting || mode == _mode) return;
                      setState(() {
                        _mode = mode;
                        _error = null;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _LoginField(
                    controller: widget.apiBaseController,
                    icon: CupertinoIcons.link,
                    label: '后端地址',
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  _LoginField(
                    controller: widget.accountController,
                    icon: CupertinoIcons.person,
                    label: '账号',
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _passwordFocus.requestFocus(),
                  ),
                  const SizedBox(height: 12),
                  _LoginField(
                    controller: widget.passwordController,
                    focusNode: _passwordFocus,
                    icon: CupertinoIcons.lock,
                    label: '密码',
                    obscureText: _obscure,
                    textInputAction: _mode == _BackendAuthMode.register
                        ? TextInputAction.next
                        : TextInputAction.done,
                    onSubmitted: (_) {
                      if (_mode == _BackendAuthMode.register) {
                        _confirmPasswordFocus.requestFocus();
                      } else {
                        _submit();
                      }
                    },
                    trailing: IconButton(
                      tooltip: _obscure ? '显示密码' : '隐藏密码',
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? CupertinoIcons.eye
                            : CupertinoIcons.eye_slash,
                        size: 20,
                      ),
                    ),
                  ),
                  if (_mode == _BackendAuthMode.register) ...[
                    const SizedBox(height: 12),
                    _LoginField(
                      controller: _confirmPasswordController,
                      focusNode: _confirmPasswordFocus,
                      icon: CupertinoIcons.checkmark_shield,
                      label: '确认密码',
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                    ),
                  ],
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _error == null
                        ? const SizedBox(height: 26)
                        : Padding(
                            padding: const EdgeInsets.only(top: 10, bottom: 6),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: Color(0xFFE24A4A),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                  ),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFAFCFFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      _submitting
                          ? (_mode == _BackendAuthMode.register
                                ? '注册中...'
                                : '登录中...')
                          : (_mode == _BackendAuthMode.register
                                ? '注册并继续'
                                : '登录'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginField extends StatelessWidget {
  const _LoginField({
    required this.controller,
    required this.icon,
    required this.label,
    this.focusNode,
    this.obscureText = false,
    this.textInputAction,
    this.onSubmitted,
    this.trailing,
  });

  final TextEditingController controller;
  final IconData icon;
  final String label;
  final FocusNode? focusNode;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 20, color: AppColors.muted),
          suffixIcon: trailing,
          labelText: label,
          labelStyle: TextStyle(color: AppColors.muted),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
