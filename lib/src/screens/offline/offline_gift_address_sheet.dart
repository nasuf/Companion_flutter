part of 'package:companion_flutter/main.dart';

class _AddressEditSheet extends StatefulWidget {
  const _AddressEditSheet({
    required this.api,
    required this.initial,
    required this.onSaved,
  });

  final CompanionApi api;
  final GiftAddress? initial;
  final VoidCallback onSaved;

  @override
  State<_AddressEditSheet> createState() => _AddressEditSheetState();
}

class _AddressEditSheetState extends State<_AddressEditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _detail;
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  ChinaRegionData? _regions;
  String? _province;
  String? _city;
  String? _district;
  bool _regionsLoading = true;
  bool _saving = false;
  bool _confirmingDelete = false;
  bool _addressLoading = false;
  bool _hasSavedAddress = false;
  String? _addressError;
  String? _operationError;

  @override
  void initState() {
    super.initState();
    _hasSavedAddress = widget.initial?.hasAddress == true;
    // Home data is masked. Never seed editable fields from that snapshot.
    final initial = _hasSavedAddress ? null : widget.initial;
    _name = TextEditingController(text: initial?.recipientName ?? '');
    _phone = TextEditingController(text: initial?.phone ?? '');
    _province = _emptyToNull(initial?.province);
    _city = _emptyToNull(initial?.city);
    _district = _emptyToNull(initial?.district);
    _detail = TextEditingController(text: initial?.detail ?? '');
    _loadRegions();
    if (_hasSavedAddress) unawaited(_loadAddress());
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _detail.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  Future<void> _loadAddress() async {
    setState(() {
      _addressLoading = true;
      _addressError = null;
    });
    try {
      final address = await widget.api.fetchGiftAddress();
      if (!mounted) return;
      setState(() {
        _hasSavedAddress = address.hasAddress;
        _name.text = address.recipientName ?? '';
        _phone.text = address.phone ?? '';
        _detail.text = address.detail ?? '';
        _province = _emptyToNull(address.province);
        _city = _emptyToNull(address.city);
        _district = _emptyToNull(address.district);
      });
    } catch (_) {
      if (mounted) setState(() => _addressError = '地址加载失败，请重试');
    } finally {
      if (mounted) setState(() => _addressLoading = false);
    }
  }

  Future<void> _delete() async {
    if (_saving || _confirmingDelete || _addressLoading || !_hasSavedAddress) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _confirmingDelete = true;
      _operationError = null;
    });
    try {
      final confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('删除收货地址？'),
          content: const Text('新的礼物需要重新填写地址，已下单礼物的配送不受影响。'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      setState(() {
        _confirmingDelete = false;
        _saving = true;
      });
      await widget.api.deleteGiftAddress();
      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _operationError = '地址删除失败，请重试');
    } finally {
      if (mounted) {
        setState(() {
          _confirmingDelete = false;
          _saving = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_saving ||
        _confirmingDelete ||
        _addressLoading ||
        _addressError != null) {
      return;
    }
    final validationError = _validateAddress();
    if (validationError != null) {
      await _showAddressError(validationError);
      return;
    }
    setState(() {
      _saving = true;
      _operationError = null;
    });
    try {
      await widget.api.saveGiftAddress(
        recipientName: _name.text.trim(),
        phone: _phone.text.trim(),
        province: (_province ?? '').trim(),
        city: (_city ?? '').trim(),
        district: (_district ?? '').trim(),
        detail: _detail.text.trim(),
      );
      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _operationError = '地址保存失败，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validateAddress() {
    if (_name.text.trim().isEmpty) return '先填一下收件人。';
    final phone = _phone.text.trim().replaceAll(RegExp(r'[\s-]+'), '');
    if (!RegExp(r'^\+?\d{6,20}$').hasMatch(phone)) {
      return '手机号格式看起来不太对。';
    }
    if ((_province ?? '').trim().isEmpty) return '先选一下省份。';
    if ((_city ?? '').trim().isEmpty) return '所在城市不能为空。';
    if ((_district ?? '').trim().isEmpty) return '所在地区不能为空。';
    if (_detail.text.trim().length < 3) return '详细地址再写具体一点。';
    return null;
  }

  static String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  Future<void> _loadRegions() async {
    try {
      final data = await ChinaRegions.load();
      if (!mounted) return;
      setState(() {
        _regions = data;
        _regionsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _regionsLoading = false);
    }
  }

  List<String> _provinceOptions() {
    return _withCurrent(_regions?.provinces ?? const [], _province);
  }

  List<String> _cityOptions() {
    return _withCurrent(_regions?.citiesFor(_province) ?? const [], _city);
  }

  List<String> _districtOptions() {
    return _withCurrent(
      _regions?.districtsFor(_province, _city) ?? const [],
      _district,
    );
  }

  List<String> _withCurrent(List<String> options, String? current) {
    final trimmed = current?.trim();
    if (trimmed == null || trimmed.isEmpty || options.contains(trimmed)) {
      return options;
    }
    return [trimmed, ...options];
  }

  Future<void> _selectProvince() async {
    if (!_hasRegionData()) return;
    final selected = await _pickAddressValue(
      title: '选择省份',
      options: _provinceOptions(),
      current: _province,
    );
    if (selected == null || selected == _province) return;
    setState(() {
      _province = selected;
      _city = null;
      _district = null;
    });
  }

  Future<void> _selectCity() async {
    if (!_hasRegionData()) return;
    if ((_province ?? '').trim().isEmpty) {
      await _showAddressError('先选省份，再选所在城市。');
      return;
    }
    final selected = await _pickAddressValue(
      title: '选择城市',
      options: _cityOptions(),
      current: _city,
    );
    if (selected == null || selected == _city) return;
    setState(() {
      _city = selected;
      _district = null;
    });
  }

  Future<void> _selectDistrict() async {
    if (!_hasRegionData()) return;
    if ((_city ?? '').trim().isEmpty) {
      await _showAddressError('先选所在城市，再选所在地区。');
      return;
    }
    final selected = await _pickAddressValue(
      title: '选择地区',
      options: _districtOptions(),
      current: _district,
    );
    if (selected == null || selected == _district) return;
    setState(() => _district = selected);
  }

  bool _hasRegionData() {
    if (_regions != null) return true;
    _showAddressError(_regionsLoading ? '地址数据还在加载，稍等一下。' : '地址数据加载失败，请稍后再试。');
    return false;
  }

  Future<String?> _pickAddressValue({
    required String title,
    required List<String> options,
    required String? current,
  }) async {
    FocusScope.of(context).unfocus();
    if (options.isEmpty) return null;
    var selected = current != null && options.contains(current)
        ? current
        : options.first;
    final initialIndex = math.max(0, options.indexOf(selected));
    return showCupertinoModalPopup<String>(
      context: context,
      builder: (popupContext) {
        final colors = AppColors.of(popupContext);
        final popupTextStyle = TextStyle(
          color: colors.text,
          decoration: TextDecoration.none,
        );
        return DefaultTextStyle(
          style: popupTextStyle,
          child: Container(
            height: 312,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  SizedBox(
                    height: 54,
                    child: Row(
                      children: [
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          onPressed: () => Navigator.of(popupContext).pop(),
                          child: Text(
                            '取消',
                            style: popupTextStyle.copyWith(color: colors.muted),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: popupTextStyle.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          onPressed: () =>
                              Navigator.of(popupContext).pop(selected),
                          child: Text(
                            '完成',
                            style: popupTextStyle.copyWith(
                              color: const Color(0xFFE0813A),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(
                        initialItem: initialIndex,
                      ),
                      itemExtent: 42,
                      magnification: 1.04,
                      squeeze: 1.08,
                      onSelectedItemChanged: (index) =>
                          selected = options[index],
                      children: [
                        for (final option in options)
                          Center(
                            child: Text(
                              option,
                              style: popupTextStyle.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAddressError(String message) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: const Text('地址还没填完整'),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(message),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('知道了'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final busy =
        _saving ||
        _confirmingDelete ||
        _addressLoading ||
        _addressError != null;
    final sheet = LayoutBuilder(
      builder: (context, constraints) {
        // Fit the complete form when space permits. With the IME or large text,
        // cap the sheet below the safe top and scroll only the form.
        // viewPadding remains stable as the IME closes. A keyboard > 0 branch
        // would jump from 12px to the home-indicator inset on its final frame.
        final bottom = math.max(keyboard, media.viewPadding.bottom) + 18;
        return ConstrainedBox(
          key: const ValueKey('gift-address-sheet'),
          constraints: BoxConstraints(
            maxHeight: constraints.maxHeight - 12,
            minWidth: constraints.maxWidth,
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: _OfflineDetailSurface(
              glass: true,
              child: DefaultTextStyle(
                style: _mutedStyle(context, 15),
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottom),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        key: const ValueKey('gift-address-grabber'),
                        padding: const EdgeInsets.only(top: 10),
                        child: _sheetGrabber(context, bottomSpacing: 6),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 0, 10, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '收货地址',
                                      style: _titleStyle(
                                        context,
                                        18,
                                      ).copyWith(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  // Loading must not add height to the form:
                                  // the content-sized sheet would jump on completion.
                                  if (_addressLoading)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: Semantics(
                                        label: '正在加载收货地址',
                                        child:
                                            const CupertinoActivityIndicator(),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (_hasSavedAddress)
                              CupertinoButton(
                                key: const ValueKey('gift-address-delete'),
                                onPressed: busy ? null : _delete,
                                child: const Icon(
                                  CupertinoIcons.trash,
                                  semanticLabel: '删除收货地址',
                                  size: 20,
                                  color: CupertinoColors.systemRed,
                                ),
                              )
                            else
                              const SizedBox(height: 44),
                          ],
                        ),
                      ),
                      Flexible(
                        fit: FlexFit.loose,
                        child: SingleChildScrollView(
                          key: const ValueKey('gift-address-scroll'),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.manual,
                          padding: const EdgeInsets.fromLTRB(22, 0, 22, 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_addressError != null)
                                _OfflineErrorBlock(
                                  message: _addressError!,
                                  onRetry: _loadAddress,
                                ),
                              AbsorbPointer(
                                absorbing: busy,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _AddressField(
                                      label: '收件人',
                                      controller: _name,
                                      focusNode: _nameFocus,
                                      textInputAction: TextInputAction.next,
                                      onSubmitted: (_) =>
                                          _phoneFocus.requestFocus(),
                                    ),
                                    _AddressField(
                                      label: '手机号',
                                      controller: _phone,
                                      focusNode: _phoneFocus,
                                      keyboardType: TextInputType.phone,
                                      textInputAction: TextInputAction.done,
                                      onSubmitted: (_) =>
                                          FocusScope.of(context).unfocus(),
                                    ),
                                    _AddressSelectField(
                                      label: '省份',
                                      value: _province,
                                      placeholder: _regionsLoading
                                          ? '地址数据加载中...'
                                          : '选择省份',
                                      onTap: _selectProvince,
                                    ),
                                    _AddressSelectField(
                                      label: '所在城市',
                                      value: _city,
                                      placeholder: _regionsLoading
                                          ? '地址数据加载中...'
                                          : (_province == null
                                                ? '请先选择省份'
                                                : '选择城市'),
                                      onTap: _selectCity,
                                    ),
                                    _AddressSelectField(
                                      label: '所在地区',
                                      value: _district,
                                      placeholder: _regionsLoading
                                          ? '地址数据加载中...'
                                          : (_city == null ? '请先选择城市' : '选择地区'),
                                      onTap: _selectDistrict,
                                    ),
                                    _AddressField(
                                      label: '详细地址',
                                      controller: _detail,
                                      textInputAction: TextInputAction.done,
                                      onSubmitted: (_) =>
                                          FocusScope.of(context).unfocus(),
                                    ),
                                  ],
                                ),
                              ),
                              if (_operationError != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Text(
                                    _operationError!,
                                    style: _mutedStyle(context, 13).copyWith(
                                      color: CupertinoColors.systemRed,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 10),
                              _AddressSaveButton(
                                busy: _saving,
                                onPressed: busy ? null : _save,
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
          ),
        );
      },
    );
    return PopScope<void>(
      // Barrier taps use maybePop. While the IME is visible, consume that tap
      // to unfocus first; allow the next tap after the keyboard has closed.
      canPop: keyboard == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) FocusScope.of(context).unfocus();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: sheet,
      ),
    );
  }
}

/// 与打卡计划新增 sheet 的主按钮同一套设计：整宽胶囊 + 主题色填充 + 柔和投影，
/// 白字 20/w600；忙碌转圈；禁用时变淡去掉投影。礼物页主调是橙色。
class _AddressSaveButton extends StatelessWidget {
  const _AddressSaveButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    const base = _kGiftAccent;
    final enabled = onPressed != null && !busy;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size.fromHeight(52),
      borderRadius: BorderRadius.circular(999),
      onPressed: enabled ? onPressed : null,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? base : base.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(999),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: base.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(2, 8),
                  ),
                ]
              : null,
        ),
        child: busy
            ? const CupertinoActivityIndicator(color: Colors.white)
            : const Text(
                '保存地址',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
      ),
    );
  }
}

class _AddressField extends StatelessWidget {
  const _AddressField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _addressFieldLabelStyle(context)),
          const SizedBox(height: 7),
          CupertinoTextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            style: TextStyle(color: w.ink, fontSize: 15),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: w.glass,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: w.glassBorder),
            ),
          ),
        ],
      ),
    );
  }
}

/// 地址表单字段的小标签样式：统一小字号 + 次级墨色(跟天气/胶囊页一致)。
TextStyle _addressFieldLabelStyle(BuildContext context) {
  return TextStyle(
    color: _W2b.resolve(context).inkSoft,
    fontSize: 13,
    height: 1.2,
    fontWeight: FontWeight.w800,
    decoration: TextDecoration.none,
  );
}

class _AddressSelectField extends StatelessWidget {
  const _AddressSelectField({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final w = _W2b.resolve(context);
    final displayValue = value?.trim();
    final hasValue = displayValue != null && displayValue.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _addressFieldLabelStyle(context)),
          const SizedBox(height: 7),
          CupertinoButton(
            minimumSize: Size.zero,
            padding: EdgeInsets.zero,
            onPressed: onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: w.glass,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: w.glassBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      hasValue ? displayValue : placeholder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasValue ? w.ink : w.inkFaint,
                        fontSize: 15,
                        fontWeight: hasValue
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    CupertinoIcons.chevron_down,
                    size: 17,
                    color: w.inkFaint,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
