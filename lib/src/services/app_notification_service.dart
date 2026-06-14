part of 'package:companion_flutter/main.dart';

enum AppNotificationSource { inApp, remotePush }

class AppNotificationEvent {
  const AppNotificationEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.route,
    required this.source,
    this.conversationId,
    this.workspaceId,
    this.messageId,
    this.triggerId,
    this.memoryId,
    this.payload = const {},
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final String route;
  final AppNotificationSource source;
  final String? conversationId;
  final String? workspaceId;
  final String? messageId;
  final String? triggerId;
  final String? memoryId;
  final Map<String, dynamic> payload;

  bool get isRemotePush => source == AppNotificationSource.remotePush;
  bool get isChat => route == 'chat' || type == 'agent_message';
  bool get isCheckin => route == 'checkin' || type == 'checkin_reminder';
  bool get isCapsule => route == 'capsules' || type == 'capsule_ready';
  bool get isAchievement =>
      route == 'achievement' || type == 'achievement_unlocked';

  factory AppNotificationEvent.fromPushPayload(PushNotificationPayload value) {
    final data = value.data;
    final type = value.type.isEmpty ? 'system_custom' : value.type;
    return AppNotificationEvent(
      id: _eventId(data, type),
      type: type,
      title: data['title']?.toString() ?? _defaultTitle(type),
      body: data['body']?.toString() ?? _defaultBody(type),
      route: value.route,
      source: AppNotificationSource.remotePush,
      conversationId: data['conversation_id']?.toString(),
      workspaceId: data['workspace_id']?.toString(),
      messageId: data['message_id']?.toString(),
      triggerId: value.triggerId,
      memoryId: value.memoryId,
      payload: data,
    );
  }

  factory AppNotificationEvent.agentMessage({
    required String text,
    required AuthSession session,
    required String eventType,
    String? messageId,
  }) {
    final trimmed = _oneLine(text);
    const type = 'agent_message';
    final data = {
      'type': type,
      'route': 'chat',
      'conversation_id': session.conversationId,
      'workspace_id': session.workspaceId,
      'agent_id': session.agentId,
      'message_id': messageId,
      'origin': eventType == 'proactive' ? 'proactive' : 'reply',
    };
    return AppNotificationEvent(
      id: messageId?.isNotEmpty == true
          ? messageId!
          : 'agent-${DateTime.now().microsecondsSinceEpoch}',
      type: type,
      title: session.agentName?.trim().isNotEmpty == true
          ? session.agentName!.trim()
          : '伴生',
      body: trimmed.isEmpty ? '你收到了一条新消息' : trimmed,
      route: 'chat',
      source: AppNotificationSource.inApp,
      conversationId: session.conversationId,
      workspaceId: session.workspaceId,
      messageId: messageId,
      payload: data,
    );
  }

  static String _eventId(Map<String, dynamic> data, String type) {
    final explicit =
        data['notification_id'] ??
        data['message_id'] ??
        data['trigger_id'] ??
        data['memory_id'];
    final value = explicit?.toString();
    if (value != null && value.isNotEmpty) return value;
    return '$type-${DateTime.now().microsecondsSinceEpoch}';
  }

  static String _defaultTitle(String type) {
    return switch (type) {
      'achievement_unlocked' => '成就达成',
      'capsule_ready' => '时间胶囊可以开启了',
      'checkin_reminder' => '伴生打卡提醒',
      'agent_message' => '伴生',
      _ => '系统通知',
    };
  }

  static String _defaultBody(String type) {
    return switch (type) {
      'achievement_unlocked' => '你解锁了一个新成就',
      'capsule_ready' => '今天有时间胶囊可以开启了',
      'checkin_reminder' => '该完成今天的打卡啦',
      'agent_message' => '你收到了一条新消息',
      _ => '你收到了一条通知',
    };
  }

  static String _oneLine(String value) {
    final compact = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (compact.length <= 76) return compact;
    return '${compact.substring(0, 75)}…';
  }
}

class AppNotificationService {
  AppNotificationService._();

  static final AppNotificationService instance = AppNotificationService._();

  final _events = StreamController<AppNotificationEvent>.broadcast();
  AppNotificationEvent? _pending;
  bool _initialized = false;

  Stream<AppNotificationEvent> get events => _events.stream;

  void initialize() {
    if (_initialized) return;
    _initialized = true;
    PushNotificationService.instance.payloads.listen((payload) {
      emit(AppNotificationEvent.fromPushPayload(payload), remember: true);
    });
    final pendingPush = PushNotificationService.instance.takePendingPayload();
    if (pendingPush != null) {
      emit(AppNotificationEvent.fromPushPayload(pendingPush), remember: true);
    }
  }

  AppNotificationEvent? takePendingEvent() {
    final event = _pending;
    _pending = null;
    return event;
  }

  void emit(AppNotificationEvent event, {bool remember = false}) {
    if (remember && !_events.hasListener) _pending = event;
    _events.add(event);
  }

  void emitAgentMessage({
    required String text,
    required AuthSession session,
    required String eventType,
    String? messageId,
  }) {
    emit(
      AppNotificationEvent.agentMessage(
        text: text,
        session: session,
        eventType: eventType,
        messageId: messageId,
      ),
    );
  }
}
