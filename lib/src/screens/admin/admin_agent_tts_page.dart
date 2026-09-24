part of 'package:companion_flutter/main.dart';

class _AdminAgentTtsPage extends StatefulWidget {
  const _AdminAgentTtsPage({
    required this.api,
    required this.session,
    required this.agent,
  });

  final CompanionApi api;
  final AuthSession session;
  final _AdminAgentSummary agent;

  @override
  State<_AdminAgentTtsPage> createState() => _AdminAgentTtsPageState();
}

class _AdminAgentTtsPageState extends State<_AdminAgentTtsPage> {
  final TextEditingController _instructionController = TextEditingController();
  final TextEditingController _previewController = TextEditingController(
    text: '你好，很高兴见到你。今天想聊点什么？',
  );
  final TextEditingController _seedController = TextEditingController();
  final AudioPlayer _player = AudioPlayer();
  List<_AdminTtsVoiceProfile> _voices = const [];
  String? _voiceProfileId;
  double _rate = 1;
  double _pitch = 1;
  double _volume = 50;
  double _emotionScale = 1;
  bool _autoEmotion = true;
  String _emotion = '中性';
  double _intensity = 50;
  bool _loading = true;
  bool _saving = false;
  bool _previewing = false;
  String? _error;
  String? _notice;
  String? _previewPath;
  _AdminTtsPreview? _preview;

  static const _emotions = [
    '中性',
    '高兴',
    '悲伤',
    '愤怒',
    '惊讶',
    '恐惧',
    '厌恶',
    '焦虑',
    '失望',
    '欣慰',
    '感激',
    '戏谑',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _instructionController.dispose();
    _previewController.dispose();
    _seedController.dispose();
    unawaited(_player.dispose());
    final path = _previewPath;
    if (path != null) unawaited(_deletePreviewFile(path));
    super.dispose();
  }

  Future<void> _deletePreviewFile(String path) async {
    try {
      await File(path).delete();
    } catch (_) {}
  }

  String get _selectedVoiceName {
    for (final voice in _voices) {
      if (voice.id == _voiceProfileId) return voice.displayName;
    }
    return '请选择';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    widget.api.authToken = widget.session.token;
    try {
      final values = await Future.wait<Object>([
        widget.api.fetchAdminAgentTtsConfig(widget.agent.id),
        widget.api.fetchAdminTtsVoices(),
      ]);
      final config = values[0] as _AdminAgentTtsConfig;
      final voices = values[1] as List<_AdminTtsVoiceProfile>;
      _AdminTtsVoiceProfile? fallback;
      for (final voice in voices) {
        if (voice.enabled &&
            voice.gender == (config.gender == 'male' ? 'male' : 'female')) {
          fallback = voice;
          break;
        }
      }
      if (fallback == null) {
        for (final voice in voices) {
          if (voice.enabled) {
            fallback = voice;
            break;
          }
        }
      }
      if (!mounted) return;
      final currentVoiceIsEnabled = voices.any(
        (voice) => voice.id == config.voiceProfileId && voice.enabled,
      );
      _instructionController.text = config.instruction ?? '';
      _seedController.text = config.seed.toString();
      setState(() {
        _voices = voices;
        _voiceProfileId = currentVoiceIsEnabled
            ? config.voiceProfileId
            : fallback?.id;
        _rate = config.rate;
        _pitch = config.pitch;
        _volume = config.volume.toDouble();
        _autoEmotion = config.autoEmotion;
        _emotionScale = config.emotionScale;
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

  Map<String, dynamic>? _payload() {
    final profileId = _voiceProfileId;
    if (profileId == null || profileId.isEmpty) {
      setState(() => _error = '请选择可用音色');
      return null;
    }
    final instruction = _instructionController.text.trim();
    if (_ttsInstructionCharacters(instruction) > 100) {
      setState(() => _error = '风格指令超过 100 个计费字符');
      return null;
    }
    return {
      'voice_profile_id': profileId,
      'rate': double.parse(_rate.toStringAsFixed(2)),
      'pitch': double.parse(_pitch.toStringAsFixed(2)),
      'volume': _volume.round(),
      'seed': (int.tryParse(_seedController.text) ?? 0).clamp(0, 65535).toInt(),
      'instruction': instruction.isEmpty ? null : instruction,
      'auto_emotion': _autoEmotion,
      'emotion_scale': double.parse(_emotionScale.toStringAsFixed(2)),
    };
  }

  Future<void> _save() async {
    final payload = _payload();
    if (payload == null) return;
    setState(() {
      _saving = true;
      _error = null;
      _notice = null;
    });
    widget.api.authToken = widget.session.token;
    try {
      await widget.api.updateAdminAgentTtsConfig(widget.agent.id, payload);
      if (!mounted) return;
      setState(() => _notice = '已保存，下一条语音回复立即生效');
    } catch (error) {
      if (mounted) setState(() => _error = _asMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _previewVoice() async {
    final payload = _payload();
    final text = _previewController.text.trim();
    if (payload == null || text.isEmpty) return;
    setState(() {
      _previewing = true;
      _error = null;
      _notice = null;
    });
    widget.api.authToken = widget.session.token;
    try {
      final preview = await widget.api.previewAdminAgentTts(widget.agent.id, {
        ...payload,
        'text': text,
        'emotion': _emotion,
        'intensity': _intensity.round(),
      });
      final directory = await getTemporaryDirectory();
      final oldPath = _previewPath;
      final path =
          '${directory.path}/tts_preview_${DateTime.now().microsecondsSinceEpoch}.wav';
      await File(path).writeAsBytes(preview.bytes, flush: true);
      if (oldPath != null) {
        try {
          await File(oldPath).delete();
        } catch (_) {}
      }
      await _player.stop();
      await _player.play(DeviceFileSource(path));
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _previewPath = path;
      });
    } catch (error) {
      if (mounted) setState(() => _error = _asMessage(error));
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  Future<void> _pickVoice() async {
    final enabled = _voices.where((voice) => voice.enabled).toList();
    final value = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('选择音色'),
        actions: [
          for (final voice in enabled)
            CupertinoActionSheetAction(
              isDefaultAction: voice.id == _voiceProfileId,
              onPressed: () => Navigator.pop(context, voice.id),
              child: Text(
                '${voice.displayName} · ${voice.gender == 'male' ? '男声' : '女声'}'
                '${voice.source == 'cloned' ? ' · 复刻' : ''}',
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ),
    );
    if (value != null && mounted) setState(() => _voiceProfileId = value);
  }

  Future<void> _pickEmotion() async {
    final value = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('试听情绪'),
        actions: [
          for (final emotion in _emotions)
            CupertinoActionSheetAction(
              isDefaultAction: emotion == _emotion,
              onPressed: () => Navigator.pop(context, emotion),
              child: Text(emotion),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ),
    );
    if (value != null && mounted) setState(() => _emotion = value);
  }

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    bool integerValue = false,
    required ValueChanged<double> onChanged,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 13)),
              ),
              Text(
                value.toStringAsFixed(integerValue ? 0 : 2),
                style: const TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ],
          ),
          SizedBox(
            width: double.infinity,
            child: CupertinoSlider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _AdminScaffold(
      title: '语音配置',
      subtitle: widget.agent.name,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
                children: [
                  _AdminCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _AdminNavRow(
                          title: '音色',
                          subtitle: _selectedVoiceName,
                          onTap: _pickVoice,
                        ),
                        const SizedBox(height: 12),
                        _slider(
                          label: '语速',
                          value: _rate,
                          min: 0.5,
                          max: 2,
                          onChanged: (value) => setState(() => _rate = value),
                        ),
                        _slider(
                          label: '音调',
                          value: _pitch,
                          min: 0.5,
                          max: 2,
                          onChanged: (value) => setState(() => _pitch = value),
                        ),
                        _slider(
                          label: '音量',
                          value: _volume,
                          min: 0,
                          max: 100,
                          integerValue: true,
                          onChanged: (value) => setState(() => _volume = value),
                        ),
                        CupertinoTextField(
                          controller: _seedController,
                          placeholder: '随机种子 0–65535',
                          keyboardType: TextInputType.number,
                          onTapOutside: (_) =>
                              FocusManager.instance.primaryFocus?.unfocus(),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(5),
                          ],
                        ),
                        const SizedBox(height: 12),
                        CupertinoTextField(
                          controller: _instructionController,
                          placeholder: '风格指令（留空使用默认）',
                          minLines: 3,
                          maxLines: 5,
                          onTapOutside: (_) =>
                              FocusManager.instance.primaryFocus?.unfocus(),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_ttsInstructionCharacters(_instructionController.text)} / 100 计费字符',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                _ttsInstructionCharacters(
                                      _instructionController.text,
                                    ) >
                                    100
                                ? CupertinoColors.systemRed
                                : CupertinoColors.systemGrey,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                '自动情绪',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                            CupertinoSwitch(
                              value: _autoEmotion,
                              onChanged: (value) =>
                                  setState(() => _autoEmotion = value),
                            ),
                          ],
                        ),
                        if (_autoEmotion)
                          _slider(
                            label: '情绪强度倍率',
                            value: _emotionScale,
                            min: 0,
                            max: 2,
                            onChanged: (value) =>
                                setState(() => _emotionScale = value),
                          ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: CupertinoButton.filled(
                            onPressed: _saving ? null : _save,
                            child: Text(_saving ? '保存中...' : '保存并立即生效'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _AdminCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '即时试听',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        CupertinoTextField(
                          controller: _previewController,
                          minLines: 2,
                          maxLines: 4,
                          placeholder: '输入试听文本',
                          onTapOutside: (_) =>
                              FocusManager.instance.primaryFocus?.unfocus(),
                        ),
                        const SizedBox(height: 10),
                        if (_autoEmotion) ...[
                          _AdminNavRow(
                            title: '模拟情绪',
                            subtitle: _emotion,
                            onTap: _pickEmotion,
                          ),
                          _slider(
                            label: '模拟强度',
                            value: _intensity,
                            min: 0,
                            max: 100,
                            integerValue: true,
                            onChanged: (value) =>
                                setState(() => _intensity = value),
                          ),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: CupertinoButton(
                            color: const Color(0xFF2D73FF),
                            onPressed: _previewing ? null : _previewVoice,
                            child: Text(
                              _previewing ? '生成中...' : '生成并播放试听',
                              style: const TextStyle(
                                color: CupertinoColors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        if (_preview != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${((_preview!.durationMilliseconds ?? 0) / 1000).toStringAsFixed(2)} 秒 · '
                            '${_preview!.billableCharacters ?? 0} 字符 · '
                            '¥${(_preview!.costCny ?? 0).toStringAsFixed(6)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_notice != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _notice!,
                      style: const TextStyle(
                        color: CupertinoColors.activeGreen,
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: CupertinoColors.systemRed),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _AdminMessageBubble extends StatelessWidget {
  const _AdminMessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMine = message.isMine;
    final bubbleColor = isMine
        ? AppColors.of(context).accent
        : (isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.9));
    final textColor = isMine
        ? Colors.white
        : (isDark ? AppColors.text : const Color(0xFF12171B));
    final content = message.content.trim().isEmpty
        ? '（无文本内容）'
        : message.content;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.76,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(16),
              border: isMine
                  ? null
                  : Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0x14181F2A),
                    ),
            ),
            child: SelectableText(
              content,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            _adminDateLabel(message.createdAt.toIso8601String()),
            style: TextStyle(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.34)
                  : const Color(0x6612171B),
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminWechatBlock extends StatelessWidget {
  const _AdminWechatBlock({required this.wechat});

  final _AdminWechatIdentity? wechat;

  @override
  Widget build(BuildContext context) {
    if (wechat == null) {
      return const _AdminDetailBlock(
        title: '微信信息',
        children: [_AdminDetailLine(label: '绑定状态', value: '未绑定微信')],
      );
    }
    return _AdminDetailBlock(
      title: '微信信息',
      children: [
        _AdminDetailLine(label: '昵称', value: wechat!.nickname ?? '暂无'),
        _AdminDetailLine(label: 'OpenID', value: wechat!.openid ?? '暂无'),
        _AdminDetailLine(label: 'UnionID', value: wechat!.unionid ?? '暂无'),
        _AdminDetailLine(label: '地区', value: wechat!.location ?? '暂无'),
        _AdminDetailLine(
          label: '最近登录',
          value: _adminDateLabel(wechat!.lastLoginAt),
        ),
      ],
    );
  }
}

class _AdminDetailBlock extends StatelessWidget {
  const _AdminDetailBlock({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.62),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isDark ? AppColors.text : const Color(0xFF12171B),
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }
}

class _AdminDetailLine extends StatelessWidget {
  const _AdminDetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? const Color(0x9EEBF2EE) : AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: isDark ? AppColors.text : const Color(0xFF12171B),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminDetailWidgetLine extends StatelessWidget {
  const _AdminDetailWidgetLine({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? const Color(0x9EEBF2EE) : AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _AdminProgressDialog extends StatelessWidget {
  const _AdminProgressDialog({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: Text(title),
      content: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(
          children: [
            const CupertinoActivityIndicator(radius: 12),
            const SizedBox(height: 12),
            Text(message),
          ],
        ),
      ),
    );
  }
}
