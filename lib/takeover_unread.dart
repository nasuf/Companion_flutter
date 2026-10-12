import 'dart:async';

import 'package:flutter/widgets.dart';

import 'companion_api.dart';
import 'takeover_inbox.dart';

/// One account-scoped snapshot, shared by both admin entry points.
class TakeoverUnreadController extends ChangeNotifier
    with WidgetsBindingObserver {
  TakeoverUnreadController();
  static final instance = TakeoverUnreadController();

  CompanionApi? _api;
  bool get configured => _api != null;
  String? _adminId;
  int _generation = 0;
  int? count;
  DateTime? sampledAt;
  bool stale = false;
  bool _refreshing = false;
  bool _again = false;
  StreamSubscription<dynamic>? _events;
  Timer? _timer;

  void configure(CompanionApi api, String adminId) {
    if (_api == api && _adminId == adminId) return;
    clear();
    _api = api;
    _adminId = adminId;
    WidgetsBinding.instance.addObserver(this);
    _events = TakeoverInbox.instance.events.listen((event) {
      if (event.type != 'pong') unawaited(refresh());
    });
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(refresh());
      }
    });
    unawaited(refresh());
  }

  Future<void> refresh() async {
    final api = _api;
    if (api == null) return;
    if (_refreshing) {
      _again = true;
      return;
    }
    final generation = _generation;
    _refreshing = true;
    try {
      final result = await api.getTakeoverUnreadSummary();
      if (generation != _generation) return;
      count = result.count;
      sampledAt = result.sampledAt;
      stale = false;
    } catch (_) {
      if (generation != _generation) return;
      // A failed refresh is not a zero-message snapshot.
      stale = true;
    } finally {
      if (generation == _generation) {
        _refreshing = false;
        notifyListeners();
        if (_again) {
          _again = false;
          unawaited(refresh());
        }
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  void clear() {
    _generation++;
    _events?.cancel();
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _api = null;
    _adminId = null;
    count = null;
    sampledAt = null;
    stale = false;
    _refreshing = false;
    _again = false;
    notifyListeners();
  }

  @override
  void dispose() {
    clear();
    super.dispose();
  }
}
