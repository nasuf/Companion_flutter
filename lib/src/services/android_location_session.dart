import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

/// A foreground owner of Android's bounded, shared location acquisition.
/// iOS never opens this channel or changes its existing geolocator policy.
class AndroidLocationSession {
  AndroidLocationSession() : _precise = true;
  AndroidLocationSession.chat() : _precise = false;
  final bool _precise;
  static const channel = MethodChannel('companion/foreground_location');
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static int _sequence = 0;
  static final _pending = <bool, _Read>{};
  static Position? _cached;
  bool _closed = false;
  final _onClose = Completer<void>();

  Future<T> _whileOpen<T>(Future<T> operation) => Future.any<T>([
    operation,
    _onClose.future.then<T>((_) => throw StateError('Location session closed')),
  ]).timeout(const Duration(seconds: 2));

  bool get closed => _closed;

  Future<void> prewarm() async {
    if (!supported || _closed) return;
    try {
      final permission = await _whileOpen(Geolocator.checkPermission());
      if (_closed ||
          (permission != LocationPermission.whileInUse &&
              permission != LocationPermission.always)) {
        return;
      }
      if (!await _whileOpen(Geolocator.isLocationServiceEnabled()) || _closed) {
        return;
      }
      await read();
    } catch (_) {
      // Speculative acquisition never prompts, writes a profile or shows UI.
    }
  }

  Future<Position> read({bool fresh = false}) async {
    if (_closed) throw StateError('Location session closed');
    final cached = _cached;
    if (!fresh && cached != null && _usable(cached, precise: _precise)) {
      return cached;
    }
    var read = _pending[_precise];
    if (read == null) {
      final id = ++_sequence;
      read = _Read(id, _precise);
      _pending[_precise] = read;
      read.future = _acquire(read, fresh: fresh);
    }
    read.owners.add(this);
    final position = await read.future;
    if (_closed) throw StateError('Location session closed');
    return position;
  }

  static bool _usable(Position p, {required bool precise}) {
    final age = DateTime.now().difference(p.timestamp);
    return p.latitude.isFinite &&
        p.latitude.abs() <= 90 &&
        p.longitude.isFinite &&
        p.longitude.abs() <= 180 &&
        p.accuracy.isFinite &&
        p.accuracy > 0 &&
        (!precise || p.accuracy <= 100) &&
        !age.isNegative &&
        age <= const Duration(seconds: 15);
  }

  static Future<Position> _acquire(_Read read, {required bool fresh}) async {
    try {
      final raw = await Future.any<Map<String, dynamic>?>([
        channel.invokeMapMethod<String, dynamic>('read', {
          'id': read.id,
          'fresh': fresh,
          'precise': read.precise,
        }),
        read.cancelled.future.then<Map<String, dynamic>?>(
          (_) => throw StateError('Location cancelled'),
        ),
      ]).timeout(const Duration(seconds: 9));
      if (raw == null) throw StateError('Position unavailable');
      final position = Position.fromMap(raw);
      if (!_usable(position, precise: read.precise)) {
        throw StateError('Invalid position');
      }
      if (identical(_pending[read.precise], read)) _cached = position;
      return position;
    } on PlatformException catch (error) {
      if (error.code == 'timeout') throw TimeoutException('Location deadline');
      if (error.code == 'permission_denied') {
        throw PermissionDeniedException('Location permission');
      }
      if (error.code == 'service_disabled') {
        throw const LocationServiceDisabledException();
      }
      rethrow;
    } finally {
      if (identical(_pending[read.precise], read)) {
        _pending.remove(read.precise);
      }
      unawaited(_cancel(read.id));
    }
  }

  static Future<void> _cancel(int id) async {
    try {
      await channel.invokeMethod<void>('cancel', {'id': id});
    } catch (_) {}
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _onClose.complete();
    final read = _pending[_precise];
    if (read == null) return;
    read.owners.remove(this);
    if (read.owners.isEmpty) {
      _pending.remove(_precise);
      read.cancelled.complete();
      unawaited(_cancel(read.id));
    }
  }

  @visibleForTesting
  static void resetForTesting() {
    _pending.clear();
    _cached = null;
  }
}

class _Read {
  _Read(this.id, this.precise);
  final bool precise;
  final int id;
  final cancelled = Completer<void>();
  final owners = <AndroidLocationSession>{};
  late final Future<Position> future;
}
