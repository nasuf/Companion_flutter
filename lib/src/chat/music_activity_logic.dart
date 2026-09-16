import 'package:companion_flutter/models.dart';
import 'package:companion_flutter/src/chat/game_activity_logic.dart';

const Duration kMusicActivityBurstWindow = Duration(minutes: 5);

class MusicActivitySegment {
  const MusicActivitySegment({
    required this.at,
    required this.action,
    required this.actor,
    required this.sessionId,
    this.trackId = '',
    this.trackTitle = '',
    this.actorName = '',
  });

  final DateTime at;
  final String action;
  final String actor;
  final String sessionId;
  final String trackId;
  final String trackTitle;
  final String actorName;

  bool get isJoined => action == 'joined';
  bool get isListened => action == 'listened';

  factory MusicActivitySegment.fromJson(Map<String, dynamic> json) {
    return MusicActivitySegment(
      at: DateTime.tryParse(json['at']?.toString() ?? '') ?? DateTime.now(),
      action: json['action']?.toString() ?? 'joined',
      actor: json['actor']?.toString() ?? '',
      sessionId: json['session_id']?.toString() ?? '',
      trackId: json['track_id']?.toString() ?? '',
      trackTitle: json['track_title']?.toString() ?? '',
      actorName: json['actor_name']?.toString() ?? '',
    );
  }

  MusicActivitySegment withFallback({
    String? trackId,
    String? trackTitle,
    String? actorName,
  }) {
    return MusicActivitySegment(
      at: at,
      action: action,
      actor: actor,
      sessionId: sessionId,
      trackId: this.trackId.isNotEmpty ? this.trackId : (trackId ?? ''),
      trackTitle: this.trackTitle.isNotEmpty
          ? this.trackTitle
          : (trackTitle ?? ''),
      actorName: this.actorName.isNotEmpty
          ? this.actorName
          : (actorName ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'at': at.toIso8601String(),
      'action': action,
      'actor': actor,
      'session_id': sessionId,
      if (trackId.isNotEmpty) 'track_id': trackId,
      if (trackTitle.isNotEmpty) 'track_title': trackTitle,
      if (actorName.isNotEmpty) 'actor_name': actorName,
    };
  }
}

class MusicActivitySummary {
  const MusicActivitySummary({
    required this.trackId,
    required this.trackTitle,
    required this.firstAt,
    required this.lastAt,
    required this.listenCount,
    required this.segments,
  });

  final String trackId;
  final String trackTitle;
  final DateTime firstAt;
  final DateTime lastAt;
  final int listenCount;
  final List<MusicActivitySegment> segments;
}

List<MusicActivitySegment> musicActivitySegmentsFromMetadata(
  Map<String, dynamic>? metadata,
) {
  final raw = metadata?['segments'];
  if (raw is! List) return const [];
  final fallbackTrackId = metadata?['music_track_id']?.toString() ?? '';
  final fallbackTrackTitle = metadata?['music_track_title']?.toString() ?? '';
  final fallbackActorName =
      metadata?['music_status_actor_name']?.toString() ?? '';
  return [
    for (final item in raw)
      if (item is Map)
        MusicActivitySegment.fromJson(
          Map<String, dynamic>.from(item),
        ).withFallback(
          trackId: fallbackTrackId,
          trackTitle: fallbackTrackTitle,
          actorName: fallbackActorName,
        ),
  ];
}

MusicActivityBurstPresentation? parseMusicActivityBurst(ChatMessage message) {
  if (message.isMusicActivityBurst) {
    final segments = musicActivitySegmentsFromMetadata(message.metadata);
    if (segments.isEmpty) return null;
    return MusicActivityBurstPresentation(
      anchorMessage: message,
      segments: segments,
    );
  }
  if (message.isMusicStatus) {
    final status = message.metadata?['music_status']?.toString();
    final actor = message.metadata?['music_status_actor']?.toString() ?? '';
    final action = status == 'ended' ? 'listened' : 'joined';
    if (status == 'started' && actor == 'user') {
      return null;
    }
    return MusicActivityBurstPresentation(
      anchorMessage: message,
      segments: [
        MusicActivitySegment(
          at: message.createdAt,
          action: action,
          actor: actor,
          sessionId: message.conversationId,
          trackId: message.metadata?['music_track_id']?.toString() ?? '',
          trackTitle: message.metadata?['music_track_title']?.toString() ?? '',
          actorName: message.metadata?['music_status_actor_name']?.toString() ??
              '',
        ),
      ],
    );
  }
  return null;
}

class MusicActivityBurstPresentation {
  const MusicActivityBurstPresentation({
    required this.anchorMessage,
    required this.segments,
  });

  final ChatMessage anchorMessage;
  final List<MusicActivitySegment> segments;
}

bool isMusicActivityTimelineMessage(ChatMessage message) {
  return message.isMusicActivityBurst || message.isMusicStatus;
}

List<MusicActivitySegment> segmentsFromMusicActivityMessage(
  ChatMessage message,
) {
  final presentation = parseMusicActivityBurst(message);
  if (presentation == null) return const [];
  return presentation.segments;
}

List<MusicActivitySummary> summarizeMusicActivity(
  List<MusicActivitySegment> segments,
) {
  if (segments.isEmpty) return const [];
  final listened = segments.where((item) => item.isListened).toList();
  final source = listened.isNotEmpty ? listened : segments;
  final order = <String>[];
  final grouped = <String, List<MusicActivitySegment>>{};
  for (final segment in source) {
    final key = segment.trackId.isNotEmpty
        ? 'id:${segment.trackId}'
        : (segment.trackTitle.isNotEmpty
              ? 'title:${segment.trackTitle}'
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
        final listens = items.where((item) => item.isListened).length;
        return MusicActivitySummary(
          trackId: items.first.trackId,
          trackTitle: items.first.trackTitle.isNotEmpty
              ? items.first.trackTitle
              : '共听',
          firstAt: items.first.at,
          lastAt: items.last.at,
          listenCount: listens > 0 ? listens : 1,
          segments: items,
        );
      }(),
  ];
}

(List<ChatMessage> visibleMessages, Set<String> hiddenMessageIds)
preprocessMusicActivityMessages(List<ChatMessage> messages) {
  if (messages.isEmpty) {
    return (messages, const {});
  }
  final hidden = <String>{};
  final visible = <ChatMessage>[];
  var index = 0;
  while (index < messages.length) {
    final current = messages[index];
    if (!isMusicActivityTimelineMessage(current)) {
      visible.add(current);
      index += 1;
      continue;
    }

    final group = <ChatMessage>[current];
    var next = index + 1;
    while (next < messages.length) {
      final candidate = messages[next];
      if (!isMusicActivityTimelineMessage(candidate)) break;
      final gap = candidate.createdAt.difference(group.last.createdAt);
      if (gap > kMusicActivityBurstWindow) break;
      group.add(candidate);
      next += 1;
    }

    final segments = [
      for (final item in group) ...segmentsFromMusicActivityMessage(item),
    ];
    final hadAgentJoin = segments.any(
      (segment) => segment.isJoined && segment.actor == 'agent',
    );
    final hasListened = segments.any((segment) => segment.isListened);
    if (hasListened && !hadAgentJoin) {
      for (final item in group) {
        hidden.add(item.id);
      }
      index = next;
      continue;
    }
    final summaries = summarizeMusicActivity(segments);
    if (summaries.isEmpty) {
      for (final item in group) {
        hidden.add(item.id);
      }
      index = next;
      continue;
    }

    if (group.length == 1 &&
        summaries.length <= 1 &&
        summaries.first.segments.length <= 1 &&
        !summaries.first.segments.first.isListened) {
      hidden.add(group.first.id);
      index = next;
      continue;
    }

    final anchor = group.last;
    final mergedMetadata = Map<String, dynamic>.from(anchor.metadata ?? {});
    mergedMetadata['kind'] = 'music_activity_burst';
    mergedMetadata['segments'] = [
      for (final segment in segments) segment.toJson(),
    ];
    if (summaries.length == 1) {
      mergedMetadata['music_track_id'] ??= summaries.first.trackId;
      mergedMetadata['music_track_title'] = summaries.first.trackTitle;
    } else {
      mergedMetadata.remove('music_track_id');
      mergedMetadata['music_track_title'] = summaries
          .map((item) => item.trackTitle)
          .join('、');
    }
    mergedMetadata['music_status_actor_name'] ??=
        anchor.metadata?['music_status_actor_name']?.toString() ?? '';

    visible.add(
      ChatMessage(
        id: anchor.id,
        conversationId: anchor.conversationId,
        role: anchor.role,
        content: collapsedMusicActivityLabel(summaries),
        createdAt: anchor.createdAt,
        metadata: mergedMetadata,
        read: anchor.read,
      ),
    );
    for (final item in group.where((message) => message.id != anchor.id)) {
      hidden.add(item.id);
    }
    index = next;
  }
  return (visible, hidden);
}

String collapsedMusicActivityLabel(List<MusicActivitySummary> summaries) {
  if (summaries.isEmpty) return '刚才打开了共听';
  final listened = summaries.any(
    (item) => item.segments.any((segment) => segment.isListened),
  );
  if (!listened) {
    return summaries.length == 1
        ? '刚才打开了共听'
        : '刚才打开了 ${summaries.length} 次共听';
  }
  if (summaries.length == 1) {
    return '一起听了《${summaries.first.trackTitle}》';
  }
  return '一起听了 ${summaries.length} 首歌';
}

String musicActivityDigestHeading(List<MusicActivitySummary> summaries) {
  if (summaries.length <= 1) {
    return summaries.isEmpty
        ? '刚才的共听'
        : '《${summaries.first.trackTitle}》';
  }
  return '刚才的共听';
}

String formatMusicActivityClock(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String formatMusicActivityTimeRange(List<MusicActivitySummary> summaries) {
  if (summaries.isEmpty) return '';
  final first = summaries.first.firstAt;
  final last = summaries.last.lastAt;
  final start = formatMusicActivityClock(first);
  final end = formatMusicActivityClock(last);
  if (start == end) return start;
  return '$start – $end';
}

bool canOpenMusicActivityDigest(List<MusicActivitySummary> summaries) {
  if (summaries.length > 1) return true;
  if (summaries.isEmpty) return false;
  return summaries.first.segments.length > 1;
}

(List<ChatMessage> visibleMessages, Set<String> hiddenMessageIds)
preprocessTimelineActivityMessages(List<ChatMessage> messages) {
  final gameProcessed = preprocessGameActivityMessages(messages);
  return preprocessMusicActivityMessages(gameProcessed.$1);
}
