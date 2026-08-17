part of 'package:companion_flutter/main.dart';

/// The 草稿 sheet. Carries the capsule palette rather than the app surface
/// tokens, because it is only ever reached from the warm capsule home.
class _CapsuleDraftSheet extends StatelessWidget {
  const _CapsuleDraftSheet({required this.capsules});

  final List<TimeCapsule> capsules;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    return Container(
      // Hugs its rows instead of always claiming half the screen: one draft
      // under a tall warm slab reads as a loading failure.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.58,
      ),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      // Opaque warm sand, the same ground the home breathes on: the rows are
      // glass, so the panel behind them has to be solid to read over the scrim.
      decoration: BoxDecoration(
        color: w.isDark ? _capsuleWarmBaseDark : _capsuleWarmBase,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SafeArea(
        top: false,
        // merge, not replace: a plain DefaultTextStyle would also drop the font
        // family the app installs.
        child: DefaultTextStyle.merge(
          style: TextStyle(color: w.ink, decoration: TextDecoration.none),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SheetGrabber(color: Color(0xFFFFDCB0)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '草稿',
                    style: TextStyle(
                      color: w.ink,
                      fontSize: 18,
                      height: 22 / 18,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _capsuleOrange,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: const [_capsuleOrangeShadow],
                    ),
                    child: Text(
                      '${capsules.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        height: 13 / 11,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '还没封存，随时可以接着写',
                style: TextStyle(
                  color: w.inkSoft,
                  fontSize: 11,
                  height: 13 / 11,
                  fontWeight: FontWeight.w400,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: ListView.separated(
                  // The viewport clips, so the last row needs room to drop its
                  // shadow.
                  padding: const EdgeInsets.only(bottom: 8),
                  shrinkWrap: true,
                  itemCount: capsules.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _CapsuleDraftTile(
                    capsule: capsules[index],
                    onTap: () {
                      final selected = capsules[index];
                      Navigator.of(context).pop(selected);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
