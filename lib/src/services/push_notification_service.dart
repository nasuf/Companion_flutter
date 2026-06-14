part of 'package:companion_flutter/main.dart';

class PushNotificationPayload {
  const PushNotificationPayload(this.data);

  final Map<String, dynamic> data;

  String get type => data['type']?.toString() ?? '';
  String get route => data['route']?.toString() ?? type;
  String? get triggerId => data['trigger_id']?.toString();
  String? get memoryId => data['memory_id']?.toString();
}

class PushNotificationService with WidgetsBindingObserver {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();
  static const _channel = MethodChannel('companion/push_notifications');
  static const _storage = FlutterSecureStorage();
  static const _deviceIdKey = 'push_device_id';

  final _payloadController =
      StreamController<PushNotificationPayload>.broadcast();
  PushNotificationPayload? _pendingPayload;
  CompanionApi? _api;
  AuthSession? _session;
  String? _deviceId;
  String? _token;
  String? _apnsEnvironment;
  String? _bundleId;
  String? _appVersion;
  Timer? _presenceTimer;
  final List<Timer> _registrationRetryTimers = [];
  bool _initialized = false;
  bool _foreground = true;
  bool _refreshingRegistration = false;

  Stream<PushNotificationPayload> get payloads => _payloadController.stream;

  PushNotificationPayload? takePendingPayload() {
    final payload = _pendingPayload;
    _pendingPayload = null;
    return payload;
  }

  Future<void> initialize() async {
    if (_initialized || kIsWeb || !Platform.isIOS) return;
    WidgetsBinding.instance.addObserver(this);
    _channel.setMethodCallHandler(_handleNativeCall);
    _deviceId = await _loadDeviceId();
    try {
      final initial = await _channel.invokeMapMethod<String, dynamic>(
        'takeInitialNotification',
      );
      if (initial != null) _emitPayload(Map<String, dynamic>.from(initial));
      _apnsEnvironment = await _loadApnsEnvironment();
      await _loadAppMetadata();
      final token = await _channel.invokeMethod<String>('getToken');
      if (token != null && token.isNotEmpty) {
        _token = token;
      }
    } catch (error) {
      debugPrint('[push] initialize skipped: $error');
    }
    _initialized = true;
  }

  Future<void> configure(CompanionApi api, AuthSession session) async {
    _api = api;
    _session = session;
    if (kIsWeb || !Platform.isIOS) return;
    await initialize();
    await _requestAuthorizationAndRegister();
    await _registerTokenIfReady();
    await _sendPresence();
    _startPresenceTimer();
    _scheduleRegistrationRefreshes();
  }

  void setRouteContext(AuthSession session) {
    _session = session;
    if (_foreground) unawaited(_sendPresence());
  }

  Future<void> clear() async {
    _presenceTimer?.cancel();
    _presenceTimer = null;
    _cancelRegistrationRefreshes();
    final api = _api;
    final token = _token;
    if (api != null && token != null && token.isNotEmpty) {
      try {
        await api.disablePushDevice(token: token);
      } catch (_) {
        // Best effort on logout.
      }
    }
    if (_deviceId != null) {
      await _sendPresence(foreground: false);
    }
    _api = null;
    _session = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      unawaited(_refreshRegistrationAndRegister());
      unawaited(_sendPresence(foreground: true));
      _startPresenceTimer();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _foreground = false;
      _presenceTimer?.cancel();
      _presenceTimer = null;
      unawaited(_sendPresence(foreground: false));
    }
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'apnsToken':
        final token = call.arguments?.toString() ?? '';
        if (token.isNotEmpty) {
          _token = token;
          await _registerTokenIfReady();
        }
        break;
      case 'remoteNotificationTapped':
        final args = call.arguments;
        if (args is Map) {
          _emitPayload(Map<String, dynamic>.from(args));
        }
        break;
      case 'apnsRegistrationFailed':
        debugPrint('[push] APNs registration failed: ${call.arguments}');
        break;
      default:
        break;
    }
  }

  Future<void> _requestAuthorizationAndRegister() async {
    try {
      await _channel.invokeMethod<bool>('requestAuthorizationAndRegister');
      final token = await _channel.invokeMethod<String>('getToken');
      if (token != null && token.isNotEmpty) {
        _token = token;
      }
    } catch (error) {
      debugPrint('[push] request authorization skipped: $error');
    }
  }

  Future<void> _refreshRegistrationAndRegister() async {
    if (kIsWeb || !Platform.isIOS || _api == null || _refreshingRegistration) {
      return;
    }
    _refreshingRegistration = true;
    try {
      final token = await _channel.invokeMethod<String>('refreshRegistration');
      if (token != null && token.isNotEmpty) {
        _token = token;
      }
      await _registerTokenIfReady();
    } on MissingPluginException {
      try {
        final token = await _channel.invokeMethod<String>('getToken');
        if (token != null && token.isNotEmpty) {
          _token = token;
          await _registerTokenIfReady();
        }
      } on MissingPluginException {
        debugPrint('[push] native push channel is not available');
      }
    } catch (error) {
      debugPrint('[push] refresh registration skipped: $error');
    } finally {
      _refreshingRegistration = false;
    }
  }

  void _scheduleRegistrationRefreshes() {
    _cancelRegistrationRefreshes();
    if (kIsWeb || !Platform.isIOS || _api == null) return;
    for (final delay in const [
      Duration(seconds: 2),
      Duration(seconds: 10),
      Duration(seconds: 30),
    ]) {
      _registrationRetryTimers.add(
        Timer(delay, () {
          unawaited(_refreshRegistrationAndRegister());
        }),
      );
    }
  }

  void _cancelRegistrationRefreshes() {
    for (final timer in _registrationRetryTimers) {
      timer.cancel();
    }
    _registrationRetryTimers.clear();
  }

  Future<void> _registerTokenIfReady() async {
    final api = _api;
    final token = _token;
    final deviceId = _deviceId;
    if (api == null || token == null || token.isEmpty || deviceId == null) {
      return;
    }
    try {
      _apnsEnvironment ??= await _loadApnsEnvironment();
      await api.registerPushDevice(
        token: token,
        environment:
            _apnsEnvironment ?? (kReleaseMode ? 'production' : 'sandbox'),
        deviceId: deviceId,
        bundleId: _bundleId,
        appVersion: _appVersion,
      );
    } catch (error) {
      debugPrint('[push] register device failed: $error');
    }
  }

  void _startPresenceTimer() {
    _presenceTimer?.cancel();
    if (!_foreground || _api == null || _deviceId == null) return;
    _presenceTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      unawaited(_sendPresence());
    });
  }

  Future<void> _sendPresence({bool? foreground}) async {
    final api = _api;
    final session = _session;
    final deviceId = _deviceId;
    if (api == null || session == null || deviceId == null) return;
    try {
      await api.updatePushPresence(
        deviceId: deviceId,
        foreground: foreground ?? _foreground,
        workspaceId: session.workspaceId,
        conversationId: session.conversationId,
      );
    } catch (error) {
      debugPrint('[push] presence update failed: $error');
    }
  }

  Future<String> _loadDeviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final generated =
        'ios-${DateTime.now().microsecondsSinceEpoch}-${math.Random().nextInt(1 << 32)}';
    await _storage.write(key: _deviceIdKey, value: generated);
    return generated;
  }

  Future<String> _loadApnsEnvironment() async {
    try {
      final nativeEnvironment = await _channel.invokeMethod<String>(
        'apnsEnvironment',
      );
      if (nativeEnvironment == 'production') return 'production';
      if (nativeEnvironment == 'development') return 'sandbox';
    } on MissingPluginException {
      debugPrint('[push] native push channel is not available');
    } catch (error) {
      debugPrint('[push] APNs environment fallback: $error');
    }
    return kReleaseMode ? 'production' : 'sandbox';
  }

  Future<void> _loadAppMetadata() async {
    try {
      final metadata = await _channel.invokeMapMethod<String, dynamic>(
        'appMetadata',
      );
      _bundleId = metadata?['bundle_id']?.toString();
      _appVersion = metadata?['app_version']?.toString();
    } on MissingPluginException {
      debugPrint('[push] native push channel is not available');
    } catch (error) {
      debugPrint('[push] app metadata unavailable: $error');
    }
  }

  void _emitPayload(Map<String, dynamic> payload) {
    final parsed = PushNotificationPayload(payload);
    _pendingPayload = parsed;
    _payloadController.add(parsed);
  }
}
