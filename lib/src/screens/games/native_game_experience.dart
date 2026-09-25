part of 'package:companion_flutter/main.dart';

class _NativeGameExperienceScaffold extends StatefulWidget {
  const _NativeGameExperienceScaffold({
    required this.runtime,
    required this.game,
    required this.subtitle,
    required this.onStart,
    required this.onActiveRoundDeleted,
    required this.restartDisabled,
    this.activeChild,
    this.userTurnActive = false,
    this.turnToken = '',
    this.turnLabel = '等待开局',
    this.moveCount = 0,
    this.currentSummary,
  });

  final _NativeGameRuntime runtime;
  final _GameTile game;
  final String subtitle;
  final Future<void> Function() onStart;
  final VoidCallback onActiveRoundDeleted;
  final bool restartDisabled;
  final Widget? activeChild;
  final bool userTurnActive;
  final String turnToken;
  final String turnLabel;
  final int moveCount;
  final Map<String, dynamic> Function()? currentSummary;

  @override
  State<_NativeGameExperienceScaffold> createState() =>
      _NativeGameExperienceScaffoldState();
}

class _NativeGameExperienceScaffoldState
    extends State<_NativeGameExperienceScaffold> {
  bool _isFullscreen = false;

  @override
  void didUpdateWidget(covariant _NativeGameExperienceScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeChild == null && widget.activeChild != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.activeChild != null) {
          setState(() => _isFullscreen = true);
        }
      });
    }
  }

  Future<void> _start() async {
    await widget.onStart();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.activeChild != null) {
        setState(() => _isFullscreen = true);
      }
    });
  }

  Future<void> _closeGame() async {
    if (widget.runtime.session != null && !widget.runtime.completed) {
      await widget.runtime.abort(
        widget.runtime.turnTimeoutVisible ? 'turn_timeout_ended' : 'closed',
        widget.currentSummary?.call() ?? const {},
      );
    }
    widget.runtime.clearPresentation();
    widget.onActiveRoundDeleted();
    if (mounted) setState(() => _isFullscreen = false);
  }

  @override
  Widget build(BuildContext context) {
    final activeChild = widget.activeChild;
    final interactiveChild = activeChild == null
        ? null
        : _NativeGameInteractionLayer(
            runtime: widget.runtime,
            game: widget.game,
            onPlayAgain: _start,
            onCloseGame: _closeGame,
            userTurnActive: widget.userTurnActive,
            turnToken: '${widget.runtime.session?.id}:${widget.turnToken}',
            turnTimeout: _nativeGameTurnTimeout(widget.game.nativeGameKey),
            turnLabel: widget.turnLabel,
            moveCount: widget.moveCount,
            showPlayers: true,
            child: activeChild,
          );
    final compact = Scaffold(
      backgroundColor: AppColors.page,
      body: Stack(
        children: [
          const _GameBackground(progress: 0.5),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    MediaQuery.paddingOf(context).top + 12,
                    18,
                    14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(38, 38),
                        onPressed: () => leaveNativeGame(context),
                        child: _GlassButton(
                          size: 38,
                          child: const Icon(
                            CupertinoIcons.chevron_left,
                            size: 17,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        widget.game.title,
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 36,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          color: AppColors.text.withValues(alpha: 0.55),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                  child: _GlassPanel(
                    radius: 24,
                    padding: const EdgeInsets.all(13),
                    child: activeChild == null
                        ? Column(
                            children: [
                              AspectRatio(
                                aspectRatio: 1,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: _GamePlaceholderStage(
                                    game: widget.game,
                                  ),
                                ),
                              ),
                              if (widget.runtime.error != null) ...[
                                const SizedBox(height: 10),
                                _GomokuNotice(
                                  text: widget.runtime.error!,
                                  isError: true,
                                ),
                              ],
                              const SizedBox(height: 12),
                              _PrimaryGameButton(
                                label: '开始游戏',
                                loading: widget.runtime.starting,
                                disabled: widget.runtime.starting,
                                onPressed: _start,
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Align(
                                alignment: Alignment.centerRight,
                                child: _NativeFullscreenToggleButton(
                                  expanded: false,
                                  onPressed: () =>
                                      setState(() => _isFullscreen = true),
                                ),
                              ),
                              const SizedBox(height: 6),
                              interactiveChild!,
                              if (widget.runtime.syncNotice != null) ...[
                                const SizedBox(height: 10),
                                _GomokuNotice(
                                  text: widget.runtime.syncNotice!,
                                  isError: false,
                                ),
                              ],
                              const SizedBox(height: 12),
                              _PrimaryGameButton(
                                label: widget.runtime.completed
                                    ? '再来一局'
                                    : '重新开一局',
                                loading: widget.runtime.starting,
                                disabled:
                                    widget.runtime.starting ||
                                    widget.restartDisabled,
                                onPressed: _start,
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _GameRoundStats(
                  rounds: widget.runtime.rounds,
                  recordStats: widget.runtime.recordStats,
                  roundsLoading: widget.runtime.roundsLoading,
                  gamePoints: widget.runtime.gamePoints,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 42)),
            ],
          ),
        ],
      ),
    );
    final expanded = activeChild == null
        ? const SizedBox.shrink()
        : _NativeFullscreenGameSurface(
            gameKey: widget.game.nativeGameKey,
            gameTitle: widget.game.title,
            onExit: () => setState(() => _isFullscreen = false),
            onRestart: _start,
            restartLabel: widget.runtime.completed ? '再来一局' : '重新开一局',
            restartDisabled: widget.runtime.starting || widget.restartDisabled,
            restartLoading: widget.runtime.starting,
            child: interactiveChild!,
          );
    return _NativeGameFullscreenTransition(
      expanded: _isFullscreen && activeChild != null,
      compactChild: compact,
      expandedChild: expanded,
    );
  }
}

class _NativeScoreHeader extends StatelessWidget {
  const _NativeScoreHeader({
    required this.left,
    required this.center,
    required this.right,
  });
  final String left;
  final String center;
  final String right;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: _score(left, CrossAxisAlignment.start)),
      Expanded(child: _score(center, CrossAxisAlignment.center)),
      Expanded(child: _score(right, CrossAxisAlignment.end)),
    ],
  );

  Widget _score(String text, CrossAxisAlignment alignment) => Column(
    crossAxisAlignment: alignment,
    children: [
      Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.text,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}
