part of 'package:companion_flutter/main.dart';

class NoAgentPage extends StatefulWidget {
  const NoAgentPage({
    super.key,
    required this.api,
    required this.session,
    required this.onSessionChanged,
  });

  final CompanionApi api;
  final AuthSession session;
  final ValueChanged<AuthSession> onSessionChanged;

  @override
  State<NoAgentPage> createState() => _NoAgentPageState();
}

class _NoAgentPageState extends State<NoAgentPage> {
  bool _openedCreatePage = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _openedCreatePage || widget.session.hasAgent) return;
      _openedCreatePage = true;
      _openCreatePage(context);
    });
  }

  void _openCreatePage(BuildContext context) {
    Navigator.of(context).push(
      CompanionPageRoute<void>(
        builder: (_) => AgentCreatePage(
          api: widget.api,
          session: widget.session,
          onCreated: widget.onSessionChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '聊天',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.person_2_square_stack,
                    color: AppColors.muted,
                    size: 56,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.session.hasAgent ? '还没有可用会话' : '寻找你的AI伙伴',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '根据TA的性别和灵魂倾向，我们会为你匹配最合适的伴生AI伙伴',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, height: 1.45),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: () => _openCreatePage(context),
                    child: const Text('点击匹配寻找'),
                  ),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
