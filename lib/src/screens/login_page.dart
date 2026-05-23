part of 'package:companion_flutter/main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onAuthenticated});

  final void Function(CompanionApi api, AuthSession session) onAuthenticated;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _apiBaseController = TextEditingController(text: defaultApiBaseUrl);
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _apiBaseController.dispose();
    _accountController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final baseUrl = _apiBaseController.text.trim().replaceAll(
      RegExp(r'/$'),
      '',
    );
    final account = _accountController.text.trim();
    final password = _passwordController.text;
    if (baseUrl.isEmpty || account.isEmpty || password.isEmpty) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final api = CompanionApi(baseUrl: baseUrl);
      final loggedIn = await api.login(account, password);
      final session = await api.ensureConversation(loggedIn);
      if (!mounted) return;
      widget.onAuthenticated(api, session);
    } catch (error) {
      setState(() => _error = _asMessage(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
            children: [
              const SizedBox(height: 12),
              const _BrandLockup(),
              const SizedBox(height: 46),
              Text(
                '从一句话开始',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '登录后连接 Companion_server，加载真实聊天记录并进入实时对话。',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 16,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 34),
              _LoginField(
                controller: _apiBaseController,
                icon: CupertinoIcons.link,
                label: '后端地址',
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              _LoginField(
                controller: _accountController,
                icon: CupertinoIcons.person,
                label: '账号',
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _passwordFocus.requestFocus(),
              ),
              const SizedBox(height: 14),
              _LoginField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                icon: CupertinoIcons.lock,
                label: '密码',
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                trailing: IconButton(
                  tooltip: _obscure ? '显示密码' : '隐藏密码',
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                    size: 20,
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _error == null
                    ? const SizedBox(height: 28)
                    : Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 8),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFE24A4A),
                            fontSize: 13,
                          ),
                        ),
                      ),
              ),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: AppColors.wechatGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFA8DDBF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _submitting ? '登录中...' : '登录',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Center(
                child: Text(
                  '默认地址 iOS/macOS: localhost · Android: 10.0.2.2',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
            ],
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Image.asset('assets/prototype/logo.png'),
        ),
        const SizedBox(width: 14),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '「伴生」',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 3),
            Text(
              'Ban Sheng',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
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
          labelStyle: const TextStyle(color: AppColors.muted),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
