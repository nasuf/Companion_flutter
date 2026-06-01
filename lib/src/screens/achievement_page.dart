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
  _AchievementFilter _filter = _AchievementFilter.all;

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
    return Scaffold(
      backgroundColor: AppColors.page,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<AchievementsResponse>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _AchievementError(
                message: '${snapshot.error}',
                onRetry: _retry,
              );
            }
            final data = snapshot.data!;
            final items = _filteredAchievements(data.items, _filter);
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _AchievementHeader(data: data)),
                SliverToBoxAdapter(
                  child: _AchievementFilterBar(
                    value: _filter,
                    data: data,
                    onChanged: (value) => setState(() => _filter = value),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final item = items[index];
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
                    }, childCount: items.length),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.04,
                        ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

enum _AchievementFilter { all, unlocked, locked }

List<AchievementItem> _filteredAchievements(
  List<AchievementItem> items,
  _AchievementFilter filter,
) {
  return switch (filter) {
    _AchievementFilter.unlocked =>
      items.where((item) => item.unlocked).toList(),
    _AchievementFilter.locked => items.where((item) => !item.unlocked).toList(),
    _AchievementFilter.all => items,
  };
}
