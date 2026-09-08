part of 'package:companion_flutter/main.dart';

// ---------------------------------------------------------------------------
// Admin · 遗言短信测试
// ---------------------------------------------------------------------------

extension _AdminLastWillSmsApi on CompanionApi {
  Future<_LastWillSmsTestResult> sendAdminLastWillSmsTest({
    required String phone,
  }) async {
    final json =
        await _adminHttpRequest(
              this,
              'POST',
              '/admin-api/last-wills/sms-test',
              body: {'phone': phone.trim()},
            )
            as Map<String, dynamic>;
    return _LastWillSmsTestResult.fromJson(json);
  }
}

class _LastWillSmsTestResult {
  const _LastWillSmsTestResult({required this.phoneTail, required this.mock});

  final String phoneTail;
  final bool mock;

  factory _LastWillSmsTestResult.fromJson(Map<String, dynamic> json) {
    return _LastWillSmsTestResult(
      phoneTail: json['phone_tail']?.toString() ?? '',
      mock: json['mock'] == true,
    );
  }
}

class AdminLastWillSmsTestPage extends StatefulWidget {
  const AdminLastWillSmsTestPage({
    super.key,
    required this.api,
    required this.session,
  });

  final CompanionApi api;
  final AuthSession session;

  @override
  State<AdminLastWillSmsTestPage> createState() =>
      _AdminLastWillSmsTestPageState();
}

class _AdminLastWillSmsTestPageState extends State<AdminLastWillSmsTestPage> {
  final _phoneController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      await _showResult(title: '请输入手机号', message: '请填写要接收测试短信的手机号码。');
      return;
    }

    setState(() => _sending = true);
    widget.api.authToken = widget.session.token;
    try {
      final result = await widget.api.sendAdminLastWillSmsTest(phone: phone);
      if (!mounted) return;
      final mode = result.mock ? '（Mock 模式，未实际发送）' : '';
      await _showResult(
        title: '发送成功',
        message: '已向尾号 ${result.phoneTail} 的号码发送遗言测试短信$mode。',
      );
    } catch (error) {
      if (!mounted) return;
      await _showResult(title: '发送失败', message: _asMessage(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _showResult({
    required String title,
    required String message,
  }) async {
    await showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('好的'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _AdminScaffold(
      title: '遗言短信测试',
      subtitle: '向指定手机号发送一条测试通知',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          Text(
            '使用生产环境的遗言短信模板，填入测试参数（联系人=测试联系人，失联天数=30，留言=测试文案）。',
            style: TextStyle(
              color: isDark ? const Color(0xB3EBF2EE) : const Color(0xFF5A6570),
              fontSize: 14,
              height: 1.45,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '手机号码',
            style: TextStyle(
              color: isDark ? const Color(0xFFEBF2EE) : const Color(0xFF12171B),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.08),
              ),
            ),
            child: CupertinoTextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              placeholder: '请输入 11 位手机号',
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: const BoxDecoration(),
              style: _adminInputStyle(context),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              onPressed: _sending ? null : _send,
              child: _sending
                  ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                  : const Text('发送测试短信'),
            ),
          ),
        ],
      ),
    );
  }
}
