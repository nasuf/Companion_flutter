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

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _name = TextEditingController(text: initial?.recipientName ?? '');
    _phone = TextEditingController(text: initial?.phone ?? '');
    _province = _emptyToNull(initial?.province);
    _city = _emptyToNull(initial?.city);
    _district = _emptyToNull(initial?.district);
    _detail = TextEditingController(text: initial?.detail ?? '');
    _loadRegions();
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

  Future<void> _save() async {
    final validationError = _validateAddress();
    if (validationError != null) {
      await _showAddressError(validationError);
      return;
    }
    setState(() => _saving = true);
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
    return _BottomSheetFrame(
      // 玻璃底色，让下面的玻璃输入框/下拉框衬出来(参考打卡计划新增 sheet)。
      backgroundColor: _W2b.resolve(context).base,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetGrabber(context),
          Text('收货地址', style: _titleStyle(context, 20)),
          const SizedBox(height: 16),
          _AddressField(
            label: '收件人',
            controller: _name,
            focusNode: _nameFocus,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _phoneFocus.requestFocus(),
          ),
          _AddressField(
            label: '手机号',
            controller: _phone,
            focusNode: _phoneFocus,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
          ),
          _AddressSelectField(
            label: '省份',
            value: _province,
            placeholder: _regionsLoading ? '地址数据加载中...' : '选择省份',
            onTap: _selectProvince,
          ),
          _AddressSelectField(
            label: '所在城市',
            value: _city,
            placeholder: _regionsLoading
                ? '地址数据加载中...'
                : (_province == null ? '请先选择省份' : '选择城市'),
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
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
          ),
          const SizedBox(height: 10),
          // 参考打卡计划新增 sheet 的主按钮(_CheckinPrimaryButton)：整宽胶囊、
          // 主题蓝填充 + 柔和投影、白字 20/w600、忙碌显示转圈、禁用变淡。
          _AddressSaveButton(busy: _saving, onPressed: _saving ? null : _save),
        ],
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
