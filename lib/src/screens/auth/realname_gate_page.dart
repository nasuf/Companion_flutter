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
  static const _accent = Color(0xFF06C893);
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
    final step = _step;
    final (title, subtitle) = switch (step) {
      'phone' => ('绑定手机号', '根据国家相关规定，使用前需要完成手机号验证'),
      'id_card' => ('实名认证', '本服务仅面向年满18周岁的用户，请填写本人身份信息'),
      _ => ('暂时无法使用', ''),
    };
    return Scaffold(
      backgroundColor: const Color(0xFFF4FBF9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _busy ? null : widget.onLogout,
            child: const Text(
              '退出登录',
              style: TextStyle(color: Color(0xFF7B8582)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF7B8582),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              if (step == 'phone') ..._phoneForm(),
              if (step == 'id_card') ..._idForm(),
              if (step == 'minor_blocked') _minorNotice(),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFE5484D),
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _phoneForm() => [
    _CredentialField(
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
    _CredentialField(
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
        child: Text(_countdown > 0 ? '${_countdown}s' : '获取验证码'),
      ),
    ),
    const SizedBox(height: 24),
    _primaryButton('验证并绑定', _bindPhone),
  ];

  List<Widget> _idForm() => [
    _CredentialField(
      controller: _nameController,
      label: '真实姓名',
      icon: CupertinoIcons.person,
      inputFormatters: [LengthLimitingTextInputFormatter(20)],
    ),
    const SizedBox(height: 12),
    _CredentialField(
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
    const SizedBox(height: 16),
    // 身份证号属于敏感个人信息，必须单独同意，不能和登录时的协议合并勾选。
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          checked: _consent,
          label: '同意收集身份信息',
          child: Checkbox(
            value: _consent,
            activeColor: _accent,
            onChanged: (v) => setState(() => _consent = v ?? false),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _consent = !_consent),
            child: Wrap(
              children: [
                const Text(
                  '我同意提供姓名和身份证号，仅用于实名认证和年龄核验。'
                  '信息将交由腾讯云核验，我们不保存身份证号原文。详见',
                  style: TextStyle(
                    color: Color(0xFF4A5452),
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
                GestureDetector(
                  onTap: _openPrivacy,
                  child: const Text(
                    '《隐私协议》',
                    style: TextStyle(
                      color: _accent,
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
    _primaryButton('提交认证', _verifyId),
  ];

  Widget _minorNotice() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Icon(
        CupertinoIcons.lock_shield,
        size: 56,
        color: Color(0xFF9AA5A2),
      ),
      const SizedBox(height: 16),
      const Text(
        '根据《人工智能拟人化互动服务管理暂行办法》，本服务不向未满18周岁的用户提供。\n\n'
        '如认证信息有误，请通过「意见反馈」或客服联系我们处理。',
        style: TextStyle(color: Color(0xFF4A5452), fontSize: 14, height: 1.7),
      ),
      const SizedBox(height: 28),
      _primaryButton('退出登录', widget.onLogout),
    ],
  );

  Widget _primaryButton(String label, VoidCallback onPressed) => SizedBox(
    height: 50,
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: _accent,
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
