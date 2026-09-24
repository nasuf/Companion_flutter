part of 'package:companion_flutter/main.dart';

/// 个人资料二级页 —— 头像与昵称在这里编辑。
///
/// 改完必须把新 session 通过 [onSessionChanged] 冒泡到 auth_gate: 用户头像除了
/// 这一页，还被顶部关系头图和各棋类对局页读取，只改本页 state 会让它们停在旧值
/// 直到下次冷启动。
class _ProfileInfoPage extends StatefulWidget {
  const _ProfileInfoPage({
    required this.api,
    required this.session,
    required this.onSessionChanged,
  });

  final CompanionApi api;
  final AuthSession session;
  final ValueChanged<AuthSession> onSessionChanged;

  @override
  State<_ProfileInfoPage> createState() => _ProfileInfoPageState();
}

class _ProfileInfoPageState extends State<_ProfileInfoPage> {
  /// 与服务端 `models/user.py: MAX_DISPLAY_NAME_LENGTH` 一致。输入框先挡一道，
  /// 服务端超长只会回 422 的原始校验体，用户看了没法理解。
  static const _maxNicknameLength = 32;

  final _imagePicker = ImagePicker();
  final _nicknameController = TextEditingController();
  bool _busy = false;
  String? _error;

  /// 本页自己持有一份 session。这一页是 push 出来的路由，父级 rebuild 不会重建
  /// 它 —— 只回传给 auth_gate 的话，本页的头像和昵称会停在改动前的值。
  late AuthSession _session = widget.session;

  @override
  void didUpdateWidget(covariant _ProfileInfoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) _session = widget.session;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    if (_busy) return;
    final source = await showCupertinoModalPopup<ImageSource>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(ImageSource.camera),
            child: const Text('拍照'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
            child: const Text('从相册选择'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ),
    );
    if (source == null || !mounted) return;
    await _pickAndUploadAvatar(source);
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    // 取图和上传分开 catch：权限被拒和服务端拒绝是两回事，混在一起会给出"需要
    // 相机权限"这种和实际原因无关的提示。
    final XFile? picked;
    final Uint8List bytes;
    try {
      // 1024 比聊天图的 1600 更小: 头像最终只存 512²，取一倍余量给裁剪留下
      // 放大空间，再大就只是白白拉长上传时间。
      picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      bytes = await picked.readAsBytes();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is MissingPluginException
            ? '图片功能需要完整重启 App 后才能使用。'
            : source == ImageSource.camera
            ? '打不开相机，请检查系统里的相机权限。'
            : '读不到这张图片，请检查系统里的相册权限。';
      });
      return;
    }

    if (!mounted) return;
    final crop = await Navigator.of(context).push<AvatarCropRect>(
      CompanionPageRoute<AvatarCropRect>(
        builder: (_) => AvatarCropPage(imageBytes: bytes),
      ),
    );
    if (crop == null || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      widget.api.authToken = _session.token;
      _applyResult(
        await widget.api.uploadUserAvatar(
          bytes: bytes,
          mime: picked.mimeType ?? _imageMimeFromPath(picked.path),
          crop: crop,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _asMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editNickname() async {
    if (_busy) return;
    // controller 归本页所有而不是每次新建：弹窗 pop 之后还有一段退场动画，
    // 那期间 CupertinoTextField 仍然挂在树上，就地 dispose 会抛"used after
    // being disposed"。
    _nicknameController.text = _session.displayNameOr('');
    final name = await showCupertinoDialog<String>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('修改昵称'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: _nicknameController,
            autofocus: true,
            maxLength: _maxNicknameLength,
            placeholder: '想让 TA 怎么称呼你',
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () =>
                Navigator.of(context).pop(_nicknameController.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    final trimmed = name?.trim();
    if (trimmed == null || !mounted) return;
    if (trimmed.isEmpty) {
      setState(() => _error = '昵称不能为空。');
      return;
    }
    if (trimmed == _session.userDisplayName?.trim()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      widget.api.authToken = _session.token;
      _applyResult(await widget.api.updateUserDisplayName(trimmed));
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _asMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _applyResult(UserProfileUpdateResult result) {
    if (!mounted) return;
    final updated = _session.copyWith(
      userDisplayName: result.displayName,
      userAvatarUrl: result.avatarUrl,
    );
    setState(() {
      _session = updated;
      _error = null;
    });
    widget.onSessionChanged(updated);
  }

  String _imageMimeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _copyUserId() async {
    await Clipboard.setData(ClipboardData(text: _session.userId));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('用户ID 已复制'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 1200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _session.displayNameOr('小星辰');
    final error = _error;
    return _SettingsSubScaffold(
      title: '个人资料',
      child: _SubPageContent(
        children: [
          _SubCard(
            children: [
              _SubCardRow(
                label: '头像',
                onTap: _busy ? null : _pickAvatar,
                trailing: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_busy)
                        const Padding(
                          padding: EdgeInsets.only(right: 10),
                          child: CupertinoActivityIndicator(radius: 8),
                        ),
                      _SettingsAvatarImage(
                        assetPath: 'assets/prototype/user-avatar-shanmu.jpg',
                        imageUrl: _session.userAvatarUrl,
                        accent: _SettingsColors.blueDark,
                      ),
                      const SizedBox(width: 6),
                      const _SettingsArrow(),
                    ],
                  ),
                ),
              ),
              _SubCardRow(
                label: '昵称',
                value: '$displayName ›',
                onTap: _busy ? null : _editNickname,
              ),
              // 原本这里是「登录账号」(wx_89b939bc004 之类的内部 hash) —— 对用户
              // 零信息量。换成账号类型, 数据来自服务端早就在发的 phone /
              // wechat_bound (AuthResponse 里那两个字段的注释写的就是 "for the
              // account-settings UI")。
              _SubCardRow(
                label: '账号类型',
                trailing: _LoginMethodBadges(methods: _session.loginMethods),
              ),
              _SubCardRow(
                label: '用户ID',
                // 只显示前 8 位: 完整 uuid 36 字符会把标签挤掉。点一下复制完整值 ——
                // 昵称现在可改且不唯一, 反馈问题时这串是唯一能定位账号的东西。
                value: '${_session.userId.split('-').first}… 复制',
                onTap: _copyUserId,
                showDivider: false,
              ),
            ],
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                error,
                style: TextStyle(color: _SettingsColors.red, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}

class _AiAppearancePage extends StatelessWidget {
  const _AiAppearancePage({required this.agentName, this.agentAvatarUrl});

  final String agentName;
  final String? agentAvatarUrl;

  @override
  Widget build(BuildContext context) {
    return _SettingsSubScaffold(
      title: '$agentName形象',
      child: _SubPageContent(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 18),
              child: _SettingsAvatarImage(
                assetPath: 'assets/prototype/agent-avatar.png',
                imageUrl: agentAvatarUrl,
                accent: _SettingsColors.orangeDark,
              ),
            ),
          ),
          _SubCard(
            children: [
              _SubCardRow(label: '名称', value: agentName),
              _SubCardRow(
                label: '头像来源',
                value: agentAvatarUrl?.trim().isNotEmpty == true
                    ? '后台头像'
                    : '默认头像',
              ),
              const _SubCardRow(
                label: '形象编辑',
                value: '等待素材与保存接口',
                showDivider: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BackpackPage extends StatefulWidget {
  const _BackpackPage({required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_BackpackPage> createState() => _BackpackPageState();
}

class _BackpackPageState extends State<_BackpackPage> {
  late Future<StoreInventoryResponse> _future;
  _BackpackFilter _selectedFilter = _BackpackFilter.all;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<StoreInventoryResponse> _load() => widget.api.listStoreInventory();

  void _retry() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StoreInventoryResponse>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final inventory = {
          for (final item in data?.items ?? const <StoreInventoryItem>[])
            if (item.productKind.isNotEmpty && item.quantity > 0)
              item.productKind: item,
        };
        final ownedProducts = [
          for (final kind in inventory.keys)
            _productForKind(kind) ??
                _StoreProduct(
                  title: kind,
                  subtitle: '已下架',
                  productKind: kind,
                  memberPrice: 0,
                  listPrice: 0,
                ),
        ];
        final visibleProducts = _selectedFilter.category == null
            ? ownedProducts
            : ownedProducts
                  .where((item) => item.category == _selectedFilter.category)
                  .toList();
        final totalCount = ownedProducts.fold<int>(
          0,
          (sum, product) => sum + inventory[product.productKind]!.quantity,
        );
        return _SettingsSubScaffold(
          title: '我的背包',
          trailing: Text(
            snapshot.connectionState == ConnectionState.done
                ? '共$totalCount件'
                : '同步中',
            style: TextStyle(
              color: _SettingsColors.tertiary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
          child: Builder(
            builder: (context) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Center(
                  child: CupertinoActivityIndicator(
                    color: _SettingsColors.blueDark,
                  ),
                );
              }
              if (snapshot.hasError) {
                return _SubPageContent(
                  center: true,
                  children: [
                    Text(
                      '背包同步失败：${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _SettingsColors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    CupertinoButton(
                      color: _SettingsColors.blueDark,
                      borderRadius: BorderRadius.circular(14),
                      onPressed: _retry,
                      child: const Text('重新同步'),
                    ),
                  ],
                );
              }
              return _SubPageContent(
                children: [
                  _StoreSegmentedLabelBar<_BackpackFilter>(
                    values: _BackpackFilter.values,
                    selected: _selectedFilter,
                    labelFor: (filter) => filter.label,
                    onSelected: (filter) {
                      setState(() => _selectedFilter = filter);
                    },
                  ),
                  const SizedBox(height: 12),
                  if (visibleProducts.isEmpty)
                    _SubCard(
                      padding: const EdgeInsets.fromLTRB(20, 34, 20, 34),
                      children: [
                        Text(
                          totalCount == 0 ? '还没有获得物品' : '这个分类还没有物品',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _SettingsColors.tertiary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                            height: 1.5,
                          ),
                        ),
                      ],
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: visibleProducts.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.82,
                          ),
                      itemBuilder: (context, index) {
                        final product = visibleProducts[index];
                        final item = inventory[product.productKind]!;
                        return _ExchangeProductCard(
                          product: product,
                          affordable: true,
                          compact: true,
                          showPrice: false,
                          quantity: item.quantity,
                          expiresAt: item.expiresAt,
                          isGift: item.isGift,
                        );
                      },
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

enum _BackpackFilter {
  all('全部', null),
  gift('礼物', _ExchangeCategory.gift),
  blind('盲盒', _ExchangeCategory.blind),
  outfit('装扮', _ExchangeCategory.outfit),
  bundle('礼包', _ExchangeCategory.bundle);

  const _BackpackFilter(this.label, this.category);

  final String label;
  final _ExchangeCategory? category;
}

class _NotificationSettingsPage extends StatefulWidget {
  const _NotificationSettingsPage({required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<_NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<_NotificationSettingsPage> {
  bool _messageEnabled = true;
  bool _busy = false;

  Future<void> _toggleMessageNotifications(bool enabled) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (enabled) {
        await PushNotificationService.instance.configure(
          widget.api,
          widget.session,
        );
      } else {
        await PushNotificationService.instance.clear();
      }
      if (!mounted) return;
      setState(() => _messageEnabled = enabled);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(enabled ? '已开启新消息提醒' : '已关闭新消息提醒'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1200),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('通知设置失败：$error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsSubScaffold(
      title: '通知设置',
      child: _SubPageContent(
        children: [
          _SubCard(
            children: [
              _SubCardRow(
                label: '新消息提醒',
                trailing: CupertinoSwitch(
                  value: _messageEnabled,
                  activeTrackColor: _SettingsColors.blueDark,
                  onChanged: _busy ? null : _toggleMessageNotifications,
                ),
              ),
              _SubCardRow(
                label: '提醒状态',
                value: _busy
                    ? '同步中'
                    : (_messageEnabled ? '声音 · 振动 · 通知栏' : '已关闭'),
              ),
              const _SubCardRow(
                label: '提示铃声',
                value: '系统默认',
                showDivider: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubTitle extends StatelessWidget {
  const _SubTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          color: _SettingsColors.text,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _PrivacySecurityPage extends StatefulWidget {
  const _PrivacySecurityPage({
    required this.api,
    required this.session,
    this.initialStats,
    required this.onDeleteFriend,
  });

  final CompanionApi api;
  final AuthSession session;
  final ProfileStats? initialStats;
  final VoidCallback onDeleteFriend;

  @override
  State<_PrivacySecurityPage> createState() => _PrivacySecurityPageState();
}

class _PrivacySecurityPageState extends State<_PrivacySecurityPage> {
  ProfileStats? _stats;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _stats = widget.initialStats;
    _refreshStats();
  }

  Future<void> _refreshStats() async {
    if (widget.session.agentId == null || widget.session.agentId!.isEmpty) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      widget.api.authToken = widget.session.token;
      final stats = await widget.api.fetchProfileStats(
        workspaceId: widget.session.workspaceId,
      );
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _asMessage(error);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final messageCount = _stats?.messageCount;
    final messageLabel = _loading
        ? '同步中...'
        : messageCount == null
        ? (_error == null ? '--' : '暂不可用')
        : '$messageCount 条';
    return _SettingsSubScaffold(
      title: '隐私与安全中心',
      child: _SubPageContent(
        children: [
          _SubCard(
            children: [
              const _SubSectionHeader('绑定信息'),
              _SubCardRow(
                label: '绑定手机',
                value: _maskedPhone(widget.session.username),
              ),
              const _SubCardRow(label: '绑定微信', value: '未绑定 ›'),
              const _SubCardRow(
                label: '绑定邮箱',
                value: '未绑定 ›',
                showDivider: false,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _SubCard(
            children: [
              _SubSectionHeader('实名认证'),
              _SubCardRow(label: '认证状态', value: '未认证'),
              _SubCardRow(label: '姓名', value: '未填写'),
              _SubCardRow(label: '身份证号', value: '未填写', showDivider: false),
            ],
          ),
          const SizedBox(height: 12),
          const _SubCard(
            children: [
              _SubSectionHeader('适龄验证'),
              _SubCardRow(label: '适龄状态', value: '成年人（18+）', showDivider: false),
            ],
          ),
          const SizedBox(height: 12),
          _SubCard(
            children: [
              const _SubSectionHeader('聊天记录管理'),
              _SubCardRow(
                label: '当前消息数',
                value: messageLabel,
                showDivider: false,
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: _SettingsColors.red, fontSize: 12),
            ),
          ],
          const SizedBox(height: 24),
          _SettingsActionButton(
            label: '删除好友',
            destructive: true,
            enabled:
                widget.session.agentId != null &&
                widget.session.agentId!.isNotEmpty,
            onTap: widget.onDeleteFriend,
          ),
          const SizedBox(height: 10),
          _SettingsActionButton(
            label: '注销账号',
            destructive: true,
            enabled: false,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  static String _maskedPhone(String username) {
    final digits = username.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7) return '未绑定 ›';
    return '${digits.substring(0, 3)}****${digits.substring(digits.length - 4)} ›';
  }
}

class _CacheCleanupPage extends StatefulWidget {
  const _CacheCleanupPage();

  @override
  State<_CacheCleanupPage> createState() => _CacheCleanupPageState();
}

class _CacheCleanupPageState extends State<_CacheCleanupPage> {
  late Future<int> _sizeFuture = _loadCacheSize();
  bool _cleaning = false;

  Future<int> _loadCacheSize() async {
    var total = 0;
    total += PaintingBinding.instance.imageCache.currentSizeBytes;
    final dirs = <Directory>[];
    try {
      dirs.add(await getTemporaryDirectory());
    } catch (_) {}
    try {
      dirs.add(await getApplicationCacheDirectory());
    } catch (_) {}
    for (final dir in dirs) {
      total += await _directorySize(dir);
    }
    return total;
  }

  Future<int> _directorySize(Directory directory) async {
    if (!await directory.exists()) return 0;
    var total = 0;
    try {
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return total;
  }

  Future<void> _clearCache() async {
    if (_cleaning) return;
    setState(() => _cleaning = true);
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    try {
      await DefaultCacheManager().emptyCache();
    } catch (_) {}
    final dirs = <Directory>[];
    try {
      dirs.add(await getTemporaryDirectory());
    } catch (_) {}
    try {
      dirs.add(await getApplicationCacheDirectory());
    } catch (_) {}
    for (final dir in dirs) {
      if (!await dir.exists()) continue;
      try {
        await for (final entity in dir.list()) {
          await entity.delete(recursive: true);
        }
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _cleaning = false;
      _sizeFuture = _loadCacheSize();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('缓存已清理'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 1200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsSubScaffold(
      title: '缓存清理',
      child: FutureBuilder<int>(
        future: _sizeFuture,
        builder: (context, snapshot) {
          final sizeLabel = snapshot.hasData
              ? _formatBytes(snapshot.data!)
              : '计算中';
          return _SubPageContent(
            children: [
              _SubCard(
                children: [
                  _SubCardRow(label: '缓存大小', value: sizeLabel),
                  _SubCardRow(
                    label: _cleaning ? '清理中' : '清理缓存',
                    value: '›',
                    showDivider: false,
                    onTap: _cleaning ? null : _clearCache,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  '仅清理本机图片与临时文件，不会删除服务端聊天记录',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _SettingsColors.isDark
                        ? _SettingsColors.tertiary
                        : const Color(0xFF999999),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)}KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)}MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(1)}GB';
  }
}
