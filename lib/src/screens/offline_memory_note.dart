part of 'package:companion_flutter/main.dart';

/// 记忆手札浮层（spec §5.4-8）：竖版玻璃手札卡（封面+日期→旅途小记→唤醒的思绪标签
/// →签名）+ 保存图片 / 分享手札。
///
/// 说明：真正的「保存到相册 / 分享到微信等」需引入 gal + share_plus 依赖并配置原生权限
/// （方案文档 §12 决策点 3，待产品确认）。当前「保存图片」为真实 RepaintBoundary 截图
/// 落地到应用目录；「分享手札」为玻璃渠道面板（占位），接入 SDK 后替换为系统分享。
Future<void> showOfflineMemoryNote(
  BuildContext context, {
  required OfflineMemoryNote note,
  String? authToken,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'memory-note',
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, __, ___) =>
        _MemoryNoteOverlay(note: note, authToken: authToken),
    transitionBuilder: (_, anim, __, child) => _dialogScaleFade(anim, child),
  );
}

class _MemoryNoteOverlay extends StatefulWidget {
  const _MemoryNoteOverlay({required this.note, this.authToken});

  final OfflineMemoryNote note;
  final String? authToken;

  @override
  State<_MemoryNoteOverlay> createState() => _MemoryNoteOverlayState();
}

class _MemoryNoteOverlayState extends State<_MemoryNoteOverlay> {
  final GlobalKey _cardKey = GlobalKey();
  bool _saving = false;

  Future<void> _saveImage() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      // 存入系统相册（gal：iOS 走 add-only 权限，Android 走 MediaStore）。
      await Gal.putImageBytes(
        bytes,
        name: 'memory_note_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (mounted) _showActivityToast(context, '已保存到相册');
    } on GalException catch (e) {
      if (mounted) {
        _showActivityToast(
          context,
          e.type == GalExceptionType.accessDenied ? '需要相册权限才能保存' : '保存失败，请稍后再试',
        );
      }
    } catch (_) {
      if (mounted) _showActivityToast(context, '保存失败，请稍后再试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _share() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      builder: (sheetContext) => _MemoryNoteShareSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final w = _W2b.resolve(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: RepaintBoundary(
                key: _cardKey,
                child: _MemoryNoteCard(note: note, authToken: widget.authToken),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SecondaryActivityPillButton(
                    label: _saving ? '保存中…' : '保存图片',
                    enabled: !_saving,
                    onPressed: _saveImage,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PrimaryActivityPillButton(
                    label: '分享手札',
                    icon: '📤',
                    onPressed: _share,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            CupertinoButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text('关闭', style: TextStyle(color: w.inkSoft)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryNoteCard extends StatelessWidget {
  const _MemoryNoteCard({required this.note, this.authToken});

  final OfflineMemoryNote note;
  final String? authToken;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    final cover = note.coverUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        color: w.isDark ? const Color(0xFF141A24) : Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 150,
              width: double.infinity,
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
                        colors: [Colors.transparent, Color(0x99000000)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatNoteDate(note.dateText),
                          style: const TextStyle(
                            color: Color(0xCCFFFFFF),
                            fontSize: 12,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('旅途小记', style: _titleStyle(context, 15)),
                  const SizedBox(height: 8),
                  Text(
                    note.travelNote,
                    style: _mutedStyle(context, 14).copyWith(height: 1.8),
                  ),
                  if (note.fragmentTags.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('唤醒的思绪', style: _titleStyle(context, 15)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final tag in note.fragmentTags)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: _kActivityAccent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                color: w.inkSoft,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Divider(color: w.glassBorder, height: 1),
                  const SizedBox(height: 10),
                  Text(
                    '伴生 · 陪你走过的一段路',
                    style: TextStyle(
                      color: w.inkFaint,
                      fontSize: 11,
                      letterSpacing: 1,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryNoteShareSheet extends StatelessWidget {
  static const _channels = <(String, String)>[
    ('💬', '微信'),
    ('🌿', '朋友圈'),
    ('📕', '小红书'),
    ('🌐', '微博'),
    ('🔗', '复制链接'),
    ('···', '更多'),
  ];

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    return _BottomSheetFrame(
      backgroundColor: w.base,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sheetGrabber(context),
          Text('分享记忆手札到', style: _titleStyle(context, 16)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 18,
            runSpacing: 18,
            children: [
              for (final (icon, label) in _channels)
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).maybePop();
                    _showActivityToast(context, '分享能力开通后可直达「$label」');
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: w.glass,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: w.glassBorder),
                        ),
                        child: Center(
                          child: Text(icon,
                              style: const TextStyle(fontSize: 22)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(label, style: _mutedStyle(context, 12)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

String _formatNoteDate(String iso) {
  final t = DateTime.tryParse(iso)?.toLocal();
  if (t == null) return iso;
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  return '${t.year}.${t.month}.${t.day} · $hh:$mm';
}
