part of 'package:companion_flutter/main.dart';

/// 活动回顾页（spec §5.4-7）。玻璃风格：英雄头图 + 旅途故事 + 素材画廊 + 思绪碎片集
/// + 事件记录 + 页脚（生成记忆手札 / 查看原始聊天）。
class OfflineReviewPage extends StatefulWidget {
  const OfflineReviewPage({
    super.key,
    required this.api,
    required this.session,
    required this.activityId,
  });

  final CompanionApi api;
  final AuthSession session;
  final String activityId;

  @override
  State<OfflineReviewPage> createState() => _OfflineReviewPageState();
}

// tier -> (emoji, 标签, 主调色)，与思绪气泡保持一致。
const Map<String, (String, String, Color)> _kFragmentTierMeta = {
  'rare': ('💭', '片刻感想', Color(0xFF5FB6AE)),
  'epic': ('📜', '心底独白', Color(0xFFB07FD0)),
  'legendary': ('🔮', '秘密念想', Color(0xFFD79A2E)),
};

class _OfflineReviewPageState extends State<OfflineReviewPage> {
  OfflineActivityReview? _review;
  bool _loading = true;
  bool _generatingNote = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final review = await widget.api.fetchOfflineActivityReview(
        widget.activityId,
      );
      if (!mounted) return;
      setState(() {
        _review = review;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException ? error.message : error.toString();
      });
    }
  }

  Future<void> _openMemoryNote() async {
    if (_generatingNote) return;
    setState(() => _generatingNote = true);
    try {
      final note = await widget.api.generateOfflineMemoryNote(widget.activityId);
      if (!mounted) return;
      await showOfflineMemoryNote(context, note: note, authToken: widget.api.authToken);
    } on ApiException catch (error) {
      if (mounted) _showActivityToast(context, error.message);
    } finally {
      if (mounted) setState(() => _generatingNote = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return CupertinoPageScaffold(
      backgroundColor: colors.page,
      child: DefaultTextStyle(
        style: TextStyle(
          color: colors.text,
          fontSize: 15,
          decoration: TextDecoration.none,
        ),
        child: Stack(
          children: [
            const _ActivityPageBackdrop(),
            SafeArea(
              bottom: false,
              child: _loading
                  ? const Center(child: CupertinoActivityIndicator())
                  : _review == null
                  ? _buildError()
                  : _buildBody(_review!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: _OfflineErrorBlock(
          message: _error ?? '加载失败',
          onRetry: () {
            setState(() => _loading = true);
            _load();
          },
        ),
      ),
    );
  }

  Widget _buildBody(OfflineActivityReview review) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _WeatherBackButton(
                onTap: () => Navigator.of(context).maybePop(),
                iconColor: _W2b.resolve(context).ink,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: _ReviewHero(review: review, authToken: widget.api.authToken),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: _ReviewCard(
              title: '旅途故事',
              child: Text(
                review.story,
                style: _mutedStyle(context, 14).copyWith(height: 1.7),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: _ReviewCard(
              title: '素材画廊',
              child: review.gallery.isEmpty
                  ? Text('本次没有留下图片素材',
                      style: _mutedStyle(context, 13))
                  : _ReviewGallery(
                      urls: review.gallery,
                      authToken: widget.api.authToken,
                    ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: _ReviewCard(
              title: '思绪碎片集',
              child: review.fragments.isEmpty
                  ? Text('本次没有收藏任何思绪碎片',
                      style: _mutedStyle(context, 13))
                  : _ReviewFragmentRow(fragments: review.fragments),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: _ReviewCard(
              title: '事件记录',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (review.eventTags.isEmpty)
                    Text('暂无事件记录', style: _mutedStyle(context, 13))
                  else
                    for (final tag in review.eventTags) _ReviewEventTag(tag: tag),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
            child: SizedBox(
              width: double.infinity,
              child: _PrimaryActivityPillButton(
                label: _generatingNote ? '正在生成…' : '生成记忆手札',
                icon: '✨',
                enabled: !_generatingNote,
                onPressed: _openMemoryNote,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Center(
            child: CupertinoButton(
              // 返回聊天并把到达卡消息 id 作为结果回传，聊天页据此滚动到「我到了」。
              onPressed: () =>
                  Navigator.of(context).pop(_review?.arrivalMessageId),
              child: Text('查看原始聊天', style: _mutedStyle(context, 13)),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 30)),
      ],
    );
  }
}

class _ReviewHero extends StatelessWidget {
  const _ReviewHero({required this.review, required this.authToken});

  final OfflineActivityReview review;
  final String? authToken;

  @override
  Widget build(BuildContext context) {
    final cover = review.coverUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 208,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (cover != null && cover.isNotEmpty)
              Image.network(
                cover,
                fit: BoxFit.cover,
                headers: _mediaHeadersForUrl(cover, authToken),
                errorBuilder: (_, __, ___) =>
                    const ColoredBox(color: Color(0xFFB9D9F2)),
              )
            else
              const ColoredBox(color: Color(0xFFB9D9F2)),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xB3000000)],
                  stops: [0.4, 1],
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '旅途回忆',
                    style: TextStyle(
                      color: Color(0xE6FFFFFF),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    review.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _reviewTimeRange(review.startedAt, review.endedAt),
                    style: const TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontSize: 12,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  if ((review.address ?? '').isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      '📍 ${review.address}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontSize: 12,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _softCardDecoration(context, radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _titleStyle(context, 16)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ReviewGallery extends StatelessWidget {
  const _ReviewGallery({required this.urls, required this.authToken});

  final List<String> urls;
  final String? authToken;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => _showOfflineActivityImagePreview(
            context,
            url: urls[i],
            authToken: authToken,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              urls[i],
              width: 96,
              height: 96,
              fit: BoxFit.cover,
              headers: _mediaHeadersForUrl(urls[i], authToken),
              errorBuilder: (_, __, ___) => Container(
                width: 96,
                height: 96,
                color: AppColors.of(context).surfaceMuted,
                child: Icon(CupertinoIcons.photo,
                    color: AppColors.of(context).muted),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewFragmentRow extends StatelessWidget {
  const _ReviewFragmentRow({required this.fragments});

  final List<OfflineActivityFragment> fragments;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: fragments.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final f = fragments[i];
          final (icon, label, accent) =
              _kFragmentTierMeta[f.tier] ?? _kFragmentTierMeta['rare']!;
          return GestureDetector(
            onTap: () => _showFragmentLightbox(context, f),
            child: Container(
              width: 210,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _W2b.resolve(context).glass,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$icon $label',
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      f.text,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: _mutedStyle(context, 13).copyWith(height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

void _showFragmentLightbox(BuildContext context, OfflineActivityFragment f) {
  final (icon, label, accent) =
      _kFragmentTierMeta[f.tier] ?? _kFragmentTierMeta['rare']!;
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'fragment',
    barrierColor: Colors.black.withValues(alpha: 0.5),
    pageBuilder: (dialogContext, _, __) => Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: GestureDetector(
          onTap: () => Navigator.of(dialogContext).pop(),
          child: _GlassDialogCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$icon $label',
                  style: TextStyle(
                    color: accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  f.text,
                  style: _mutedStyle(dialogContext, 15).copyWith(height: 1.7),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ReviewEventTag extends StatelessWidget {
  const _ReviewEventTag({required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _kActivityAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        tag,
        style: const TextStyle(
          color: _kActivityAccent,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

String _reviewTimeRange(String? startIso, String? endIso) {
  final start = DateTime.tryParse(startIso ?? '')?.toLocal();
  final end = DateTime.tryParse(endIso ?? '')?.toLocal();
  if (start == null) return '';
  String d(DateTime t) => '${t.year}/${t.month}/${t.day}';
  String hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  if (end == null) return '${d(start)} ${hm(start)}';
  if (d(start) == d(end)) return '${d(start)} ${hm(start)} - ${hm(end)}';
  return '${d(start)} ${hm(start)} - ${d(end)} ${hm(end)}';
}
