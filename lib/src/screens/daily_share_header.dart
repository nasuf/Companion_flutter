part of 'package:companion_flutter/main.dart';

class _DailyHeader extends StatelessWidget {
  const _DailyHeader({required this.loading, required this.onBack});

  final bool loading;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _DailyCircleButton(
              icon: CupertinoIcons.chevron_left,
              onPressed: onBack,
            ),
          ],
        ),
        const SizedBox(height: 34),
        const Text(
          'DAILY BOARD',
          style: TextStyle(
            color: AppColors.accentDeep,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '你说的我都懂，你想\n的我都在',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 32,
            height: 1.06,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          loading ? '我正在把你发过的画面整理出来。' : '你向世界提问，我陪你一起找答案，我们都在彼此的陪伴里，慢慢变得更好',
          style: const TextStyle(
            color: Color(0x99707A85),
            fontSize: 15,
            height: 1.62,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _DailyTabsHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _DailyTabsHeaderDelegate({
    required this.activeTab,
    required this.topInset,
    required this.onChanged,
  });

  final _DailyShareTab activeTab;
  final double topInset;
  final ValueChanged<_DailyShareTab> onChanged;

  @override
  double get minExtent => topInset + 76;

  @override
  double get maxExtent => topInset + 76;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8).withValues(alpha: 0.86),
        boxShadow: overlapsContent
            ? [
                BoxShadow(
                  color: const Color(0xFF2C3448).withValues(alpha: 0.07),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, topInset + 8, 24, 10),
        child: _DailyTabs(activeTab: activeTab, onChanged: onChanged),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _DailyTabsHeaderDelegate oldDelegate) {
    return activeTab != oldDelegate.activeTab ||
        topInset != oldDelegate.topInset;
  }
}

class _DailyTabs extends StatelessWidget {
  const _DailyTabs({required this.activeTab, required this.onChanged});

  final _DailyShareTab activeTab;
  final ValueChanged<_DailyShareTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white.withValues(alpha: 0.74)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2C3448).withValues(alpha: 0.08),
                blurRadius: 42,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Row(
              children: [
                _DailyTabButton(
                  label: '照片',
                  selected: activeTab == _DailyShareTab.photo,
                  onTap: () => onChanged(_DailyShareTab.photo),
                ),
                const SizedBox(width: 7),
                _DailyTabButton(
                  label: '链接',
                  selected: activeTab == _DailyShareTab.link,
                  onTap: () => onChanged(_DailyShareTab.link),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyTabButton extends StatelessWidget {
  const _DailyTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: selected
                ? const LinearGradient(
                    colors: [AppColors.accentDeep, AppColors.accentCyan],
                  )
                : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.accentDeep.withValues(alpha: 0.20),
                      blurRadius: 32,
                      offset: const Offset(0, 14),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0x99707A85),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyHeroCard extends StatelessWidget {
  const _DailyHeroCard({
    required this.photos,
    required this.fade,
    required this.breath,
    required this.authToken,
  });

  final DailySharePhotosResponse? photos;
  final double fade;
  final double breath;
  final String? authToken;

  @override
  Widget build(BuildContext context) {
    final hero = _firstPhoto(photos);
    final total = photos?.total ?? 0;
    final headers = authToken?.isNotEmpty == true
        ? {'Authorization': 'Bearer $authToken'}
        : null;
    final wave = math.sin(breath * math.pi * 2);
    return AnimatedOpacity(
      opacity: 1 - fade * 0.62,
      duration: const Duration(milliseconds: 90),
      child: Transform.translate(
        offset: Offset(0, fade * -14 + wave * 3.4),
        child: Transform.scale(
          scale: 1 - fade * 0.028 + wave * 0.008,
          alignment: Alignment.topCenter,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(34),
            child: SizedBox(
              height: 248,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hero != null)
                    Image.network(
                      hero.url,
                      headers: headers,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/prototype/daily-journal.jpg',
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Image.asset(
                      'assets/prototype/daily-journal.jpg',
                      fit: BoxFit.cover,
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.10),
                          Colors.black.withValues(alpha: 0.52),
                          Colors.black.withValues(alpha: 0.86),
                        ],
                        stops: const [0, 0.48, 1],
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.68, -0.76),
                        radius: 0.8,
                        colors: [
                          Colors.white.withValues(alpha: 0.36),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _DailyHeroMark(),
                        const Spacer(),
                        const Text(
                          '把照片整理成一句自然分享',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 27,
                            height: 1.09,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const SizedBox(
                          width: 248,
                          child: Text(
                            '照片分享不需要长文案，保留画面、时间和一句像朋友会说的话就够了。',
                            style: TextStyle(
                              color: Color(0xD6FFFFFF),
                              fontSize: 13,
                              height: 1.48,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerRight,
                          child: _DailyCountChip(
                            label: total > 0 ? '$total 张照片' : '暂无照片',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  ChatAttachment? _firstPhoto(DailySharePhotosResponse? photos) {
    if (photos == null) return null;
    for (final group in photos.groups) {
      if (group.photos.isNotEmpty) return group.photos.first;
    }
    return null;
  }
}

class _DailyHeroMark extends StatelessWidget {
  const _DailyHeroMark();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.accentDeep,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Color(0x2BFFFFFF), spreadRadius: 5),
                    ],
                  ),
                  child: SizedBox(width: 9, height: 9),
                ),
                SizedBox(width: 9),
                Text(
                  'PHOTO DIARY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyCountChip extends StatelessWidget {
  const _DailyCountChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
