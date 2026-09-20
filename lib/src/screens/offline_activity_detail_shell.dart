part of 'package:companion_flutter/main.dart';

class _ExpandedSheetTopBar extends StatelessWidget {
  const _ExpandedSheetTopBar({
    required this.title,
    required this.onClose,
  });

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    final view = View.of(context);
    final topInset = view.padding.top / view.devicePixelRatio;
    return SizedBox(
      height: topInset + 74,
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 18),
                // 关闭键跟活动主页左上角返回键同款同大小(36pt 玻璃圆)，只是图标
                // 换成 X。
                child: _WeatherBackButton(
                  onTap: onClose,
                  icon: CupertinoIcons.xmark,
                  iconColor: w.ink,
                ),
              ),
            ),
            Text(
              title,
              style: TextStyle(
                color: w.ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
