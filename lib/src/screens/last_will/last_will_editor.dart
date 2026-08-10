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
                  _LegacyHeader(
                    backIcon: CupertinoIcons.xmark,
                    onBack: () => Navigator.of(context).maybePop(),
                    trailing: widget.onDelete == null
                        ? null
                        : _LegacyEditorDeleteButton(onTap: _delete),
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
                          cursorColor: Colors.white,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            height: 24 / 20,
                            fontWeight: FontWeight.w400,
                            decoration: TextDecoration.none,
                          ),
                          placeholderStyle: const TextStyle(
                            color: _legacyPlaceholderOnCard,
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
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: const SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: Icon(
            CupertinoIcons.delete,
            size: 26,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Color(0x80000000),
                blurRadius: 4,
                offset: Offset(0, 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
