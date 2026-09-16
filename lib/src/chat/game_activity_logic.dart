import 'package:companion_flutter/models.dart';

const Duration kGameActivityBurstWindow = Duration(minutes: 5);

class GameActivitySegment {
  const GameActivitySegment({
    required this.at,
    required this.action,
    required this.sessionId,
    this.quickExit = false,
  });

  final DateTime at;
  final String action;
  final String sessionId;
  final bool quickExit;

  bool get isEnter => action == 'enter';
  bool get isExit => action == 'exit';

  factory GameActivitySegment.fromJson(Map<String, dynamic> json) {
    return GameActivitySegment(
      at: DateTime.tryParse(json['at']?.toString() ?? '') ?? DateTime.now(),
      action: json['action']?.toString() ?? 'enter',
      sessionId: json['session_id']?.toString() ?? '',
      quickExit: json['quick_exit'] == true,
    );
  }
}

List<GameActivitySegment> gameActivitySegmentsFromMetadata(
  Map<String, dynamic>? metadata,
) {
  final raw = metadata?['segments'];
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is Map)
        GameActivitySegment.fromJson(Map<String, dynamic>.from(item)),
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
  if (message.isGameActivityBurst) {
    return message.metadata?['game_key']?.toString();
  }
  if (message.isGameStatus) {
    return message.metadata?['game_key']?.toString();
  }
  return null;
}

String? gameActivityGroupKey(ChatMessage message) {
  final gameKey = gameActivityGameKey(message);
  if (gameKey != null && gameKey.isNotEmpty) {
    return gameKey;
  }
  final gameTitle = message.metadata?['game_title']?.toString().trim();
  if (gameTitle != null && gameTitle.isNotEmpty) {
    return 'title:$gameTitle';
  }
  return null;
}

bool isGameActivityTimelineMessage(ChatMessage message) {
  return message.isGameActivityBurst || message.isGameStatus;
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

    final gameKey = gameActivityGroupKey(current) ?? '';
    final group = <ChatMessage>[current];
    var next = index + 1;
    while (next < messages.length) {
      final candidate = messages[next];
      if (!isGameActivityTimelineMessage(candidate)) break;
      final candidateKey = gameActivityGroupKey(candidate) ?? '';
      if (gameKey.isNotEmpty &&
          candidateKey.isNotEmpty &&
          gameKey != candidateKey) {
        break;
      }
      final gap = candidate.createdAt.difference(group.last.createdAt);
      if (gap > kGameActivityBurstWindow) break;
      group.add(candidate);
      next += 1;
    }

    if (group.length == 1) {
      visible.add(group.first);
    } else {
      final anchor = group.last;
      final segments = <GameActivitySegment>[];
      for (final item in group) {
        if (item.isGameActivityBurst) {
          segments.addAll(gameActivitySegmentsFromMetadata(item.metadata));
        } else {
          final presentation = parseGameActivityBurst(item);
          if (presentation != null) {
            segments.addAll(presentation.segments);
          }
        }
      }
      final mergedMetadata = Map<String, dynamic>.from(anchor.metadata ?? {});
      mergedMetadata['kind'] = 'game_activity_burst';
      mergedMetadata['segments'] = [
        for (final segment in segments)
          {
            'at': segment.at.toIso8601String(),
            'action': segment.action,
            'session_id': segment.sessionId,
            if (segment.quickExit) 'quick_exit': true,
          },
      ];
      mergedMetadata['game_key'] ??= gameActivityGameKey(anchor) ?? gameKey;
      mergedMetadata['game_title'] ??=
          anchor.metadata?['game_title']?.toString() ?? '游戏';
      mergedMetadata['game_status_actor_name'] ??=
          anchor.metadata?['game_status_actor_name']?.toString() ?? '';

      visible.add(
        ChatMessage(
          id: anchor.id,
          conversationId: anchor.conversationId,
          role: anchor.role,
          content: collapsedGameActivityLabel(
            gameTitle: mergedMetadata['game_title']?.toString() ?? '游戏',
            actorName:
                mergedMetadata['game_status_actor_name']?.toString() ?? '',
            segments: segments,
          ),
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

String collapsedGameActivityLabel({
  required String gameTitle,
  required String actorName,
  required List<GameActivitySegment> segments,
}) {
  if (segments.length <= 1) {
    final action = segments.isEmpty ? 'enter' : segments.first.action;
    final prefix = actorName.isNotEmpty ? '$actorName 和你' : '你们';
    final verb = action == 'exit' ? '退出' : '进入';
    return '$prefix已$verb游戏《$gameTitle》';
  }
  final first = segments.first.at;
  final last = segments.last.at;
  final sameDay =
      first.year == last.year &&
      first.month == last.month &&
      first.day == last.day;
  final timePart = sameDay
      ? '${formatGameActivityClock(first)}–${formatGameActivityClock(last)} '
      : '';
  return '$timePart《$gameTitle》进出 ${segments.length} 次';
}

String formatGameActivityClock(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String expandedGameActivitySegmentLabel({
  required GameActivitySegment segment,
  required String gameTitle,
  required String actorName,
}) {
  final prefix = actorName.isNotEmpty ? '$actorName 和你' : '你们';
  final verb = segment.isExit ? '退出' : '进入';
  return '$prefix已$verb游戏《$gameTitle》';
}
