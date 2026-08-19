part of 'package:companion_flutter/main.dart';

class _LastWillEditResult {
  const _LastWillEditResult({
    required this.content,
    required this.startNow,
    required this.convertToDraft,
  });

  final String content;
  final bool startNow;
  final bool convertToDraft;
}

/// 留遗言 editor. A full-screen route so the graphite background reaches behind
/// the status bar, matching the export.
class _LastWillEditorPage extends StatefulWidget {
  const _LastWillEditorPage({
    required this.initialContent,
    required this.hasContacts,
    required this.allowStart,
    required this.canConvertToDraft,
    required this.ensureContacts,
    this.onDelete,
  });

  final String initialContent;
  final bool hasContacts;
  final bool allowStart;
  final bool canConvertToDraft;
  final Future<bool> Function() ensureContacts;
  final Future<bool> Function()? onDelete;

  @override
  State<_LastWillEditorPage> createState() => _LastWillEditorPageState();
}

class _LastWillEditorPageState extends State<_LastWillEditorPage> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialContent,
  );
  late bool _hasContacts = widget.hasContacts;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = _W2b.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          const Positioned.fill(child: _LegacyBackground()),
          SafeArea(
            bottom: false,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Column(
                children: [
                  // 与胶囊「写新胶囊」编辑页头部完全一致的几何：18/10/18/8 内边距、
                  // 44 高、Positioned+Center 让按钮垂直居中——而不是贴边。
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                    child: SizedBox(
                      height: 44,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: _WeatherBackButton(
                                onTap: () => Navigator.of(context).maybePop(),
                                icon: CupertinoIcons.xmark,
                                iconColor: w.ink,
                              ),
                            ),
                          ),
                          if (widget.onDelete != null)
                            Positioned(
                              right: 0,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: _LegacyEditorDeleteButton(
                                  onTap: _delete,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _legacyGutter,
                      ),
                      child: _LegacyCard(
                        padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
                        child: CupertinoTextField(
                          controller: _controller,
                          maxLines: null,
                          expands: true,
                          autofocus: widget.initialContent.trim().isEmpty,
                          textAlignVertical: TextAlignVertical.top,
                          placeholder: '把想留下的话写在这里...',
                          padding: EdgeInsets.zero,
                          cursorColor: w.ink,
                          style: TextStyle(
                            color: w.ink,
                            fontSize: 20,
                            height: 24 / 20,
                            fontWeight: FontWeight.w400,
                            decoration: TextDecoration.none,
                          ),
                          placeholderStyle: TextStyle(
                            color: w.inkFaint,
                            fontSize: 20,
                            height: 24 / 20,
                            fontWeight: FontWeight.w400,
                            decoration: TextDecoration.none,
                          ),
                          decoration: const BoxDecoration(),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      _legacyGutter,
                      16,
                      _legacyGutter,
                      bottomInset > 0 ? 16 : math.max(26, safeBottom + 12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _LegacyPillButton(
                            label: widget.canConvertToDraft ? '转草稿' : '存草稿',
                            onPressed: () => _pop(
                              startNow: false,
                              convertToDraft: widget.canConvertToDraft,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _LegacyPillButton(
                            label: widget.allowStart
                                ? (_hasContacts ? '开始触发' : '添加联系人')
                                : '更新',
                            primary: true,
                            onPressed: _startNow,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _pop({required bool startNow, bool convertToDraft = false}) {
    Navigator.of(context).pop(
      _LastWillEditResult(
        content: _controller.text,
        startNow: startNow,
        convertToDraft: convertToDraft,
      ),
    );
  }

  Future<void> _startNow() async {
    if (!widget.allowStart) {
      _pop(startNow: false);
      return;
    }
    if (!_hasContacts) {
      final ready = await widget.ensureContacts();
      if (!mounted || !ready) return;
      setState(() => _hasContacts = true);
      return;
    }
    _pop(startNow: true);
  }

  Future<void> _delete() async {
    final deleted = await widget.onDelete?.call() ?? false;
    if (!mounted || !deleted) return;
    Navigator.of(context).maybePop();
  }
}

class _LegacyEditorDeleteButton extends StatelessWidget {
  const _LegacyEditorDeleteButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Same 36pt glass circle as the header's back/close button (_W2b is the
    // weather page's shared token set, visible library-wide) — the header now
    // sits on the bright page rather than the old dark background, so a bare
    // white glyph with a drop shadow would no longer read.
    final w = _W2b.of(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: w.glass,
          shape: BoxShape.circle,
          border: Border.all(color: w.glassBorder),
          boxShadow: [w.pillShadow],
        ),
        child: const Icon(
          CupertinoIcons.delete,
          size: 20,
          color: _legacyDanger,
        ),
      ),
    );
  }
}
