part of 'package:companion_flutter/main.dart';

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
    return Container(
      height: 360,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 20,
                fontWeight: FontWeight.w900,
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

class _CheckinLoadingCard extends StatelessWidget {
  const _CheckinLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 118,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface(context, light: 0.72),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.glassBorder(context)),
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
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onAdd,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.elevatedSurface(context, light: 0.76),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.glassBorder(context)),
        ),
        child: Text(
          '这一天还没有打卡任务',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _CheckinBackdrop extends StatelessWidget {
  const _CheckinBackdrop();

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
            colors.page,
          ],
        ),
      ),
    );
  }
}
