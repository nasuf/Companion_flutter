part of 'package:companion_flutter/main.dart';

/// Freezes [Ticker]s on a pushed page while it is sliding in, covered, or
/// popping away.
///
/// Cupertino transitions paint both the outgoing and incoming routes. Leaving
/// repeating breath / glow controllers running on either side is what made
/// every sidebar and tab-subpage switch feel like a low refresh rate — not
/// just weather and capsule.
///
/// Incoming freeze is the enter-jank counterpart of the covered-route freeze:
/// Daily Share / Music / Games build ImageFiltered layers and start N card
/// tickers on the same frame the Cupertino slide begins. Exit felt fine
/// because the destination was already a static snapshot.
class RouteTickerScope extends StatefulWidget {
  const RouteTickerScope({super.key, required this.child});

  final Widget child;

  @override
  State<RouteTickerScope> createState() => _RouteTickerScopeState();
}

class _RouteTickerScopeState extends State<RouteTickerScope> with RouteAware {
  bool _tick = false;
  bool _incomingCompleted = false;
  bool _publishedSettled = false;
  bool _coveredOrPopping = false;
  Timer? _resumeTimer;
  PageRoute<dynamic>? _subscribedRoute;
  Animation<double>? _routeAnimation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    _bindAnimation(route?.animation);
    if (route is PageRoute<dynamic> && route != _subscribedRoute) {
      appRouteObserver.unsubscribe(this);
      _subscribedRoute = route;
      appRouteObserver.subscribe(this, route);
    }
    _catchUpIncomingCompleted();
    _syncTick();
  }

  @override
  void didPush() {
    _resumeTimer?.cancel();
    _coveredOrPopping = false;
    DisplayRefreshRate.suppressRecover(
      DisplayRefreshPolicy.routeRecoverSuppress,
    );
    _catchUpIncomingCompleted();
    _syncTick();
  }

  @override
  void didPushNext() {
    _resumeTimer?.cancel();
    _coveredOrPopping = true;
    DisplayRefreshRate.suppressRecover(
      DisplayRefreshPolicy.routeRecoverSuppress,
    );
    _syncTick();
  }

  @override
  void didPopNext() {
    _resumeTimer?.cancel();
    DisplayRefreshRate.suppressRecover(
      DisplayRefreshPolicy.routeRecoverSuppress,
    );
    _resumeTimer = Timer(DisplayRefreshPolicy.routeUncoverDelay, () {
      if (!mounted) return;
      _coveredOrPopping = false;
      _syncTick();
    });
  }

  @override
  void didPop() {
    _resumeTimer?.cancel();
    _coveredOrPopping = true;
    DisplayRefreshRate.suppressRecover(
      DisplayRefreshPolicy.routeRecoverSuppress,
    );
    _syncTick();
  }

  @override
  void dispose() {
    _resumeTimer?.cancel();
    _routeAnimation?.removeStatusListener(_onRouteAnimationStatus);
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  void _bindAnimation(Animation<double>? animation) {
    if (identical(animation, _routeAnimation)) return;
    _routeAnimation?.removeStatusListener(_onRouteAnimationStatus);
    _routeAnimation = animation;
    _routeAnimation?.addStatusListener(_onRouteAnimationStatus);
  }

  void _onRouteAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _incomingCompleted = true;
    }
    _syncTick();
  }

  void _catchUpIncomingCompleted() {
    if (_incomingCompleted) return;
    final animation = _routeAnimation;
    if (animation == null) {
      // Live PageRoutes always expose an animation. Null means tests or a
      // widget tree with no [ModalRoute] — treat as already settled.
      if (_subscribedRoute == null) _incomingCompleted = true;
      return;
    }
    if (animation.status == AnimationStatus.completed) {
      _incomingCompleted = true;
    }
  }

  void _syncTick() {
    if (!mounted) return;
    final tick = incomingRouteTickersEnabled(
      coveredOrPopping: _coveredOrPopping,
      animationStatus: _incomingCompleted
          ? AnimationStatus.completed
          : (_routeAnimation?.status ?? AnimationStatus.forward),
    );
    if (_tick == tick && _publishedSettled == _incomingCompleted) return;
    setState(() {
      _tick = tick;
      _publishedSettled = _incomingCompleted;
    });
  }

  @override
  Widget build(BuildContext context) {
    return TickerMode(
      enabled: _tick,
      child: RouteSettled(settled: _publishedSettled, child: widget.child),
    );
  }
}

/// True once this route's incoming animation has landed. Heavy blur layers
/// and deferred network [setState]s should wait on this so they do not
/// compete with the Cupertino slide. Defaults to true outside a [RouteTickerScope]
/// so tests and non-routed widgets keep their previous behavior.
class RouteSettled extends InheritedWidget {
  const RouteSettled({super.key, required this.settled, required super.child});

  final bool settled;

  static bool of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<RouteSettled>()
            ?.settled ??
        true;
  }

  @override
  bool updateShouldNotify(RouteSettled oldWidget) =>
      settled != oldWidget.settled;
}

/// Drops [ImageFiltered] / [BackdropFilter] while the incoming route is still
/// sliding. The unfiltered [child] stays so layout does not jump.
class RouteSettledBlur extends StatelessWidget {
  const RouteSettledBlur.image({
    super.key,
    required this.sigma,
    required this.child,
  }) : backdrop = false;

  const RouteSettledBlur.backdrop({
    super.key,
    required this.sigma,
    required this.child,
  }) : backdrop = true;

  final double sigma;
  final Widget child;
  final bool backdrop;

  @override
  Widget build(BuildContext context) {
    if (!RouteSettled.of(context)) return child;
    final filter = ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
    if (backdrop) {
      return BackdropFilter(filter: filter, child: child);
    }
    return ImageFiltered(imageFilter: filter, child: child);
  }
}

/// Drop-in [CupertinoPageRoute] that applies [RouteTickerScope] to every
/// user-facing push (tabs, sidebar, nested subpages).
class CompanionPageRoute<T> extends CupertinoPageRoute<T> {
  CompanionPageRoute({
    required WidgetBuilder builder,
    super.settings,
    super.maintainState,
    super.fullscreenDialog,
    super.allowSnapshotting,
    super.barrierDismissible,
    super.title,
  }) : super(builder: (context) => RouteTickerScope(child: builder(context)));
}
