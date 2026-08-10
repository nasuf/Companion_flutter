part of 'package:companion_flutter/main.dart';

class _LegacyContactResult {
  const _LegacyContactResult.saved(this.contact) : deleted = false;
  const _LegacyContactResult.deleted() : contact = null, deleted = true;

  final LastWillContact? contact;
  final bool deleted;
}

/// 联系人管理界面 — one card per slot, empty slots read "点击添加".
class _LegacyContactsManagePage extends StatefulWidget {
  const _LegacyContactsManagePage({
    required this.contacts,
    required this.onSave,
  });

  final List<LastWillContact> contacts;
  final Future<List<LastWillContact>> Function(List<LastWillContact>) onSave;

  @override
  State<_LegacyContactsManagePage> createState() =>
      _LegacyContactsManagePageState();
}

class _LegacyContactsManagePageState extends State<_LegacyContactsManagePage> {
  late List<LastWillContact> _contacts = [...widget.contacts];

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _LegacyBackground()),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _LegacyHeader(onBack: () => Navigator.of(context).maybePop()),
                Expanded(
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      _legacyGutter,
                      21,
                      _legacyGutter,
                      math.max(24, safeBottom + 12),
                    ),
                    itemCount: _legacyMaxContacts,
                    separatorBuilder: (_, __) => const SizedBox(height: 24),
                    itemBuilder: (context, index) {
                      return _LegacyContactRowCard(
                        key: Key('legacy-contact-slot-$index'),
                        contact: index < _contacts.length
                            ? _contacts[index]
                            : null,
                        onTap: () => _edit(index),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(int index) async {
    final existing = index < _contacts.length ? _contacts[index] : null;
    final result = await _showLegacyContactSheet(
      context,
      index: index,
      initial: existing,
    );
    if (result == null || !mounted) return;
    final next = [..._contacts];
    if (result.deleted) {
      if (existing == null) return;
      next.removeAt(index);
    } else {
      final contact = result.contact;
      if (contact == null) return;
      if (existing == null) {
        next.add(contact);
      } else {
        next[index] = contact;
      }
    }
    setState(() => _contacts = next);
    final effective = await widget.onSave(next);
    if (!mounted) return;
    setState(() => _contacts = effective);
  }
}

class _LegacyContactRowCard extends StatelessWidget {
  const _LegacyContactRowCard({
    super.key,
    required this.contact,
    required this.onTap,
  });

  final LastWillContact? contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final contact = this.contact;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: _LegacyCard(
        padding: const EdgeInsets.fromLTRB(17, 16, 20, 16),
        child: SizedBox(
          height: 87,
          child: Row(
            children: [
              _LegacyContactAvatar(filled: contact != null),
              const SizedBox(width: 11),
              Expanded(
                child: contact == null
                    ? const Text(
                        '点击添加',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 17 / 14,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.none,
                        ),
                      )
                    : Text(
                        _summary(contact),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 20 / 14,
                          fontWeight: FontWeight.w900,
                          decoration: TextDecoration.none,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              const Icon(
                CupertinoIcons.chevron_right,
                size: 20,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _summary(LastWillContact contact) {
    final lines = <String>['名字：${_orDash(contact.name)}'];
    final email = contact.email?.trim() ?? '';
    final phone = contact.phone?.trim() ?? '';
    if (email.isNotEmpty) lines.add('邮箱：$email');
    if (phone.isNotEmpty) lines.add('电话：$phone');
    return lines.join('\n');
  }

  static String _orDash(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? '未命名' : trimmed;
  }
}

/// 联系人添加 bottom sheet — adds or edits a single contact.
Future<_LegacyContactResult?> _showLegacyContactSheet(
  BuildContext context, {
  required int index,
  LastWillContact? initial,
}) {
  return showModalBottomSheet<_LegacyContactResult>(
    context: context,
    isScrollControlled: true,
    enableDrag: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x6B000000),
    builder: (_) => _LegacyContactSheet(index: index, initial: initial),
  );
}

class _LegacyContactSheet extends StatefulWidget {
  const _LegacyContactSheet({required this.index, this.initial});

  final int index;
  final LastWillContact? initial;

  @override
  State<_LegacyContactSheet> createState() => _LegacyContactSheetState();
}

class _LegacyContactSheetState extends State<_LegacyContactSheet> {
  late final _LegacyContactDraft _draft = widget.initial == null
      ? _LegacyContactDraft()
      : _LegacyContactDraft.fromContact(widget.initial!);
  String? _error;

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final safeBottom = media.padding.bottom;
    // The panel grows downwards by however much keyboard there is instead of
    // being pushed up by it. Two things come out of that: its background keeps
    // reaching the screen edge, so the sheet and the keyboard read as one slab
    // rather than two with a dark seam between them; and the height is a plain
    // function of the inset, so it tracks the keyboard frame by frame. The
    // AnimatedPadding this replaces ran its own 200ms curve on top of the
    // system animation, which is the lag you could see on dismiss.
    return Container(
      key: const Key('legacy-contact-sheet'),
      decoration: const BoxDecoration(
        gradient: _legacyCardGradient,
        borderRadius: BorderRadius.vertical(top: _legacyCardRadius),
        boxShadow: [_legacyCardShadow],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Flexible, not Expanded: the sheet stays content-height until the
          // keyboard squeezes it, and only then does the form scroll.
          Flexible(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                // Scrolling must not yank the keyboard away mid-gesture;
                // tapping outside a field still dismisses it.
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.manual,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 45),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        '紧急联系人',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          height: 24 / 20,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 13),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        '最多$_legacyMaxContacts位，邮箱或者电话至少填写一个。',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          height: 14 / 12,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 38),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 17, 16, 34),
                        decoration: BoxDecoration(
                          color: _legacyPanelFill,
                          borderRadius: _legacyCardBorderRadius,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '联系人${widget.index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      height: 19 / 16,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                                if (widget.initial != null)
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    onPressed: _remove,
                                    child: const Icon(
                                      CupertinoIcons.delete,
                                      size: 22,
                                      color: Color(0xFFA5A3A3),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 11),
                            _LegacyGlassField(
                              controller: _draft.name,
                              placeholder: '名字',
                              textCapitalization: TextCapitalization.words,
                            ),
                            const SizedBox(height: 12),
                            _LegacyGlassField(
                              controller: _draft.email,
                              placeholder: '邮箱',
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 12),
                            _LegacyGlassField(
                              controller: _draft.phone,
                              placeholder: '电话',
                              keyboardType: TextInputType.phone,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Pinned below the scroller so it sits on the keyboard line, and so
          // a validation message cannot be left scrolled out of sight at the
          // moment it appears.
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 12, 32, 0),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFFFFD9D9),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              32,
              26,
              32,
              // The home indicator only needs clearing while it is showing —
              // the keyboard covers it on the way up.
              math.max(34, safeBottom + 20 - keyboard),
            ),
            child: Center(
              child: SizedBox(
                key: const Key('legacy-contact-save'),
                width: 174,
                child: _LegacyPillButton(
                  label: widget.initial == null ? '添加联系人' : '保存联系人',
                  primary: true,
                  onPressed: _save,
                ),
              ),
            ),
          ),
          // The stretch that lives behind the keyboard.
          SizedBox(height: keyboard),
        ],
      ),
    );
  }

  void _save() {
    final error = _draft.validationError(index: widget.index);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final contact = _draft.toContact();
    if (contact == null) {
      setState(() => _error = '请填写联系人信息');
      return;
    }
    Navigator.of(context).pop(_LegacyContactResult.saved(contact));
  }

  Future<void> _remove() async {
    final confirmed = await _showLegacyConfirmDialog(
      context,
      title: '删除联系人？',
      message: '删除后我们将不再把你的遗言转告这位联系人。',
      confirmLabel: '删除',
      buttonHeight: 32,
    );
    if (!confirmed || !mounted) return;
    Navigator.of(context).pop(const _LegacyContactResult.deleted());
  }
}

/// 46px glass input pill used inside the contact sheet.
class _LegacyGlassField extends StatelessWidget {
  const _LegacyGlassField({
    required this.controller,
    required this.placeholder,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String placeholder;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      cursorColor: _legacyInk,
      decoration: BoxDecoration(
        color: _legacyGlassFill,
        borderRadius: _legacyCardBorderRadius,
        border: Border.all(color: Colors.white),
      ),
      style: const TextStyle(
        color: _legacyInk,
        fontSize: 16,
        height: 19 / 16,
        fontWeight: FontWeight.w700,
        decoration: TextDecoration.none,
      ),
      placeholderStyle: const TextStyle(
        color: _legacyPlaceholderOnGlass,
        fontSize: 16,
        height: 19 / 16,
        fontWeight: FontWeight.w700,
        decoration: TextDecoration.none,
      ),
    );
  }
}

class _LegacyContactDraft {
  _LegacyContactDraft()
    : name = TextEditingController(),
      email = TextEditingController(),
      phone = TextEditingController();

  _LegacyContactDraft.fromContact(LastWillContact contact)
    : name = TextEditingController(text: contact.name),
      email = TextEditingController(text: contact.email ?? ''),
      phone = TextEditingController(text: contact.phone ?? '');

  final TextEditingController name;
  final TextEditingController email;
  final TextEditingController phone;

  LastWillContact? toContact() {
    final n = name.text.trim();
    final e = email.text.trim();
    final p = phone.text.trim();
    if (n.isEmpty && e.isEmpty && p.isEmpty) return null;
    return LastWillContact(
      name: n,
      email: e.isEmpty ? null : e,
      phone: p.isEmpty ? null : p,
    );
  }

  String? validationError({required int index}) {
    final n = name.text.trim();
    final e = email.text.trim();
    final p = phone.text.trim();
    if (n.isEmpty && e.isEmpty && p.isEmpty) return null;
    final label = '联系人${index + 1}';
    if (n.isEmpty) return '$label 请填写名字';
    if (e.isEmpty && p.isEmpty) return '$label 请填写邮箱或电话';
    if (e.isNotEmpty && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(e)) {
      return '$label 邮箱格式不正确';
    }
    if (p.isNotEmpty && !RegExp(r'^[0-9+()\-\s]{5,40}$').hasMatch(p)) {
      return '$label 电话格式不正确';
    }
    return null;
  }

  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
  }
}
