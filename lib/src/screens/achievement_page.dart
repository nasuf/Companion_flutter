part of 'package:companion_flutter/main.dart';

class AchievementPage extends StatefulWidget {
  const AchievementPage({super.key, required this.api, required this.session});

  final CompanionApi api;
  final AuthSession session;

  @override
  State<AchievementPage> createState() => _AchievementPageState();
}

class _AchievementPageState extends State<AchievementPage> {
  late Future<AchievementsResponse> _future;
  final Set<int> _flipped = <int>{};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<AchievementsResponse> _load() {
    final agentId = widget.session.agentId;
    if (agentId == null || agentId.isEmpty) {
      throw const ApiException(400, '尚未创建 AI');
    }
    return widget.api.listAchievements(agentId: agentId);
  }

  void _retry() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F5),
      body: FutureBuilder<AchievementsResponse>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return SafeArea(
              bottom: false,
              child: _AchievementError(
                message: '${snapshot.error}',
                onRetry: _retry,
              ),
            );
          }
          final data = snapshot.data!;
          final unlocked = _unlockedAchievements(data.items);
          return Stack(
            children: [
              const Positioned.fill(child: _AchievementPageBackground()),
              SafeArea(
                bottom: false,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _AchievementHeader(
                        items: unlocked,
                        score: _achievementUnlockedScore(unlocked),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                        child: Text(
                          unlocked.isEmpty ? '等待被点亮' : '已获得成就',
                          style: const TextStyle(
                            color: Color(0xFF9BA4A1),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                    if (unlocked.isEmpty)
                      const SliverToBoxAdapter(child: _AchievementEmptyState())
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          0,
                          20,
                          safeBottom + 34,
                        ),
                        sliver: SliverGrid(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final item = unlocked[index];
                            return _AchievementCard(
                              item: item,
                              flipped: _flipped.contains(item.id),
                              onTap: () {
                                setState(() {
                                  if (!_flipped.add(item.id)) {
                                    _flipped.remove(item.id);
                                  }
                                });
                              },
                            );
                          }, childCount: unlocked.length),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 14,
                                childAspectRatio: 0.88,
                              ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

List<AchievementItem> _unlockedAchievements(List<AchievementItem> items) {
  final unlocked = items.where((item) => item.unlocked).toList();
  unlocked.sort((a, b) {
    final left = a.unlockedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final right = b.unlockedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final byTime = right.compareTo(left);
    return byTime == 0 ? a.id.compareTo(b.id) : byTime;
  });
  return unlocked;
}

int _achievementUnlockedScore(List<AchievementItem> items) {
  return items.fold<int>(0, (sum, item) => sum + item.score);
}

class _AchievementPageBackground extends StatelessWidget {
  const _AchievementPageBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0.72, -0.34),
          radius: 0.92,
          colors: [
            const Color(0xFFFFF0C8).withValues(alpha: 0.46),
            const Color(0xFFF6F8F5),
          ],
        ),
      ),
    );
  }
}

class _AchievementEmptyState extends StatelessWidget {
  const _AchievementEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.84),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF20242A).withValues(alpha: 0.08),
              blurRadius: 28,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: const Text(
          '还没有被点亮的里程碑。继续自然地聊天，惊喜会在某个时刻出现。',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF7C8582),
            fontSize: 14,
            height: 1.48,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}
