part of 'package:companion_flutter/main.dart';

@pragma('vm:entry-point')
void _checkinNotificationTapBackground(NotificationResponse response) {
  CheckinNotificationService.instance._handleNotificationResponse(response);
}

class CheckinNotificationPayload {
  const CheckinNotificationPayload({required this.triggerId, this.memoryId});

  final String triggerId;
  final String? memoryId;

  factory CheckinNotificationPayload.fromJson(Map<String, dynamic> json) {
    return CheckinNotificationPayload(
      triggerId: json['trigger_id']?.toString() ?? '',
      memoryId: json['memory_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': 'checkin_reminder',
    'trigger_id': triggerId,
    if (memoryId != null && memoryId!.isNotEmpty) 'memory_id': memoryId,
  };
}

class CheckinNotificationService {
  CheckinNotificationService._();

  static final CheckinNotificationService instance =
      CheckinNotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final _payloadController =
      StreamController<CheckinNotificationPayload>.broadcast();
  CheckinNotificationPayload? _pendingPayload;
  bool _initialized = false;

  Stream<CheckinNotificationPayload> get payloads => _payloadController.stream;

  CheckinNotificationPayload? takePendingPayload() {
    final payload = _pendingPayload;
    _pendingPayload = null;
    return payload;
  }

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: darwin),
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          _checkinNotificationTapBackground,
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final response = launchDetails?.notificationResponse;
    if ((launchDetails?.didNotificationLaunchApp ?? false) &&
        response != null) {
      _handleNotificationResponse(response);
    }

    await _requestPermissions();
    _initialized = true;
  }

  Future<void> _requestPermissions() async {
    if (Platform.isIOS || Platform.isMacOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      await _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }
  }

  Future<void> syncReminders(List<ReminderItem> items) async {
    if (!_initialized || kIsWeb) return;
    final desiredIds = <int>{};
    for (final item in items) {
      if (_shouldSchedule(item)) {
        desiredIds.addAll(_notificationIdsForItem(item));
        await scheduleReminder(item);
      } else {
        await cancelReminderItem(item);
      }
    }
    await _cancelStaleCheckinNotifications(desiredIds);
  }

  Future<void> scheduleReminder(ReminderItem item) async {
    if (!_initialized || kIsWeb) return;
    await cancelReminderItem(item);
    if (!_shouldSchedule(item)) return;

    if (item.isHabit && item.habitWeekdays.isNotEmpty) {
      for (final weekday in item.habitWeekdays) {
        await _scheduleWeeklyReminder(item, weekday);
      }
      return;
    }

    final scheduledAt = item.triggerTime.toLocal();
    if (!scheduledAt.isAfter(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id: _notificationId(_scheduleKey(item), 'once'),
      scheduledDate: tz.TZDateTime.from(scheduledAt, tz.local),
      title: _notificationTitle(item),
      body: _notificationBody(item),
      payload: jsonEncode(
        CheckinNotificationPayload(
          triggerId: item.id,
          memoryId: item.memoryId,
        ).toJson(),
      ),
      notificationDetails: _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> _scheduleWeeklyReminder(ReminderItem item, int weekday) async {
    final scheduledAt = _nextWeeklyLocalTime(
      item.triggerTime.toLocal(),
      weekday,
      item.completedDates.toSet(),
    );
    await _plugin.zonedSchedule(
      id: _notificationId(_scheduleKey(item), 'weekday-$weekday'),
      scheduledDate: tz.TZDateTime.from(scheduledAt, tz.local),
      title: _notificationTitle(item),
      body: _notificationBody(item),
      payload: jsonEncode(
        CheckinNotificationPayload(
          triggerId: item.id,
          memoryId: item.memoryId,
        ).toJson(),
      ),
      notificationDetails: _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  Future<void> cancelReminder(String reminderId) async {
    if (!_initialized || kIsWeb) return;
    await _plugin.cancel(id: _notificationId(reminderId, 'once'));
    for (var weekday = 1; weekday <= 7; weekday += 1) {
      await _plugin.cancel(id: _notificationId(reminderId, 'weekday-$weekday'));
    }
  }

  Future<void> cancelReminderItem(ReminderItem item) {
    return cancelReminder(_scheduleKey(item));
  }

  List<int> _notificationIdsForItem(ReminderItem item) {
    final key = _scheduleKey(item);
    if (item.isHabit && item.habitWeekdays.isNotEmpty) {
      return item.habitWeekdays
          .map((weekday) => _notificationId(key, 'weekday-$weekday'))
          .toList();
    }
    return [_notificationId(key, 'once')];
  }

  Future<void> _cancelStaleCheckinNotifications(Set<int> desiredIds) async {
    final pending = await _plugin.pendingNotificationRequests().catchError((_) {
      return <PendingNotificationRequest>[];
    });
    for (final request in pending) {
      if (desiredIds.contains(request.id)) continue;
      if (!_isCheckinPayload(request.payload)) continue;
      await _plugin.cancel(id: request.id);
    }
  }

  bool _isCheckinPayload(String? payload) {
    if (payload == null || payload.isEmpty) return false;
    try {
      final json = jsonDecode(payload);
      return json is Map<String, dynamic> && json['type'] == 'checkin_reminder';
    } catch (_) {
      return false;
    }
  }

  bool _shouldSchedule(ReminderItem item) {
    if (item.summary.trim().isEmpty) return false;
    if (item.status == 'cancelled') return false;
    if (item.completedAt != null && !item.isHabit) return false;
    if (!item.isHabit && !item.triggerTime.toLocal().isAfter(DateTime.now())) {
      return false;
    }
    return true;
  }

  NotificationDetails _notificationDetails() {
    const android = AndroidNotificationDetails(
      'checkin_reminders',
      '打卡提醒',
      channelDescription: '伴生打卡系统的系统通知提醒',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    );
    const darwin = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: 'checkin_reminder',
    );
    return const NotificationDetails(android: android, iOS: darwin);
  }

  String _notificationTitle(ReminderItem item) {
    return item.sentToAi ? '来自你的 AI 打卡提醒' : '伴生打卡提醒';
  }

  String _notificationBody(ReminderItem item) {
    final summary = item.summary.trim();
    if (item.sentToAi) {
      return '该做“$summary”啦，我在打卡页等你回来确认。';
    }
    return '该完成“$summary”啦，点开后可以标记完成。';
  }

  DateTime _nextWeeklyLocalTime(
    DateTime time,
    int weekday,
    Set<String> completedDates,
  ) {
    final now = DateTime.now();
    for (var offset = 0; offset < 15; offset += 1) {
      final date = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(Duration(days: offset));
      if (date.weekday != weekday) continue;
      if (completedDates.contains(_localDateKey(date))) continue;
      final candidate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (candidate.isAfter(now)) return candidate;
    }
    final fallback = List.generate(
      8,
      (index) =>
          DateTime(now.year, now.month, now.day).add(Duration(days: index + 1)),
    ).firstWhere((date) => date.weekday == weekday);
    return DateTime(
      fallback.year,
      fallback.month,
      fallback.day,
      time.hour,
      time.minute,
    );
  }

  String _localDateKey(DateTime date) {
    final local = date.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  int _notificationId(String reminderId, String suffix) {
    var hash = 0x811C9DC5;
    final input = '$reminderId:$suffix';
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  String _scheduleKey(ReminderItem item) {
    if (item.isHabit && item.memoryId != null && item.memoryId!.isNotEmpty) {
      return item.memoryId!;
    }
    return item.id;
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final json = jsonDecode(payload);
      if (json is! Map<String, dynamic> || json['type'] != 'checkin_reminder') {
        return;
      }
      final parsed = CheckinNotificationPayload.fromJson(json);
      if (parsed.triggerId.isEmpty) return;
      _pendingPayload = parsed;
      _payloadController.add(parsed);
    } catch (_) {
      return;
    }
  }
}
