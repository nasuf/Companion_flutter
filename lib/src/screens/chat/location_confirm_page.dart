part of 'package:companion_flutter/main.dart';

class LocationConfirmPage extends StatelessWidget {
  const LocationConfirmPage({
    super.key,
    required this.snapshot,
  });

  final DeviceLocationSnapshot snapshot;

  static Future<ChatComponentCard?> push(
    BuildContext context, {
    required DeviceLocationSnapshot snapshot,
  }) {
    return Navigator.of(context).push<ChatComponentCard>(
      CupertinoPageRoute<ChatComponentCard>(
        fullscreenDialog: true,
        builder: (_) => LocationConfirmPage(snapshot: snapshot),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = snapshot.toComponentCard();
    final colors = AppColors.of(context);
    return CupertinoPageScaffold(
      backgroundColor: colors.page,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('发送位置'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(card),
          child: const Text(
            '发送',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          children: [
            Text(
              '确认要发送这个位置吗？',
              style: TextStyle(
                color: colors.text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Agent 会看到你分享的当前位置，并据此回复。',
              style: TextStyle(color: colors.muted, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: _LocationComponentCard(
                card: card,
                isMine: true,
                onTap: () {},
              ),
            ),
            const SizedBox(height: 18),
            if (snapshot.accuracyMeters != null)
              Text(
                '定位精度约 ${snapshot.accuracyMeters!.round()} 米',
                style: TextStyle(color: colors.muted, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}
