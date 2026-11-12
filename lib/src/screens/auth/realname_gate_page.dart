part of 'package:companion_flutter/main.dart';

/// 实名门槛（服务端 REALNAME_MODE）：登录后还差步骤时停在这里，完成才进主界面。
///
/// 步骤由服务端按顺序给出：`phone` 绑定手机号 → `id_card` 姓名 + 身份证号核验；
/// `minor_blocked` 是未满 18 周岁的锁定页，只能退出登录。服务端各聊天入口同样会
/// 拦截，这里只负责引导，不是唯一防线。
class RealnameGatePage extends StatefulWidget {
  const RealnameGatePage({
    super.key,
    required this.api,
    required this.session,
    required this.onSessionChanged,
    required this.onLogout,
  });

  final CompanionApi api;
  final AuthSession session;
  final ValueChanged<AuthSession> onSessionChanged;
  final VoidCallback onLogout;

  @override
  State<RealnameGatePage> createState() => _RealnameGatePageState();
}

class _RealnameGatePageState extends State<RealnameGatePage> {
  static final _phonePattern = RegExp(r'^1[3-9]\d{9}$');

  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  Timer? _countdownTimer;
  int _countdown = 0;
  bool _busy = false;
  bool _consent = false;
  String? _error;

  String get _step => widget.session.realnameRequired.first;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_refresh);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _phoneController.removeListener(_refresh);
    _phoneController.dispose();
    _codeController.dispose();
    _nameController.dispose();
    _idController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  bool get _phoneValid => _phonePattern.hasMatch(_phoneController.text.trim());

  Future<void> _reloadSession() async {
    final me = await widget.api.getMe(widget.session.token);
    final session = await widget.api.ensureConversation(me);
    if (mounted) widget.onSessionChanged(session);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = _asMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _sendCode() {
    if (!_phoneValid || _countdown > 0) return;
    // 和登录页一致：发出请求就开始倒计时，失败的响应不代表短信没发出去。
    setState(() => _countdown = 30);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() {
        _countdown -= 1;
        if (_countdown <= 0) timer.cancel();
      });
    });
    unawaited(_run(() => widget.api.smsSend(_phoneController.text.trim())));
  }

  void _bindPhone() {
    final code = _codeController.text.trim();
    if (!_phoneValid) return setState(() => _error = '请输入正确的手机号');
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      return setState(() => _error = '请输入 6 位验证码');
    }
    unawaited(
      _run(() async {
        await widget.api.bindPhone(_phoneController.text.trim(), code);
        await _reloadSession();
      }),
    );
  }

  void _verifyId() {
    if (!_consent) return setState(() => _error = '请先阅读并同意收集身份信息');
    final name = _nameController.text.trim();
    final id = _idController.text.trim().toUpperCase();
    if (name.length < 2) return setState(() => _error = '请填写身份证上的姓名');
    if (!RegExp(r'^\d{17}[\dX]$').hasMatch(id)) {
      return setState(() => _error = '请输入 18 位身份证号');
    }
    unawaited(
      _run(() async {
        await widget.api.verifyRealname(
          name: name,
          idNumber: id,
          consent: _consent,
        );
        await _reloadSession();
      }),
    );
  }

  void _openPrivacy() {
    Navigator.of(context).push(
      CompanionPageRoute<void>(
        builder: (_) => const _LegalDocumentPage(
          title: '隐私协议',
          assetPath: 'assets/legal/privacy_policy.txt',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final step = _step;
    final (icon, title, subtitle) = switch (step) {
      'phone' => (
        CupertinoIcons.device_phone_portrait,
        '绑定手机号',
        '根据国家相关规定，使用前需要完成手机号验证',
      ),
      'id_card' => (
        CupertinoIcons.person_crop_rectangle,
        '实名认证',
        '本服务仅面向年满18周岁的用户，请填写本人身份信息',
      ),
      _ => (CupertinoIcons.lock_shield, '暂时无法使用', ''),
    };
    return Scaffold(
      backgroundColor: c.page,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          if (step != 'minor_blocked')
            TextButton(
              onPressed: _busy ? null : widget.onLogout,
              child: Text('退出登录', style: TextStyle(color: c.muted)),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StepHeader(
                icon: icon,
                title: title,
                subtitle: subtitle,
                step: step,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: c.hairline),
                  boxShadow: [
                    BoxShadow(
                      color: c.shadow,
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (step == 'phone') ..._phoneForm(c),
                    if (step == 'id_card') ..._idForm(c),
                    if (step == 'minor_blocked') _minorNotice(c),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      CupertinoIcons.exclamationmark_circle,
                      size: 16,
                      color: c.danger,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: c.danger, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _phoneForm(AppPalette c) => [
    _RealnameField(
      controller: _phoneController,
      label: '手机号',
      icon: CupertinoIcons.device_phone_portrait,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(11),
      ],
    ),
    const SizedBox(height: 12),
    _RealnameField(
      controller: _codeController,
      label: '验证码',
      icon: CupertinoIcons.shield,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      onSubmitted: (_) => _bindPhone(),
      trailing: TextButton(
        onPressed: _phoneValid && _countdown == 0 ? _sendCode : null,
        style: TextButton.styleFrom(foregroundColor: c.accent),
        child: Text(_countdown > 0 ? '${_countdown}s' : '获取验证码'),
      ),
    ),
    const SizedBox(height: 22),
    _primaryButton(c, '验证并绑定', _bindPhone),
  ];

  List<Widget> _idForm(AppPalette c) => [
    _RealnameField(
      controller: _nameController,
      label: '真实姓名',
      icon: CupertinoIcons.person,
      inputFormatters: [LengthLimitingTextInputFormatter(20)],
    ),
    const SizedBox(height: 12),
    _RealnameField(
      controller: _idController,
      label: '身份证号',
      icon: CupertinoIcons.creditcard,
      keyboardType: TextInputType.visiblePassword,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9xX]')),
        LengthLimitingTextInputFormatter(18),
      ],
      onSubmitted: (_) => _verifyId(),
    ),
    const SizedBox(height: 14),
    // 身份证号属于敏感个人信息，必须单独同意，不能和登录时的协议合并勾选。
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          checked: _consent,
          label: '同意收集身份信息',
          child: SizedBox(
            width: 28,
            height: 28,
            child: Checkbox(
              value: _consent,
              activeColor: c.accent,
              side: BorderSide(color: c.muted),
              onChanged: (v) => setState(() => _consent = v ?? false),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _consent = !_consent),
            child: Wrap(
              children: [
                Text(
                  '我同意提供姓名和身份证号，用于实名认证、年龄核验及平台内部的用户统计分析，'
                  '不向第三方提供。核验由腾讯云完成，身份信息加密保存，注销账号时删除。详见',
                  style: TextStyle(color: c.muted, fontSize: 12, height: 1.6),
                ),
                GestureDetector(
                  onTap: _openPrivacy,
                  child: Text(
                    '《隐私协议》',
                    style: TextStyle(
                      color: c.accent,
                      fontSize: 12,
                      height: 1.6,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
    const SizedBox(height: 20),
    _primaryButton(c, '提交认证', _verifyId),
  ];

  Widget _minorNotice(AppPalette c) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        '根据《人工智能拟人化互动服务管理暂行办法》，本服务不向未满18周岁的用户提供。',
        style: TextStyle(color: c.text, fontSize: 15, height: 1.7),
      ),
      const SizedBox(height: 10),
      Text(
        '如认证信息有误，请通过「意见反馈」或客服联系我们处理。',
        style: TextStyle(color: c.muted, fontSize: 13, height: 1.6),
      ),
      const SizedBox(height: 22),
      _primaryButton(c, '退出登录', widget.onLogout),
    ],
  );

  Widget _primaryButton(
    AppPalette c,
    String label,
    VoidCallback onPressed,
  ) => SizedBox(
    height: 50,
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: c.accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: c.accent.withValues(alpha: 0.45),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      ),
      onPressed: _busy ? null : onPressed,
      child: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
    ),
  );
}

/// 顶部：图标 + 标题 + 说明 + 步骤进度（手机号 → 实名）。
class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.step,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String step;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final blocked = step == 'minor_blocked';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: blocked ? c.surfaceMuted : c.accentSoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, size: 26, color: blocked ? c.muted : c.accent),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: TextStyle(
            color: c.text,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(color: c.muted, fontSize: 14, height: 1.5),
          ),
        ],
        if (!blocked) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              _StepDot(
                label: '手机号',
                active: step == 'phone',
                done: step != 'phone',
              ),
              Expanded(
                child: Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: c.hairline,
                ),
              ),
              _StepDot(label: '实名认证', active: step == 'id_card', done: false),
            ],
          ),
        ],
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.label,
    required this.active,
    required this.done,
  });

  final String label;
  final bool active;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final on = active || done;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: on ? c.accent : c.surfaceMuted,
            shape: BoxShape.circle,
          ),
          child: done
              ? const Icon(
                  CupertinoIcons.check_mark,
                  size: 11,
                  color: Colors.white,
                )
              : null,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: on ? c.text : c.muted,
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

/// 跟随 App 主题的输入框（登录页的输入框是固定浅色，不能复用）。
class _RealnameField extends StatelessWidget {
  const _RealnameField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.inputFormatters,
    this.onSubmitted,
    this.trailing,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onSubmitted: onSubmitted,
      autocorrect: false,
      enableSuggestions: false,
      style: TextStyle(color: c.text, fontSize: 15),
      cursorColor: c.accent,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: c.muted),
        floatingLabelStyle: TextStyle(color: c.accent),
        prefixIcon: Icon(icon, color: c.muted, size: 20),
        suffixIcon: trailing,
        filled: true,
        fillColor: c.input,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        enabledBorder: border(c.hairline),
        focusedBorder: border(c.accent, 1.5),
      ),
    );
  }
}
