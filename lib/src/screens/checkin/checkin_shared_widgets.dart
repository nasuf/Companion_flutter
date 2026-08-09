part of 'package:companion_flutter/main.dart';

/// Round white back button in the check-in header.
class _CheckinNavButton extends StatelessWidget {
  const _CheckinNavButton({required this.onPressed});

  static const double _size = 36;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = _CheckinTokens.of(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(_size, _size),
      borderRadius: BorderRadius.circular(_size / 2),
      onPressed: onPressed,
      child: Container(
        width: _size,
        height: _size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tokens.card,
          shape: BoxShape.circle,
          boxShadow: tokens.navShadow,
        ),
        child: Icon(
          CupertinoIcons.chevron_back,
          size: 18,
          color: tokens.accent,
        ),
      ),
    );
  }
}

/// The blue "add plan" button floating over the bottom-right corner.
class _CheckinFab extends StatelessWidget {
  const _CheckinFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = _CheckinTokens.of(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(_kCheckinFabSize, _kCheckinFabSize),
      borderRadius: BorderRadius.circular(_kCheckinFabSize / 2),
      onPressed: onPressed,
      child: Container(
        key: const Key('checkin-fab'),
        width: _kCheckinFabSize,
        height: _kCheckinFabSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tokens.accent,
          shape: BoxShape.circle,
          boxShadow: tokens.fabShadow,
        ),
        child: const Icon(Icons.add_rounded, size: 32, color: Colors.white),
      ),
    );
  }
}

class _CheckinLoadingCard extends StatelessWidget {
  const _CheckinLoadingCard();

  @override
  Widget build(BuildContext context) {
    final tokens = _CheckinTokens.of(context);
    return Container(
      height: _kCheckinTaskRowHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(_kCheckinCardRadius),
        boxShadow: tokens.cardShadow,
      ),
      child: const CupertinoActivityIndicator(),
    );
  }
}

class _CheckinEmptyCard extends StatelessWidget {
  const _CheckinEmptyCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final tokens = _CheckinTokens.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onAdd,
      child: Container(
        height: _kCheckinTaskRowHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tokens.card,
          borderRadius: BorderRadius.circular(_kCheckinCardRadius),
          boxShadow: tokens.cardShadow,
        ),
        child: Text(
          '这一天没有打卡任务',
          style: TextStyle(
            color: tokens.placeholder,
            fontSize: 16,
            height: 1.375,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

class _PickerSheet extends StatelessWidget {
  const _PickerSheet({
    required this.title,
    required this.child,
    required this.onCancel,
    required this.onSave,
  });

  final String title;
  final Widget child;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final tokens = _CheckinTokens.of(context);
    return Container(
      height: 360,
      decoration: BoxDecoration(
        color: tokens.page,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                color: tokens.title,
                fontSize: 20,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.none,
              ),
            ),
            Expanded(child: child),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                CupertinoButton(onPressed: onCancel, child: const Text('取消')),
                CupertinoButton(onPressed: onSave, child: const Text('保存')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
