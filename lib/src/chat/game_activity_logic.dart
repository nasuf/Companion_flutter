import 'package:companion_flutter/models.dart';

const Duration kGameActivityBurstWindow = Duration(minutes: 5);

class GameActivitySegment {
  const GameActivitySegment({
    required this.at,
    required this.action,
    required this.sessionId,
    this.gameKey = '',
    this.gameTitle = '',
    this.quickExit = false,
  });

  final DateTime at;
  final String action;
  final String sessionId;
  final String gameKey;
  final String gameTitle;
  final bool quickExit;

  bool get isEnter => action == 'enter';
  bool get isExit => action == 'exit' || action == 'played';

  factory GameActivitySegment.fromJson(Map<String, dynamic> json) {
    return GameActivitySegment(
      at: DateTime.tryParse(json['at']?.toString() ?? '') ?? DateTime.now(),
      action: json['action']?.toString() ?? 'enter',
      sessionId: json['session_id']?.toString() ?? '',
      gameKey: json['game_key']?.toString() ?? '',
      gameTitle: json['game_title']?.toString() ?? '',
      quickExit: json['quick_exit'] == true,
    );
  }

  GameActivitySegment withFallback({
    String? gameKey,
    String? gameTitle,
  }) {
    return GameActivitySegment(
      at: at,
      action: action,
      sessionId: sessionId,
      gameKey: this.gameKey.isNotEmpty ? this.gameKey : (gameKey ?? ''),
      gameTitle: this.gameTitle.isNotEmpty
          ? this.gameTitle
          : (gameTitle ?? ''),
      quickExit: quickExit,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'at': at.toIso8601String(),
      'action': action,
      'session_id': sessionId,
      if (gameKey.isNotEmpty) 'game_key': gameKey,
      if (gameTitle.isNotEmpty) 'game_title': gameTitle,
      if (quickExit) 'quick_exit': true,
    };
  }
}

class GameActivitySummary {
  const GameActivitySummary({
    required this.gameKey,
    required this.gameTitle,
    required this.firstAt,
    required this.lastAt,
    required this.visitCount,
    required this.segments,
  });

  final String gameKey;
  final String gameTitle;
  final DateTime firstAt;
  final DateTime lastAt;
  final int visitCount;
  final List<GameActivitySegment> segments;
}

List<GameActivitySegment> gameActivitySegmentsFromMetadata(
  Map<String, dynamic>? metadata,
) {
  final raw = metadata?['segments'];
  if (raw is! List) return const [];
  final fallbackKey = metadata?['game_key']?.toString() ?? '';
  final fallbackTitle = metadata?['game_title']?.toString() ?? '';
  return [
    for (final item in raw)
      if (item is Map)
        GameActivitySegment.fromJson(
          Map<String, dynamic>.from(item),
        ).withFallback(gameKey: fallbackKey, gameTitle: fallbackTitle),
  ];
}

GameActivityBurstPresentation? parseGameActivityBurst(ChatMessage message) {
  if (message.isGameActivityBurst) {
    final segments = gameActivitySegmentsFromMetadata(message.metadata);
    if (segments.isEmpty) return null;
    return GameActivityBurstPresentation(
      anchorMessage: message,
      segments: segments,
    );
  }
  if (message.isGameStatus) {
    final status = message.metadata?['game_status']?.toString();
    final sessionId =
        message.metadata?['session_id']?.toString() ??
        message.metadata?['game_session_id']?.toString() ??
        '';
    return GameActivityBurstPresentation(
      anchorMessage: message,
      segments: [
        GameActivitySegment(
          at: message.createdAt,
          action: status == 'ended' ? 'exit' : 'enter',
          sessionId: sessionId,
          gameKey: message.metadata?['game_key']?.toString() ?? '',
          gameTitle: message.metadata?['game_title']?.toString() ?? '',
        ),
      ],
    );
  }
  return null;
}

class GameActivityBurstPresentation {
  const GameActivityBurstPresentation({
    required this.anchorMessage,
    required this.segments,
  });

  final ChatMessage anchorMessage;
  final List<GameActivitySegment> segments;
}

String? gameActivityGameKey(ChatMessage message) {
  final key = message.metadata?['game_key']?.toString().trim();
  if (key != null && key.isNotEmpty) return key;
  return null;
}

String? gameActivityGameTitle(ChatMessage message) {
  final title = message.metadata?['game_title']?.toString().trim();
  if (title != null && title.isNotEmpty) return title;
  return null;
}

bool isGameActivityTimelineMessage(ChatMessage message) {
  return message.isGameActivityBurst || message.isGameStatus;
}

List<GameActivitySegment> segmentsFromGameActivityMessage(ChatMessage message) {
  final presentation = parseGameActivityBurst(message);
  if (presentation == null) return const [];
  return [
    for (final segment in presentation.segments)
      segment.withFallback(
        gameKey: gameActivityGameKey(message),
        gameTitle: gameActivityGameTitle(message),
      ),
  ];
}

List<GameActivitySummary> summarizeGameActivity(
  List<GameActivitySegment> segments,
) {
  if (segments.isEmpty) return const [];
  final order = <String>[];
  final grouped = <String, List<GameActivitySegment>>{};
  for (final segment in segments) {
    final key = segment.gameKey.isNotEmpty
        ? 'key:${segment.gameKey}'
        : (segment.gameTitle.isNotEmpty
              ? 'title:${segment.gameTitle}'
              : 'unknown');
    if (!grouped.containsKey(key)) {
      order.add(key);
      grouped[key] = [];
    }
    grouped[key]!.add(segment);
  }
  return [
    for (final key in order)
      () {
        final items = grouped[key]!;
        final sessions = {
          for (final item in items)
            if (item.sessionId.isNotEmpty) item.sessionId,
        };
        final enters = items.where((item) => item.isEnter).length;
        return GameActivitySummary(
          gameKey: items.first.gameKey,
          gameTitle: items.first.gameTitle.isNotEmpty
              ? items.first.gameTitle
              : '游戏',
          firstAt: items.first.at,
          lastAt: items.last.at,
          visitCount: enters > 0
              ? enters
              : (sessions.isNotEmpty ? sessions.length : 1),
          segments: items,
        );
      }(),
  ];
}

(List<ChatMessage> visibleMessages, Set<String> hiddenMessageIds)
preprocessGameActivityMessages(List<ChatMessage> messages) {
  if (messages.isEmpty) {
    return (messages, const {});
  }
  final hidden = <String>{};
  final visible = <ChatMessage>[];
  var index = 0;
  while (index < messages.length) {
    final current = messages[index];
    if (!isGameActivityTimelineMessage(current)) {
      visible.add(current);
      index += 1;
      continue;
    }

    final group = <ChatMessage>[current];
    var next = index + 1;
    while (next < messages.length) {
      final candidate = messages[next];
      if (!isGameActivityTimelineMessage(candidate)) break;
      final gap = candidate.createdAt.difference(group.last.createdAt);
      if (gap > kGameActivityBurstWindow) break;
      group.add(candidate);
      next += 1;
    }

    if (group.length == 1 &&
        summarizeGameActivity(
          segmentsFromGameActivityMessage(group.first),
        ).length <=
            1) {
      visible.add(_messageWithDigestContent(group.first));
    } else {
      final anchor = group.last;
      final segments = [
        for (final item in group) ...segmentsFromGameActivityMessage(item),
      ];
      final summaries = summarizeGameActivity(segments);
      final mergedMetadata = Map<String, dynamic>.from(anchor.metadata ?? {});
      mergedMetadata['kind'] = 'game_activity_burst';
      mergedMetadata['segments'] = [
        for (final segment in segments) segment.toJson(),
      ];
      if (summaries.length == 1) {
        mergedMetadata['game_key'] ??= summaries.first.gameKey;
        mergedMetadata['game_title'] = summaries.first.gameTitle;
      } else {
        mergedMetadata.remove('game_key');
        mergedMetadata['game_title'] = summaries
            .map((item) => item.gameTitle)
            .join('、');
      }
      mergedMetadata['game_status_actor_name'] ??=
          anchor.metadata?['game_status_actor_name']?.toString() ?? '';

      visible.add(
        ChatMessage(
          id: anchor.id,
          conversationId: anchor.conversationId,
          role: anchor.role,
          content: collapsedGameActivityLabel(summaries),
          createdAt: anchor.createdAt,
          metadata: mergedMetadata,
          read: anchor.read,
        ),
      );
      for (final item in group.where((message) => message.id != anchor.id)) {
        hidden.add(item.id);
      }
    }
    index = next;
  }
  return (visible, hidden);
}

ChatMessage _messageWithDigestContent(ChatMessage message) {
  return ChatMessage(
    id: message.id,
    conversationId: message.conversationId,
    role: message.role,
    content: _digestContentFor(message),
    createdAt: message.createdAt,
    metadata: message.metadata,
    pending: message.pending,
    read: message.read,
    failed: message.failed,
  );
}

String _digestContentFor(ChatMessage message) {
  return collapsedGameActivityLabel(
    summarizeGameActivity(segmentsFromGameActivityMessage(message)),
  );
}

String collapsedGameActivityLabel(List<GameActivitySummary> summaries) {
  if (summaries.isEmpty) return '刚才的游戏';
  final played = summaries.any(
    (item) => item.segments.any((segment) => segment.action == 'played'),
  );
  if (summaries.length == 1) {
    final title = summaries.first.gameTitle;
    return played ? '一起玩了《$title》' : '刚才点开了《$title》';
  }
  return played
      ? '一起玩了 ${summaries.length} 款游戏'
      : '刚才点开了 ${summaries.length} 款游戏';
}

String gameActivityDigestHeading(List<GameActivitySummary> summaries) {
  if (summaries.length <= 1) {
    return summaries.isEmpty ? '刚才的游戏' : '《${summaries.first.gameTitle}》';
  }
  return '刚才的游戏';
}

String formatGameActivityClock(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String formatGameActivityTimeRange(List<GameActivitySummary> summaries) {
  if (summaries.isEmpty) return '';
  final first = summaries.first.firstAt;
  final last = summaries.last.lastAt;
  final start = formatGameActivityClock(first);
  final end = formatGameActivityClock(last);
  if (start == end) return start;
  return '$start – $end';
}

String expandedGameActivitySegmentLabel(GameActivitySegment segment) {
  final title = segment.gameTitle.isNotEmpty ? segment.gameTitle : '游戏';
  final verb = segment.isExit ? '退出' : '进入';
  return '$verb《$title》';
}

bool canOpenGameActivityDigest(List<GameActivitySummary> summaries) {
  if (summaries.length > 1) return true;
  if (summaries.isEmpty) return false;
  return summaries.first.segments.length > 1;
}
