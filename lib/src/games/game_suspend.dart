import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// How long a revealed thumbnail stays up with no touch before it folds
/// back into the edge bar.
const gameFloatIdleCollapse = Duration(seconds: 5);

const gameFloatThumbWidth = 108.0;
const gameFloatBarWidth = 20.0;
const gameFloatBarHeight = 96.0;
const gameFloatThumbGap = 8.0;
const gameFloatDragSlop = 8.0;
const gameFloatRevealCommitThreshold = 0.42;
const gameFloatMaxSlots = 5;

const _minimizeDuration = Duration(milliseconds: 560);
const _revealDuration = Duration(milliseconds: 380);
const _collapseDuration = Duration(milliseconds: 420);
const _restoreDuration = Duration(milliseconds: 480);
const _settleDuration = Duration(milliseconds: 110);

/// Thumbnail keeps the screen's aspect ratio, so scaling it back to fullscreen
/// is the same picture growing rather than a cropped card swapping in.
Size gameFloatThumbSize(Size screen) {
  if (screen.width <= 0 || screen.height <= 0) {
    return const Size(gameFloatThumbWidth, 144);
  }
  var width = math.min(gameFloatThumbWidth, screen.width * 0.34);
  var height = width * screen.height / screen.width;
  final maxHeight = screen.height * 0.42;
  if (height > maxHeight) {
    height = maxHeight;
    width = height * screen.width / screen.height;
  }
  return Size(width, height);
}

enum GameFloatEdge { left, right }

enum GameFloatPhase { expanded, minimizing, bar, thumbnail, expanding }

enum GameFloatRequest { none, restore, minimize }

/// Center on the midline snaps right, matching the default edge.
GameFloatEdge nearestHorizontalEdge({
  required double centerX,
  required double width,
}) {
  return centerX < width / 2 ? GameFloatEdge.left : GameFloatEdge.right;
}

double thumbLeftForEdge({
  required GameFloatEdge edge,
  required double screenWidth,
  double thumbWidth = gameFloatThumbWidth,
}) {
  if (edge == GameFloatEdge.left) return gameFloatThumbGap;
  return math.max(
    gameFloatThumbGap,
    screenWidth - thumbWidth - gameFloatThumbGap,
  );
}

double clampThumbTop({
  required double top,
  required double screenHeight,
  required double safeTop,
  required double safeBottom,
  required double thumbHeight,
}) {
  final minTop = safeTop + 8;
  final maxTop = screenHeight - safeBottom - thumbHeight - 8;
  if (maxTop <= minTop) return minTop;
  return top.clamp(minTop, maxTop).toDouble();
}

Rect thumbRectFor({
  required GameFloatEdge edge,
  required double centerY,
  required Size screen,
  required EdgeInsets padding,
}) {
  final size = gameFloatThumbSize(screen);
  final top = clampThumbTop(
    top: centerY - size.height / 2,
    screenHeight: screen.height,
    safeTop: padding.top,
    safeBottom: padding.bottom,
    thumbHeight: size.height,
  );
  return Rect.fromLTWH(
    thumbLeftForEdge(
      edge: edge,
      screenWidth: screen.width,
      thumbWidth: size.width,
    ),
    top,
    size.width,
    size.height,
  );
}

Rect barRectFor({
  required GameFloatEdge edge,
  required double centerY,
  required Size screen,
  required EdgeInsets padding,
}) {
  final top = clampBarTop(
    top: centerY - gameFloatBarHeight / 2,
    screenHeight: screen.height,
    safeTop: padding.top,
    safeBottom: padding.bottom,
  );
  return Rect.fromLTWH(
    barLeftForEdge(edge: edge, screenWidth: screen.width),
    top,
    gameFloatBarWidth,
    gameFloatBarHeight,
  );
}

double barLeftForEdge({
  required GameFloatEdge edge,
  required double screenWidth,
}) {
  return edge == GameFloatEdge.left ? 0.0 : screenWidth - gameFloatBarWidth;
}

double clampBarTop({
  required double top,
  required double screenHeight,
  required double safeTop,
  required double safeBottom,
}) {
  final minTop = safeTop + 8;
  final maxTop = math.max(
    minTop,
    screenHeight - safeBottom - gameFloatBarHeight - 8,
  );
  if (maxTop <= minTop) return minTop;
  return top.clamp(minTop, maxTop).toDouble();
}

/// Pull progress while dragging the edge bar (0 = docked, 1 = full thumbnail).
double barPullProgress({
  required double centerX,
  required GameFloatEdge edge,
  required double screenWidth,
  double thumbWidth = gameFloatThumbWidth,
}) {
  final edgeCenter = edge == GameFloatEdge.right
      ? screenWidth - gameFloatBarWidth / 2
      : gameFloatBarWidth / 2;
  final thumbLeft = thumbLeftForEdge(
    edge: edge,
    screenWidth: screenWidth,
    thumbWidth: thumbWidth,
  );
  final thumbCenter = thumbLeft + thumbWidth / 2;
  final maxDelta = (thumbCenter - edgeCenter).abs();
  if (maxDelta <= 0) return 1;
  final delta = edge == GameFloatEdge.right
      ? (edgeCenter - centerX).clamp(0.0, maxDelta)
      : (centerX - edgeCenter).clamp(0.0, maxDelta);
  return (delta / maxDelta).clamp(0.0, 1.0);
}

class GameFloatVisual {
  const GameFloatVisual({
    required this.rect,
    required this.shotOpacity,
    required this.chromeOpacity,
    required this.radius,
  });

  final Rect rect;
  final double shotOpacity;
  final double chromeOpacity;
  final double radius;
}

GameFloatVisual sampleFloatEdgeMorph(
  Rect from,
  Rect to,
  double t, {
  required bool opening,
}) {
  final u = opening
      ? Curves.easeOutCubic.transform(t.clamp(0.0, 1.0))
      : Curves.easeInOutCubic.transform(t.clamp(0.0, 1.0));
  final shot = opening
      ? Curves.easeOut.transform(((u - 0.08) / 0.92).clamp(0.0, 1.0))
      : 1 - Curves.easeIn.transform(((u - 0.18) / 0.82).clamp(0.0, 1.0));
  final chrome = opening ? 1 - shot : 1 - shot;
  return GameFloatVisual(
    rect: Rect.lerp(from, to, u)!,
    shotOpacity: shot.toDouble(),
    chromeOpacity: chrome.toDouble(),
    radius: ui.lerpDouble(opening ? 12 : 16, opening ? 16 : 12, u)!,
  );
}

/// Edge-anchored bar that grows into a thumbnail as it is pulled away.
GameFloatVisual computeBarPullVisual({
  required GameFloatEdge edge,
  required double centerY,
  required double progress,
  required Size screen,
  required EdgeInsets padding,
}) {
  final edgeBar = barRectFor(
    edge: edge,
    centerY: centerY,
    screen: screen,
    padding: padding,
  );
  final targetThumb = thumbRectFor(
    edge: edge,
    centerY: centerY,
    screen: screen,
    padding: padding,
  );
  return sampleFloatEdgeMorph(
    edgeBar,
    targetThumb,
    progress,
    opening: true,
  );
}

/// True once [limit] has passed since the last touch on the thumbnail.
bool gameFloatIdleElapsed({
  required DateTime now,
  required DateTime lastTouch,
  Duration limit = gameFloatIdleCollapse,
}) {
  return !now.isBefore(lastTouch.add(limit));
}

/// Keeps one live game mounted above the navigator so minimizing does not
/// dispose the round. At most [gameFloatMaxSlots] games stay suspended.
class GameSuspendController extends ChangeNotifier {
  final List<GameFloatEntry> entries = [];
  final Map<String, Future<void> Function()> _forfeitHandlers = {};

  bool contains(String id) => entries.any((entry) => entry.id == id);

  GameFloatEntry? find(String id) {
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  bool get blocksSystemBack => entries.any(
    (entry) =>
        entry.phase == GameFloatPhase.expanded ||
        entry.phase == GameFloatPhase.minimizing ||
        entry.phase == GameFloatPhase.expanding,
  );

  /// Completes when that game is actually left, not when it is minimized.
  Future<void> open({
    required String id,
    required String title,
    required String previewAsset,
    required WidgetBuilder pageBuilder,
  }) {
    final existing = find(id);
    if (existing != null) {
      existing.request = GameFloatRequest.restore;
      notifyListeners();
      return existing.done.future;
    }
    while (entries.length >= gameFloatMaxSlots) {
      final victim = entries.cast<GameFloatEntry?>().firstWhere(
        (entry) =>
            entry!.phase != GameFloatPhase.expanded &&
            entry.phase != GameFloatPhase.expanding,
        orElse: () => entries.isEmpty ? null : entries.first,
      );
      if (victim == null) break;
      close(victim.id);
    }
    final entry = GameFloatEntry(
      id: id,
      title: title,
      previewAsset: previewAsset,
      pageBuilder: pageBuilder,
    );
    entries.add(entry);
    notifyListeners();
    return entry.done.future;
  }

  void setPhase(String id, GameFloatPhase phase) {
    final entry = find(id);
    if (entry == null || entry.phase == phase) return;
    entry.phase = phase;
    if (phase != GameFloatPhase.expanded) entry.presented = false;
    notifyListeners();
  }

  /// Asks the host to capture the current frame and fold this round into the
  /// edge bar. Ignored unless the round is currently on screen.
  void requestMinimize(String id) {
    final entry = find(id);
    if (entry == null || entry.phase != GameFloatPhase.expanded) return;
    if (entry.request == GameFloatRequest.minimize) return;
    // Freeze AI and turn clocks before the host even captures the screenshot.
    entry.presented = false;
    entry.request = GameFloatRequest.minimize;
    notifyListeners();
  }

  /// True once the expanded page is on screen and the zoom-in fade has
  /// finished. AI waits on this so a move cannot land under the screenshot.
  bool isPresented(String id) {
    final entry = find(id);
    if (entry == null) return true;
    return entry.phase == GameFloatPhase.expanded && entry.presented;
  }

  void markPresented(String id) {
    final entry = find(id);
    if (entry == null || entry.phase != GameFloatPhase.expanded) return;
    if (entry.presented) return;
    entry.presented = true;
    notifyListeners();
  }

  void bindForfeit(String id, Future<void> Function() handler) {
    _forfeitHandlers[id] = handler;
  }

  void unbindForfeit(String id) {
    _forfeitHandlers.remove(id);
  }

  /// Forfeit the round (when registered) and remove the suspended entry.
  Future<void> dismiss(String id) async {
    final handler = _forfeitHandlers[id];
    if (handler != null) {
      await handler();
    }
    close(id);
  }

  void close(String id) {
    final index = entries.indexWhere((entry) => entry.id == id);
    if (index < 0) return;
    final entry = entries.removeAt(index);
    _forfeitHandlers.remove(id);
    entry.releasePreview();
    notifyListeners();
    if (!entry.done.isCompleted) entry.done.complete();
  }

  void closeAll() {
    final ids = entries.map((entry) => entry.id).toList();
    for (final id in ids) {
      close(id);
    }
  }
}

/// Root-navigator hook so a minimized game can still sit above every route,
/// while an expanded game can swallow the system back button.
class GameSuspendBinding extends NavigatorObserver {
  Route<dynamic>? topRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    topRoute = route;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    topRoute = previousRoute;
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    topRoute = previousRoute;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    topRoute = newRoute;
  }
}

final gameSuspendBinding = GameSuspendBinding();
final gameSuspendController = GameSuspendController();

/// Full-screen captures above this ratio blow past the GPU texture limit
/// (about 4096px) and come back black. 2x is still sharp when the card zooms
/// back to fullscreen.
const _capturePixelRatioCap = 2.0;
const _captureFrameTimeout = Duration(milliseconds: 300);
const _captureImageTimeout = Duration(milliseconds: 450);
const _captureOverallTimeout = Duration(milliseconds: 900);

void _disposeImageAfterFrame(ui.Image image) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    image.dispose();
  });
  WidgetsBinding.instance.scheduleFrame();
}

class GameFloatEntry {
  GameFloatEntry({
    required this.id,
    required this.title,
    required this.previewAsset,
    required this.pageBuilder,
  });

  final String id;
  final String title;
  final String previewAsset;
  final WidgetBuilder pageBuilder;
  final GlobalKey boundaryKey = GlobalKey(debugLabel: 'game-float-boundary');
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final Completer<void> done = Completer<void>();

  GameFloatPhase phase = GameFloatPhase.expanded;
  GameFloatEdge edge = GameFloatEdge.right;
  GameFloatRequest request = GameFloatRequest.none;

  /// False from the moment a round leaves the screen until the restore fade
  /// has finished. Starts true so a freshly opened game is playable.
  bool presented = true;
  double? centerY;
  Offset? thumbTopLeft;

  /// Live frame captured at suspend time. Owned by this entry.
  ui.Image? preview;
  Widget? _page;

  void adoptPreview(ui.Image image) {
    final previous = preview;
    preview = image;
    if (previous != null) _disposeImageAfterFrame(previous);
  }

  void releasePreview() {
    final previous = preview;
    preview = null;
    if (previous != null) _disposeImageAfterFrame(previous);
  }

  Widget pageFor(BuildContext context) => _page ??= pageBuilder(context);

  GameFloatRequest takeRequest() {
    final current = request;
    request = GameFloatRequest.none;
    return current;
  }
}

/// Leaves the suspended game, or pops a normal route when the page was not
/// opened through [GameSuspendController].
void leaveNativeGame(BuildContext context) {
  final entryId = GameSuspendScope.entryIdOf(context);
  if (entryId != null) {
    gameSuspendController.close(entryId);
    return;
  }
  Navigator.of(context).maybePop();
}

class GameSuspendScope extends InheritedWidget {
  const GameSuspendScope({
    super.key,
    required this.entryId,
    required this.controller,
    required super.child,
  });

  final String entryId;
  final GameSuspendController controller;

  static GameSuspendScope? of(BuildContext context) {
    return context.getInheritedWidgetOfExactType<GameSuspendScope>();
  }

  static String? entryIdOf(BuildContext context) => of(context)?.entryId;

  @override
  bool updateShouldNotify(GameSuspendScope oldWidget) =>
      entryId != oldWidget.entryId || controller != oldWidget.controller;
}

/// Registers a mid-game forfeit handler for the suspended float close button.
class GameSuspendForfeitBinding extends StatefulWidget {
  const GameSuspendForfeitBinding({
    super.key,
    required this.onForfeit,
    required this.child,
  });

  final Future<void> Function()? onForfeit;
  final Widget child;

  @override
  State<GameSuspendForfeitBinding> createState() =>
      _GameSuspendForfeitBindingState();
}

class _GameSuspendForfeitBindingState extends State<GameSuspendForfeitBinding> {
  String? _entryId;
  GameSuspendController? _controller;

  void _syncBinding() {
    if (_entryId != null && _controller != null) {
      _controller!.unbindForfeit(_entryId!);
    }
    final scope = GameSuspendScope.of(context);
    _entryId = scope?.entryId;
    _controller = scope?.controller;
    if (_entryId != null && _controller != null && widget.onForfeit != null) {
      _controller!.bindForfeit(_entryId!, widget.onForfeit!);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBinding();
  }

  @override
  void didUpdateWidget(GameSuspendForfeitBinding oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncBinding();
  }

  @override
  void dispose() {
    if (_entryId != null && _controller != null) {
      _controller!.unbindForfeit(_entryId!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Clocks that must not run while the game is only a bar or a thumbnail.
class GameLiveScope extends InheritedWidget {
  const GameLiveScope({super.key, required this.live, required super.child});

  final bool live;

  static bool isLive(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<GameLiveScope>()?.live ??
        true;
  }

  /// Reads the current flag without subscribing. Safe inside timers.
  static bool peek(BuildContext context) {
    return context.getInheritedWidgetOfExactType<GameLiveScope>()?.live ?? true;
  }

  @override
  bool updateShouldNotify(GameLiveScope oldWidget) => live != oldWidget.live;
}

/// True when turn clocks and idle nudges should freeze, same as opening the
/// in-game pause sheet.
bool gameClockPaused(BuildContext context, {required bool manualPaused}) {
  return manualPaused || !GameLiveScope.isLive(context);
}

class GameSuspendHost extends StatefulWidget {
  const GameSuspendHost({
    super.key,
    required this.controller,
    required this.child,
  });

  final GameSuspendController controller;
  final Widget child;

  @override
  State<GameSuspendHost> createState() => _GameSuspendHostState();
}

enum _FlightKind { minimize, reveal, collapse, restore }

class _Flight {
  const _Flight({
    required this.kind,
    required this.entry,
    required this.screen,
    required this.origin,
    required this.thumb,
    required this.bar,
  });

  final _FlightKind kind;
  final GameFloatEntry entry;
  final Size screen;

  /// Fullscreen rect for minimize/restore. Unused for bar↔thumb.
  final Rect origin;
  final Rect thumb;
  final Rect bar;
}

class _FlightVisual {
  const _FlightVisual({
    required this.rect,
    required this.shotOpacity,
    required this.chromeOpacity,
    required this.radius,
  });

  final Rect rect;
  final double shotOpacity;
  final double chromeOpacity;
  final double radius;
}

class _GameSuspendHostState extends State<GameSuspendHost>
    with TickerProviderStateMixin {
  Timer? _idle;
  String? _idleFor;
  AnimationController? _flightController;
  AnimationController? _slide;
  AnimationController? _settle;
  CurvedAnimation? _slideCurve;
  _Flight? _flight;
  GameFloatEntry? _settleEntry;
  bool _capturing = false;
  Offset? _panOrigin;
  Offset? _panGlobal;
  Offset? _panOriginCenter;
  GameFloatEntry? _dragEntry;
  Offset? _dragCenter;
  double _dragProgress = 0;
  bool _barPointerActive = false;
  final ValueNotifier<bool> _holdCanPop = ValueNotifier<bool>(false);
  bool _holdOpen = false;
  int _holdTicket = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onController);
  }

  @override
  void didUpdateWidget(GameSuspendHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onController);
      widget.controller.addListener(_onController);
    }
  }

  @override
  void dispose() {
    _idle?.cancel();
    _flightController?.dispose();
    _settle?.dispose();
    _stopSlide();
    _holdCanPop.dispose();
    widget.controller.removeListener(_onController);
    super.dispose();
  }

  void _onController() {
    final restores = <GameFloatEntry>[];
    final minimizes = <GameFloatEntry>[];
    for (final entry in widget.controller.entries) {
      switch (entry.takeRequest()) {
        case GameFloatRequest.restore:
          restores.add(entry);
        case GameFloatRequest.minimize:
          minimizes.add(entry);
        case GameFloatRequest.none:
          break;
      }
    }
    if (_idleFor != null) {
      final entry = widget.controller.find(_idleFor!);
      if (entry == null || entry.phase != GameFloatPhase.thumbnail) {
        _cancelIdle();
      }
    }
    setState(() {});
    _syncHoldRoute();
    for (final entry in restores) {
      unawaited(_restore(entry));
    }
    for (final entry in minimizes) {
      unawaited(_minimize(entry));
    }
  }

  void _syncHoldRoute() {
    final navigator = gameSuspendBinding.navigator;
    if (navigator == null) return;
    final needsHold = widget.controller.blocksSystemBack;
    if (needsHold && !_holdOpen) {
      _holdTicket++;
      _holdOpen = true;
      _holdCanPop.value = false;
      navigator.push<void>(
        PageRouteBuilder<void>(
          settings: const RouteSettings(name: 'game-suspend-hold'),
          opaque: false,
          barrierDismissible: false,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (context, animation, secondaryAnimation) {
            return ValueListenableBuilder<bool>(
              valueListenable: _holdCanPop,
              builder: (context, canPop, _) {
                return PopScope(
                  canPop: canPop,
                  onPopInvokedWithResult: (didPop, result) {
                    if (didPop) return;
                    _forwardSystemBack();
                  },
                  child: const SizedBox.shrink(),
                );
              },
            );
          },
        ),
      );
      return;
    }
    if (!needsHold && _holdOpen) {
      _holdCanPop.value = true;
      final ticket = ++_holdTicket;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || ticket != _holdTicket) return;
        if (widget.controller.blocksSystemBack) return;
        final current = gameSuspendBinding.navigator;
        final top = gameSuspendBinding.topRoute;
        if (current == null || top?.settings.name != 'game-suspend-hold') {
          return;
        }
        if (!current.canPop()) return;
        _holdOpen = false;
        current.pop();
      });
    }
  }

  void _forwardSystemBack() {
    for (final entry in widget.controller.entries) {
      if (entry.phase != GameFloatPhase.expanded) continue;
      final nested = entry.navigatorKey.currentState;
      if (nested != null && nested.canPop()) nested.pop();
    }
  }

  Future<void> _minimize(GameFloatEntry entry) async {
    if (_capturing || entry.phase != GameFloatPhase.expanded) return;
    _capturing = true;
    _cancelIdle();
    ui.Image? image;
    try {
      image = await _captureWhenPainted(
        entry.boundaryKey,
      ).timeout(_captureOverallTimeout, onTimeout: () => null);
    } finally {
      _capturing = false;
    }
    if (!mounted || widget.controller.find(entry.id) == null) {
      image?.dispose();
      return;
    }
    if (entry.phase != GameFloatPhase.expanded) {
      image?.dispose();
      return;
    }
    if (image != null) entry.adoptPreview(image);
    final metrics = _metrics;
    entry.edge = GameFloatEdge.right;
    entry.centerY = _freeCenterY(entry, metrics);
    final thumb = thumbRectFor(
      edge: entry.edge,
      centerY: entry.centerY!,
      screen: metrics.size,
      padding: metrics.padding,
    );
    final bar = barRectFor(
      edge: entry.edge,
      centerY: entry.centerY!,
      screen: metrics.size,
      padding: metrics.padding,
    );
    entry.thumbTopLeft = thumb.topLeft;
    widget.controller.setPhase(entry.id, GameFloatPhase.minimizing);
    _fly(
      kind: _FlightKind.minimize,
      entry: entry,
      origin: Offset.zero & metrics.size,
      thumb: thumb,
      bar: bar,
      duration: _minimizeDuration,
      onDone: () {
        if (widget.controller.find(entry.id) == null) return;
        widget.controller.setPhase(entry.id, GameFloatPhase.bar);
      },
    );
  }

  void _revealThumb(GameFloatEntry entry) {
    if (entry.phase != GameFloatPhase.bar || _flight != null) return;
    for (final other in widget.controller.entries) {
      if (other.id != entry.id && other.phase == GameFloatPhase.thumbnail) {
        widget.controller.setPhase(other.id, GameFloatPhase.bar);
      }
    }
    final metrics = _metrics;
    final centerY = entry.centerY ?? metrics.size.height * 0.36;
    final thumb = thumbRectFor(
      edge: entry.edge,
      centerY: centerY,
      screen: metrics.size,
      padding: metrics.padding,
    );
    final bar = barRectFor(
      edge: entry.edge,
      centerY: centerY,
      screen: metrics.size,
      padding: metrics.padding,
    );
    entry.thumbTopLeft = thumb.topLeft;
    _fly(
      kind: _FlightKind.reveal,
      entry: entry,
      origin: Offset.zero & metrics.size,
      thumb: thumb,
      bar: bar,
      duration: _revealDuration,
      onDone: () {
        if (widget.controller.find(entry.id) == null) return;
        entry.thumbTopLeft = thumb.topLeft;
        widget.controller.setPhase(entry.id, GameFloatPhase.thumbnail);
        _armIdle(entry.id);
      },
    );
  }

  Future<void> _restore(GameFloatEntry entry) async {
    if (entry.phase == GameFloatPhase.expanded ||
        entry.phase == GameFloatPhase.expanding ||
        entry.phase == GameFloatPhase.minimizing) {
      return;
    }
    _cancelIdle();
    _stopSlide();
    _stopSettle();
    for (final other in widget.controller.entries) {
      if (other.id == entry.id) continue;
      if (other.phase == GameFloatPhase.expanded) {
        widget.controller.setPhase(other.id, GameFloatPhase.bar);
      }
    }
    final metrics = _metrics;
    final size = gameFloatThumbSize(metrics.size);
    final thumb =
        entry.phase == GameFloatPhase.thumbnail && entry.thumbTopLeft != null
        ? Rect.fromLTWH(
            entry.thumbTopLeft!.dx,
            entry.thumbTopLeft!.dy,
            size.width,
            size.height,
          )
        : thumbRectFor(
            edge: entry.edge,
            centerY: entry.centerY ?? metrics.size.height * 0.36,
            screen: metrics.size,
            padding: metrics.padding,
          );
    final bar = barRectFor(
      edge: entry.edge,
      centerY: entry.centerY ?? metrics.size.height * 0.36,
      screen: metrics.size,
      padding: metrics.padding,
    );
    widget.controller.setPhase(entry.id, GameFloatPhase.expanding);
    _fly(
      kind: _FlightKind.restore,
      entry: entry,
      origin: Offset.zero & metrics.size,
      thumb: thumb,
      bar: bar,
      duration: _restoreDuration,
      onDone: () {
        if (widget.controller.find(entry.id) == null) return;
        _beginSettle(entry);
      },
    );
  }

  void _collapseThumb(GameFloatEntry entry) {
    if (entry.phase != GameFloatPhase.thumbnail || _flight != null) return;
    _cancelIdle();
    _stopSlide();
    final metrics = _metrics;
    final size = gameFloatThumbSize(metrics.size);
    final topLeft = entry.thumbTopLeft ?? Offset.zero;
    entry.edge = nearestHorizontalEdge(
      centerX: topLeft.dx + size.width / 2,
      width: metrics.size.width,
    );
    entry.centerY = (topLeft.dy + size.height / 2)
        .clamp(
          metrics.padding.top + gameFloatBarHeight / 2 + 8,
          metrics.size.height -
              metrics.padding.bottom -
              gameFloatBarHeight / 2 -
              8,
        )
        .toDouble();
    final thumb = Rect.fromLTWH(
      topLeft.dx,
      topLeft.dy,
      size.width,
      size.height,
    );
    final bar = barRectFor(
      edge: entry.edge,
      centerY: entry.centerY!,
      screen: metrics.size,
      padding: metrics.padding,
    );
    _fly(
      kind: _FlightKind.collapse,
      entry: entry,
      origin: Offset.zero & metrics.size,
      thumb: thumb,
      bar: bar,
      duration: _collapseDuration,
      onDone: () {
        if (widget.controller.find(entry.id) == null) return;
        widget.controller.setPhase(entry.id, GameFloatPhase.bar);
      },
    );
  }

  void _beginSettle(GameFloatEntry entry) {
    widget.controller.setPhase(entry.id, GameFloatPhase.expanded);
    _stopSettle();
    if (entry.preview == null) {
      widget.controller.markPresented(entry.id);
      return;
    }
    final settle = AnimationController(vsync: this, duration: _settleDuration);
    _settle = settle;
    _settleEntry = entry;
    settle.addListener(() {
      if (mounted && identical(_settle, settle)) setState(() {});
    });
    settle.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      if (!identical(_settle, settle)) return;
      _settleEntry = null;
      if (widget.controller.find(entry.id)?.phase == GameFloatPhase.expanded) {
        widget.controller.markPresented(entry.id);
      }
      if (mounted) setState(() {});
    });
    setState(() {});
    settle.forward();
  }

  void _stopSettle() {
    final settle = _settle;
    _settle = null;
    _settleEntry = null;
    settle?.dispose();
  }

  void _armIdle(String id) {
    _idle?.cancel();
    _idleFor = id;
    _idle = Timer(gameFloatIdleCollapse, () {
      final entry = widget.controller.find(id);
      if (!mounted ||
          entry == null ||
          entry.phase != GameFloatPhase.thumbnail) {
        return;
      }
      _collapseThumb(entry);
    });
  }

  void _cancelIdle() {
    _idle?.cancel();
    _idle = null;
    _idleFor = null;
  }

  double _clampFloatCenterY(double centerY, _ScreenMetrics metrics, double height) {
    final minCenter = metrics.padding.top + height / 2 + 8;
    final maxCenter = math.max(
      minCenter,
      metrics.size.height - metrics.padding.bottom - height / 2 - 8,
    );
    return centerY.clamp(minCenter, maxCenter).toDouble();
  }

  void _clearBarDrag() {
    _dragEntry = null;
    _dragCenter = null;
    _dragProgress = 0;
    _panOriginCenter = null;
    _barPointerActive = false;
  }

  void _beginBarDrag(GameFloatEntry entry, Offset globalPosition) {
    _stopSlide();
    _cancelIdle();
    final metrics = _metrics;
    final rect = barRectFor(
      edge: entry.edge,
      centerY: entry.centerY ?? metrics.size.height * 0.36,
      screen: metrics.size,
      padding: metrics.padding,
    );
    _barPointerActive = true;
    _dragEntry = entry;
    _panOriginCenter = rect.center;
    _dragCenter = rect.center;
    _dragProgress = 0;
    _panOrigin = rect.topLeft;
    _panGlobal = globalPosition;
    setState(() {});
  }

  void _applyBarDrag(GameFloatEntry entry, Offset globalPosition) {
    final originCenter = _panOriginCenter;
    final global = _panGlobal;
    if (_dragEntry != entry || originCenter == null || global == null) return;
    final metrics = _metrics;
    final delta = globalPosition - global;
    final center = originCenter + delta;
    final thumbSize = gameFloatThumbSize(metrics.size);
    final progress = barPullProgress(
      centerX: center.dx,
      edge: entry.edge,
      screenWidth: metrics.size.width,
      thumbWidth: thumbSize.width,
    );
    final visual = computeBarPullVisual(
      edge: entry.edge,
      centerY: center.dy,
      progress: progress,
      screen: metrics.size,
      padding: metrics.padding,
    );
    _dragCenter = Offset(
      center.dx,
      _clampFloatCenterY(center.dy, metrics, visual.rect.height),
    );
    _dragProgress = progress;
    entry.centerY = _dragCenter!.dy;
    setState(() {});
  }

  void _finishBarDrag(GameFloatEntry entry) {
    final originCenter = _panOriginCenter;
    final center = _dragCenter;
    final progress = _dragProgress;
    _panOrigin = null;
    _panGlobal = null;
    _panOriginCenter = null;
    _barPointerActive = false;
    if (_dragEntry != entry || center == null) {
      _clearBarDrag();
      if (mounted) setState(() {});
      return;
    }
    if (originCenter != null &&
        (center - originCenter).distance < gameFloatDragSlop) {
      _clearBarDrag();
      _revealThumb(entry);
      return;
    }
    if (progress >= gameFloatRevealCommitThreshold) {
      _commitBarToThumb(entry, center);
      return;
    }
    _snapBar(entry, center, fromProgress: progress);
  }

  void _cancelBarDrag(GameFloatEntry entry) {
    _panOrigin = null;
    _panGlobal = null;
    _panOriginCenter = null;
    _barPointerActive = false;
    if (_dragEntry != entry) return;
    final center = _dragCenter;
    final progress = _dragProgress;
    if (center != null && progress > 0.01) {
      _snapBar(entry, center, fromProgress: progress);
      return;
    }
    _clearBarDrag();
    if (mounted) setState(() {});
  }

  void _commitBarToThumb(GameFloatEntry entry, Offset center) {
    _cancelIdle();
    _stopSlide();
    final metrics = _metrics;
    final edge = nearestHorizontalEdge(
      centerX: center.dx,
      width: metrics.size.width,
    );
    entry.edge = edge;
    entry.centerY = _clampFloatCenterY(
      center.dy,
      metrics,
      gameFloatThumbSize(metrics.size).height,
    );
    final thumb = thumbRectFor(
      edge: edge,
      centerY: entry.centerY!,
      screen: metrics.size,
      padding: metrics.padding,
    );
    entry.thumbTopLeft = thumb.topLeft;
    _clearBarDrag();
    widget.controller.setPhase(entry.id, GameFloatPhase.thumbnail);
    _armIdle(entry.id);
  }

  void _onThumbPanStart(GameFloatEntry entry, DragStartDetails details) {
    _cancelIdle();
    _stopSlide();
    _clearBarDrag();
    _panOrigin = entry.thumbTopLeft;
    _panGlobal = details.globalPosition;
  }

  void _onThumbPanUpdate(GameFloatEntry entry, DragUpdateDetails details) {
    final origin = _panOrigin;
    final global = _panGlobal;
    if (origin == null || global == null) return;
    final metrics = _metrics;
    final size = gameFloatThumbSize(metrics.size);
    final delta = details.globalPosition - global;
    final next = origin + delta;
    entry.thumbTopLeft = Offset(
      next.dx.clamp(0, math.max(0, metrics.size.width - size.width)),
      clampThumbTop(
        top: next.dy,
        screenHeight: metrics.size.height,
        safeTop: metrics.padding.top,
        safeBottom: metrics.padding.bottom,
        thumbHeight: size.height,
      ),
    );
    setState(() {});
  }

  void _onThumbPanEnd(GameFloatEntry entry, DragEndDetails details) {
    final origin = _panOrigin;
    final current = entry.thumbTopLeft;
    _panOrigin = null;
    _panGlobal = null;
    if (origin == null || current == null) return;
    if ((current - origin).distance < gameFloatDragSlop) {
      unawaited(_restore(entry));
      return;
    }
    _snap(entry);
    _armIdle(entry.id);
  }

  void _snap(GameFloatEntry entry) {
    final current = entry.thumbTopLeft;
    if (current == null) return;
    final metrics = _metrics;
    final size = gameFloatThumbSize(metrics.size);
    final edge = nearestHorizontalEdge(
      centerX: current.dx + size.width / 2,
      width: metrics.size.width,
    );
    entry.edge = edge;
    final left = thumbLeftForEdge(
      edge: edge,
      screenWidth: metrics.size.width,
      thumbWidth: size.width,
    );
    final begin = current.dx;
    _stopSlide();
    final slide = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _slide = slide;
    final animation = CurvedAnimation(
      parent: slide,
      curve: Curves.easeOutCubic,
    );
    _slideCurve = animation;
    animation.addListener(() {
      if (!mounted || !identical(_slide, slide)) return;
      entry.thumbTopLeft = Offset(
        ui.lerpDouble(begin, left, animation.value)!,
        current.dy,
      );
      setState(() {});
    });
    slide.forward();
  }

  void _snapBar(
    GameFloatEntry entry,
    Offset center, {
    required double fromProgress,
  }) {
    final metrics = _metrics;
    final edge = nearestHorizontalEdge(
      centerX: center.dx,
      width: metrics.size.width,
    );
    entry.edge = edge;
    final edgeCenterX = edge == GameFloatEdge.right
        ? metrics.size.width - gameFloatBarWidth / 2
        : gameFloatBarWidth / 2;
    final beginCenterX = center.dx;
    final beginCenterY = center.dy;
    final beginProgress = fromProgress.clamp(0.0, 1.0);
    _dragEntry = entry;
    _dragCenter = center;
    _dragProgress = beginProgress;
    _stopSlide();
    final slide = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: beginProgress > 0.01 ? 260 : 220),
    );
    _slide = slide;
    final animation = CurvedAnimation(
      parent: slide,
      curve: Curves.easeOutCubic,
    );
    _slideCurve = animation;
    animation.addListener(() {
      if (!mounted || !identical(_slide, slide)) return;
      final t = animation.value;
      final progress = ui.lerpDouble(beginProgress, 0, t)!;
      final centerX = ui.lerpDouble(beginCenterX, edgeCenterX, t)!;
      final centerY = beginCenterY;
      final visual = computeBarPullVisual(
        edge: edge,
        centerY: centerY,
        progress: progress,
        screen: metrics.size,
        padding: metrics.padding,
      );
      entry.centerY = _clampFloatCenterY(centerY, metrics, visual.rect.height);
      _dragCenter = Offset(centerX, entry.centerY!);
      _dragProgress = progress;
      setState(() {});
    });
    slide.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      if (!identical(_slide, slide)) return;
      _clearBarDrag();
      if (mounted) setState(() {});
    });
    slide.forward();
  }

  Future<void> _dismissFloat(GameFloatEntry entry) async {
    _cancelIdle();
    _stopSlide();
    _clearBarDrag();
    await widget.controller.dismiss(entry.id);
  }

  void _stopSlide() {
    final curve = _slideCurve;
    final slide = _slide;
    _slideCurve = null;
    _slide = null;
    curve?.dispose();
    slide?.dispose();
  }

  void _fly({
    required _FlightKind kind,
    required GameFloatEntry entry,
    required Rect origin,
    required Rect thumb,
    required Rect bar,
    required Duration duration,
    required VoidCallback onDone,
  }) {
    final previous = _flightController;
    _flightController = null;
    previous?.dispose();
    final controller = AnimationController(vsync: this, duration: duration);
    _flightController = controller;
    _flight = _Flight(
      kind: kind,
      entry: entry,
      screen: _metrics.size,
      origin: origin,
      thumb: thumb,
      bar: bar,
    );
    controller.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      if (!identical(_flightController, controller)) return;
      onDone();
      if (!mounted || !identical(_flightController, controller)) return;
      setState(() => _flight = null);
    });
    setState(() {});
    controller.forward();
  }

  /// Snapshot after a frame has actually painted.
  ///
  /// An animating board is dirty most of the time we look, and [toImage]
  /// refuses a dirty boundary. Waiting for the frame avoids that skip.
  /// The image is kept as [ui.Image]: encoding a full-screen PNG was slower
  /// than the old timeout, so the card fell through to a near-black fill.
  Future<ui.Image?> _captureWhenPainted(GlobalKey key) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      await _waitForPaintFrame();
      if (!mounted) return null;
      final image = await _snapshot(key);
      if (image != null) return image;
    }
    debugPrint('Game float snapshot failed: boundary was not paintable');
    return null;
  }

  Future<void> _waitForPaintFrame() async {
    final binding = WidgetsBinding.instance;
    binding.scheduleFrame();
    try {
      await binding.endOfFrame.timeout(_captureFrameTimeout);
    } on TimeoutException {
      // If the frame never lands, the next snapshot attempt still runs.
    }
  }

  Future<ui.Image?> _snapshot(GlobalKey key) async {
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null || !boundary.hasSize || boundary.size.isEmpty) {
      return null;
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final preferred = math.min(_capturePixelRatioCap, math.max(1.0, dpr));
    Object? lastError;
    for (final ratio in <double>[preferred, 1]) {
      try {
        return await boundary
            .toImage(pixelRatio: ratio)
            .timeout(_captureImageTimeout);
      } on TimeoutException {
        continue;
      } catch (error) {
        lastError = error;
      }
    }
    debugPrint('Game float snapshot failed: $lastError');
    return null;
  }

  _ScreenMetrics get _metrics {
    final media = MediaQuery.of(context);
    return _ScreenMetrics(media.size, media.padding);
  }

  double _freeCenterY(GameFloatEntry entry, _ScreenMetrics metrics) {
    final minCenter = metrics.padding.top + gameFloatBarHeight / 2 + 8;
    final maxCenter = math.max(
      minCenter,
      metrics.size.height - metrics.padding.bottom - gameFloatBarHeight / 2 - 8,
    );
    var y = (metrics.size.height * 0.36).clamp(minCenter, maxCenter).toDouble();
    final taken =
        widget.controller.entries
            .where(
              (other) =>
                  other.id != entry.id &&
                  other.edge == entry.edge &&
                  other.centerY != null &&
                  other.phase != GameFloatPhase.expanded,
            )
            .map((other) => other.centerY!)
            .toList()
          ..sort();
    for (final other in taken) {
      if ((other - y).abs() < gameFloatBarHeight + 12) {
        y = (other + gameFloatBarHeight + 12)
            .clamp(minCenter, maxCenter)
            .toDouble();
      }
    }
    return y;
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _metrics;
    final coversApp = widget.controller.entries.any(
      (entry) =>
          entry.phase == GameFloatPhase.expanded ||
          entry.phase == GameFloatPhase.expanding ||
          entry.phase == GameFloatPhase.minimizing,
    );
    final flying = _flight != null;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        for (final entry in widget.controller.entries) _keptAlive(entry),
        if (!coversApp && !flying)
          for (final entry in widget.controller.entries)
            if (entry.phase == GameFloatPhase.bar) _bar(entry, metrics),
        if (!coversApp && !flying)
          for (final entry in widget.controller.entries)
            if (entry.phase == GameFloatPhase.thumbnail) _thumb(entry, metrics),
        if (_flight case final flight?) _flightLayer(flight),
        if (_settleEntry case final settling?) _settleLayer(settling),
      ],
    );
  }

  Widget _keptAlive(GameFloatEntry entry) {
    final show = entry.phase == GameFloatPhase.expanded;
    final live = show && entry.presented;
    return Positioned.fill(
      key: ValueKey('game-float-alive-${entry.id}'),
      child: Offstage(
        offstage: !show,
        child: IgnorePointer(
          ignoring: !live,
          child: TickerMode(
            enabled: live,
            child: GameLiveScope(
              live: live,
              child: HeroControllerScope.none(
                child: Navigator(
                  key: entry.navigatorKey,
                  onDidRemovePage: (_) {
                    if (widget.controller.contains(entry.id)) {
                      widget.controller.close(entry.id);
                    }
                  },
                  pages: [
                    MaterialPage(
                      key: ValueKey('game-float-page-${entry.id}'),
                      child: GameSuspendScope(
                        entryId: entry.id,
                        controller: widget.controller,
                        child: RepaintBoundary(
                          key: entry.boundaryKey,
                          child: entry.pageFor(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bar(GameFloatEntry entry, _ScreenMetrics metrics) {
    final dragging = _dragEntry == entry;
    final centerY = dragging && _dragCenter != null
        ? _dragCenter!.dy
        : (entry.centerY ?? metrics.size.height * 0.36);
    final progress = dragging ? _dragProgress : 0.0;
    final visual = computeBarPullVisual(
      edge: entry.edge,
      centerY: centerY,
      progress: progress,
      screen: metrics.size,
      padding: metrics.padding,
    );
    return Positioned(
      key: ValueKey('game-float-bar-${entry.id}'),
      left: visual.rect.left,
      top: visual.rect.top,
      width: visual.rect.width,
      height: visual.rect.height,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) => _beginBarDrag(entry, event.position),
        onPointerMove: (event) {
          if (!_barPointerActive || _dragEntry != entry) return;
          _applyBarDrag(entry, event.position);
        },
        onPointerUp: (_) => _finishBarDrag(entry),
        onPointerCancel: (_) => _cancelBarDrag(entry),
        child: _FloatWindow(
          entry: entry,
          shotOpacity: visual.shotOpacity,
          chromeOpacity: visual.chromeOpacity,
          radius: visual.radius,
          onRight: entry.edge == GameFloatEdge.right,
          showClose: dragging && visual.shotOpacity >= 0.72,
          onDismiss: () => unawaited(_dismissFloat(entry)),
        ),
      ),
    );
  }

  Widget _thumb(GameFloatEntry entry, _ScreenMetrics metrics) {
    final size = gameFloatThumbSize(metrics.size);
    final topLeft = entry.thumbTopLeft ?? Offset.zero;
    return Positioned(
      key: ValueKey('game-float-thumb-${entry.id}'),
      left: topLeft.dx,
      top: topLeft.dy,
      width: size.width,
      height: size.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(_restore(entry)),
        onPanStart: (details) => _onThumbPanStart(entry, details),
        onPanUpdate: (details) => _onThumbPanUpdate(entry, details),
        onPanEnd: (details) => _onThumbPanEnd(entry, details),
        child: _FloatWindow(
          entry: entry,
          shotOpacity: 1,
          chromeOpacity: 0,
          radius: 16,
          onRight: entry.edge == GameFloatEdge.right,
          showClose: true,
          onDismiss: () => unawaited(_dismissFloat(entry)),
        ),
      ),
    );
  }

  Widget _flightLayer(_Flight flight) {
    final controller = _flightController;
    if (controller == null) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final visual = _sampleFlight(flight, controller.value);
            final onRight = flight.bar.center.dx > flight.screen.width / 2;
            return Stack(
              children: [
                Positioned.fromRect(
                  rect: visual.rect,
                  child: _FloatWindow(
                    entry: flight.entry,
                    shotOpacity: visual.shotOpacity,
                    chromeOpacity: visual.chromeOpacity,
                    radius: visual.radius,
                    onRight: onRight,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _settleLayer(GameFloatEntry entry) {
    final settle = _settle;
    final opacity = settle == null ? 0.0 : (1 - settle.value).clamp(0.0, 1.0);
    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: _FloatShot(image: entry.preview),
        ),
      ),
    );
  }

  _FlightVisual _sampleFlight(_Flight flight, double t) {
    switch (flight.kind) {
      case _FlightKind.minimize:
        return _sampleMinimize(flight, t);
      case _FlightKind.reveal:
        return _sampleEdgeMorph(flight.bar, flight.thumb, t, opening: true);
      case _FlightKind.collapse:
        return _sampleEdgeMorph(flight.thumb, flight.bar, t, opening: false);
      case _FlightKind.restore:
        return _sampleRestore(flight, t);
    }
  }

  /// Shrinks the live frame toward the edge, then eases it into the bar.
  _FlightVisual _sampleMinimize(_Flight flight, double t) {
    const split = 0.74;
    final travel = Curves.easeOutCubic.transform(t);
    final center = Offset.lerp(
      flight.origin.center,
      flight.bar.center,
      travel,
    )!;
    if (t < split) {
      final u = Curves.easeOutCubic.transform(t / split);
      final scale = ui.lerpDouble(
        1,
        flight.thumb.width / math.max(flight.screen.width, 1),
        u,
      )!;
      return _FlightVisual(
        rect: Rect.fromCenter(
          center: center,
          width: flight.screen.width * scale,
          height: flight.screen.height * scale,
        ),
        shotOpacity: 1,
        chromeOpacity: 0,
        radius: ui.lerpDouble(0, 16, u)!,
      );
    }
    final u = Curves.easeInOutCubic.transform((t - split) / (1 - split));
    final held = flight.thumb.width / math.max(flight.screen.width, 1);
    return _FlightVisual(
      rect: Rect.fromCenter(
        center: center,
        width: ui.lerpDouble(flight.screen.width * held, flight.bar.width, u)!,
        height: ui.lerpDouble(
          flight.screen.height * held,
          flight.bar.height,
          u,
        )!,
      ),
      shotOpacity: 1 - u,
      chromeOpacity: u,
      radius: ui.lerpDouble(16, 12, u)!,
    );
  }

  _FlightVisual _sampleEdgeMorph(
    Rect from,
    Rect to,
    double t, {
    required bool opening,
  }) {
    final u = opening
        ? Curves.easeOutCubic.transform(t)
        : Curves.easeInOutCubic.transform(t);
    final shot = opening
        ? Curves.easeOut.transform(((u - 0.08) / 0.92).clamp(0.0, 1.0))
        : 1 - Curves.easeIn.transform(((u - 0.18) / 0.82).clamp(0.0, 1.0));
    final chrome = opening ? 1 - shot : 1 - shot;
    return _FlightVisual(
      rect: Rect.lerp(from, to, u)!,
      shotOpacity: shot.toDouble(),
      chromeOpacity: chrome.toDouble(),
      radius: ui.lerpDouble(opening ? 12 : 16, opening ? 16 : 12, u)!,
    );
  }

  _FlightVisual _sampleRestore(_Flight flight, double t) {
    final u = Curves.easeOutCubic.transform(t);
    final scale = ui.lerpDouble(
      flight.thumb.width / math.max(flight.screen.width, 1),
      1,
      u,
    )!;
    final center = Offset.lerp(flight.thumb.center, flight.origin.center, u)!;
    return _FlightVisual(
      rect: Rect.fromCenter(
        center: center,
        width: flight.screen.width * scale,
        height: flight.screen.height * scale,
      ),
      shotOpacity: 1,
      chromeOpacity: 0,
      radius: ui.lerpDouble(16, 0, u)!,
    );
  }
}

class _ScreenMetrics {
  const _ScreenMetrics(this.size, this.padding);

  final Size size;
  final EdgeInsets padding;
}

/// Sits in the in-game points row, to the right of the coin pill, and only
/// exists once a round is on screen. Same height as the pill: a sky-blue rim
/// and navy well, with a cream window glyph in the plus-button enamel.
class GameSuspendButton extends StatelessWidget {
  const GameSuspendButton({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = GameSuspendScope.of(context);
    if (scope == null) return const SizedBox.shrink();
    return Semantics(
      button: true,
      label: '挂起',
      child: CupertinoButton(
        key: ValueKey('game-suspend-button-${scope.entryId}'),
        padding: EdgeInsets.zero,
        minimumSize: const Size(34, 31),
        onPressed: () => scope.controller.requestMinimize(scope.entryId),
        child: const SizedBox(
          width: 31,
          height: 31,
          child: CustomPaint(painter: _SuspendChipPainter()),
        ),
      ),
    );
  }
}

/// Window glyph shared with the fullscreen chrome button.
class GameSuspendGlyph extends StatelessWidget {
  const GameSuspendGlyph({
    super.key,
    this.color = _SuspendPalette.glyph,
    this.outline = _SuspendPalette.outline,
    this.size = 16,
  });

  final Color color;
  final Color outline;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _SuspendGlyphPainter(color: color, outline: outline),
    );
  }
}

class _FloatWindow extends StatelessWidget {
  const _FloatWindow({
    required this.entry,
    required this.shotOpacity,
    required this.chromeOpacity,
    required this.radius,
    required this.onRight,
    this.showClose = false,
    this.onDismiss,
  });

  final GameFloatEntry entry;
  final double shotOpacity;
  final double chromeOpacity;
  final double radius;
  final bool onRight;
  final bool showClose;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final corner = radius.clamp(0.0, 28.0);
    final shot = shotOpacity.clamp(0.0, 1.0);
    final chrome = chromeOpacity.clamp(0.0, 1.0);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(corner),
        boxShadow: [
          BoxShadow(
            color: const Color(0x47000000).withValues(alpha: 0.28 * shot),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(corner),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: shot,
              child: _FloatShot(image: entry.preview),
            ),
            if (chrome > 0.01)
              Opacity(
                opacity: chrome,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xB31C1C1E),
                    borderRadius: BorderRadius.horizontal(
                      left: onRight ? Radius.circular(corner) : Radius.zero,
                      right: onRight ? Radius.zero : Radius.circular(corner),
                    ),
                  ),
                  child: const Center(child: _VerticalDots()),
                ),
              ),
            if (shot > 0.2)
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(corner),
                    border: Border.all(
                      color: const Color(0xF2FFFFFF).withValues(alpha: shot),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            if (showClose && shot > 0.55 && onDismiss != null)
              Positioned(
                top: 4,
                left: onRight ? 4 : null,
                right: onRight ? null : 4,
                child: _FloatCloseButton(onPressed: onDismiss!),
              ),
          ],
        ),
      ),
    );
  }
}

class _FloatCloseButton extends StatelessWidget {
  const _FloatCloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '关闭游戏',
      child: CupertinoButton(
        key: const ValueKey('game-float-close'),
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        onPressed: onPressed,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: const Color(0xCC1C1C1E),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x99FFFFFF)),
          ),
          alignment: Alignment.center,
          child: const Icon(
            CupertinoIcons.xmark,
            size: 12,
            color: Color(0xF2FFFFFF),
          ),
        ),
      ),
    );
  }
}

class _FloatShot extends StatelessWidget {
  const _FloatShot({required this.image});

  final ui.Image? image;

  @override
  Widget build(BuildContext context) {
    final shot = image;
    if (shot == null) {
      return const ColoredBox(color: Color(0xFF1C1C1E));
    }
    return RawImage(
      image: shot,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      filterQuality: FilterQuality.medium,
      width: double.infinity,
      height: double.infinity,
    );
  }
}

/// Colors sampled from `coin_pill.png` (rim and well) and `coin_plus.png`
/// (cream enamel glyph).
class _SuspendPalette {
  const _SuspendPalette._();

  static const edge = Color(0xFF163044);
  static const rimTop = Color(0xFF6A9DC4);
  static const rimBottom = Color(0xFF3E6C90);
  static const face = Color(0xFF213553);
  static const glyph = Color(0xFFFCF3E2);
  static const outline = Color(0xFF101820);
}

class _SuspendChipPainter extends CustomPainter {
  const _SuspendChipPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Rect.fromLTWH(0.5, 0.4, size.width - 1.0, size.height - 1.2);
    final outer = RRect.fromRectAndRadius(bounds, const Radius.circular(9));
    canvas.drawRRect(
      outer.shift(const Offset(0, 1.1)),
      Paint()
        ..color = const Color(0x4D101828)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.3),
    );
    canvas.drawRRect(outer, Paint()..color = _SuspendPalette.edge);
    final rimRect = bounds.deflate(0.8);
    final rim = RRect.fromRectAndRadius(rimRect, const Radius.circular(8.2));
    canvas.drawRRect(
      rim,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_SuspendPalette.rimTop, _SuspendPalette.rimBottom],
        ).createShader(rimRect),
    );

    final wellRect = bounds.deflate(3.15);
    final well = RRect.fromRectAndRadius(wellRect, const Radius.circular(6));
    canvas.drawRRect(well, Paint()..color = _SuspendPalette.face);
    canvas.save();
    canvas.clipRRect(well);
    final shade = Rect.fromLTWH(wellRect.left, wellRect.top, wellRect.width, 4);
    canvas.drawRect(
      shade,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x66001020), Color(0x00001020)],
        ).createShader(shade),
    );
    canvas.restore();

    const glyph = 15.0;
    final glyphTop = (wellRect.center.dy - glyph / 2)
        .clamp(2.0, size.height - glyph - 1)
        .toDouble();
    canvas.save();
    canvas.translate((size.width - glyph) / 2, glyphTop);
    const _SuspendGlyphPainter(
      color: _SuspendPalette.glyph,
      outline: _SuspendPalette.outline,
    ).paint(canvas, const Size.square(glyph));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SuspendGlyphPainter extends CustomPainter {
  const _SuspendGlyphPainter({required this.color, required this.outline});

  final Color color;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final back = RRect.fromRectAndRadius(
      Rect.fromLTWH(side * 0.08, side * 0.07, side * 0.52, side * 0.46),
      Radius.circular(side * 0.14),
    );
    final front = RRect.fromRectAndRadius(
      Rect.fromLTWH(side * 0.34, side * 0.42, side * 0.54, side * 0.46),
      Radius.circular(side * 0.16),
    );
    final weight = (side * 0.085).clamp(1.15, 1.65).toDouble();

    canvas.drawRRect(
      front.shift(Offset(0, side * 0.05)),
      Paint()..color = outline.withValues(alpha: 0.35),
    );
    _stroke(canvas, back, outline, weight + 1.7);
    _stroke(canvas, back, color, weight);
    canvas.drawRRect(front.inflate(weight * 0.42), Paint()..color = outline);
    canvas.drawRRect(front, Paint()..color = color);
  }

  void _stroke(Canvas canvas, RRect rect, Color color, double width) {
    canvas.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _SuspendGlyphPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.outline != outline;
  }
}

class _VerticalDots extends StatelessWidget {
  const _VerticalDots();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(height: 5),
          Container(
            width: 3.5,
            height: 3.5,
            decoration: const BoxDecoration(
              color: Color(0xF2FFFFFF),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    );
  }
}
