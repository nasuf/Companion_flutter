part of 'package:companion_flutter/main.dart';

/// Generate and publish immediately, through the user's complete activity flow.
class _TakeoverActivitySheet extends StatefulWidget {
  const _TakeoverActivitySheet({required this.api, required this.takeoverId});

  final CompanionApi api;
  final String takeoverId;

  @override
  State<_TakeoverActivitySheet> createState() => _TakeoverActivitySheetState();
}

class _TakeoverActivitySheetState extends State<_TakeoverActivitySheet> {
  bool _generating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_generate());
  }

  Future<void> _generate() async {
    if (_generating) return;
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      await widget.api.createTakeoverActivityRecommendation(widget.takeoverId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _error = _asMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_generating,
      child: SafeArea(
        top: false,
        child: Material(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '活动推荐',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 20),
                if (_generating) ...[
                  const CupertinoActivityIndicator(),
                  const SizedBox(height: 14),
                  const Text('正在为用户生成并发送活动…'),
                  const SizedBox(height: 8),
                  Text(
                    '可能需要一点时间，请稍候',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ] else ...[
                  Text(_error ?? '暂时无法生成活动', textAlign: TextAlign.center),
                  const SizedBox(height: 18),
                  CupertinoButton.filled(
                    onPressed: _generate,
                    child: const Text('重试'),
                  ),
                  CupertinoButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('返回聊天'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
