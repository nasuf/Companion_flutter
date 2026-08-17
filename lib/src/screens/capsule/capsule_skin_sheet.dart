part of 'package:companion_flutter/main.dart';

class _CapsuleSkinSheet extends StatelessWidget {
  const _CapsuleSkinSheet({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.66,
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      // Same warm sand ground as the home and drafts sheet, so the skin picker
      // reads as one more warm capsule surface rather than the app-grey page.
      decoration: BoxDecoration(
        color: w.isDark ? _capsuleWarmBaseDark : _capsuleWarmBase,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: DefaultTextStyle.merge(
          style: TextStyle(color: w.ink, decoration: TextDecoration.none),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SheetGrabber(color: Color(0xFFFFDCB0)),
              Text(
                '选择信纸皮肤',
                style: TextStyle(
                  color: w.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: GridView.builder(
                  itemCount: _CapsuleSkin.all.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.9,
                  ),
                  itemBuilder: (context, index) {
                    final skin = _CapsuleSkin.all[index];
                    final isSelected = skin.id == selected;
                    return CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => onSelected(skin.id),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: skin.paper,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected ? skin.accent : Colors.white,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              skin.name,
                              style: TextStyle(
                                color: skin.text,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            const Spacer(),
                            Container(height: 1, color: skin.line),
                            const SizedBox(height: 8),
                            Container(width: 60, height: 1, color: skin.line),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
