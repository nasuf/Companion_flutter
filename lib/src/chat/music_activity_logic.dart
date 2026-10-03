import 'package:companion_flutter/models.dart';
import 'package:companion_flutter/src/chat/game_activity_logic.dart';

class MusicActivitySegment {
  const MusicActivitySegment({
    required this.at,
    required this.action,
    required this.actor,
    required this.sessionId,
    this.trackId = '',
    this.trackTitle = '',
    this.actorName = '',
    this.shared = false,
  });

  final DateTime at;
  final String action;
  final String actor;
  final String sessionId;
  final String trackId;
  final String trackTitle;
  final String actorName;

  /// The server confirmed that this transition includes both participants.
  final bool shared;

  bool get isJoined => action == 'joined';
  bool get isListened => action == 'listened'; // Legacy participant exit.
  bool get isExited => action == 'exited'; // Confirmed shared exit.

  factory MusicActivitySegment.fromJson(
    Map<String, dynamic> json, {
    required DateTime fallbackAt,
    String trackId = '',
    String trackTitle = '',
  }) {
    return MusicActivitySegment(
      at: DateTime.tryParse(json['at']?.toString() ?? '') ?? fallbackAt,
      action: json['action']?.toString() ?? '',
      actor: json['actor']?.toString() ?? '',
      sessionId: json['session_id']?.toString() ?? '',
      trackId: json['track_id']?.toString() ?? trackId,
      trackTitle: json['track_title']?.toString() ?? trackTitle,
      actorName: json['actor_name']?.toString() ?? '',
      shared: json['shared'] == true,
    );
  }

  MusicActivitySegment asShared({bool exited = false}) {
    return MusicActivitySegment(
      at: at,
      action: exited ? 'exited' : 'joined',
      actor: actor,
      sessionId: sessionId,
      trackId: trackId,
      trackTitle: trackTitle,
      actorName: actorName,
      shared: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'at': at.toIso8601String(),
      'action': action,
      'actor': actor,
      'session_id': sessionId,
      'track_id': trackId,
      'track_title': trackTitle,
      if (actorName.isNotEmpty) 'actor_name': actorName,
      if (shared) 'shared': true,
    };
  }
}

List<MusicActivitySegment> musicActivitySegmentsFromMetadata(
  Map<String, dynamic>? metadata, {
  DateTime? fallbackAt,
}) {
  final raw = metadata?['segments'];
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is Map)
        MusicActivitySegment.fromJson(
          Map<String, dynamic>.from(item),
          fallbackAt: fallbackAt ?? DateTime.fromMillisecondsSinceEpoch(0),
          trackId: metadata?['music_track_id']?.toString() ?? '',
          trackTitle: metadata?['music_track_title']?.toString() ?? '',
        ),
  ];
}

List<MusicActivitySegment> segmentsFromMusicActivityMessage(
  ChatMessage message,
) {
  if (message.isMusicActivityBurst) {
    return musicActivitySegmentsFromMetadata(
      message.metadata,
      fallbackAt: message.createdAt,
    );
  }
  if (!message.isMusicStatus) return const [];
  final status = message.metadata?['music_status']?.toString();
  if (status != 'started' && status != 'ended') return const [];
  return [
    MusicActivitySegment(
      at: message.createdAt,
      action: status == 'ended' ? 'listened' : 'joined',
      actor: message.metadata?['music_status_actor']?.toString() ?? '',
      sessionId: message.conversationId,
      trackId: message.metadata?['music_track_id']?.toString() ?? '',
      trackTitle: message.metadata?['music_track_title']?.toString() ?? '',
    ),
  ];
}

String musicSharedStatusLabel(MusicActivitySegment segment) {
  final title = segment.trackTitle.isNotEmpty ? segment.trackTitle : '音乐';
  return segment.isExited ? '你们已退出共听《$title》' : '你们一起在听《$title》';
}

String? musicActivityTimelineLabel(ChatMessage message) {
  final statuses = preprocessMusicActivityMessages([message]).$1;
  return statuses.isEmpty ? null : statuses.last.content;
}

/// Expand old digests into shared transitions and keep new status rows intact.
/// Participant exits never become a listen count or a joint exit by themselves.
(List<ChatMessage> visibleMessages, Set<String> hiddenMessageIds)
preprocessMusicActivityMessages(List<ChatMessage> messages) {
  final events =
      <({ChatMessage message, MusicActivitySegment? segment, int order})>[];
  for (final message in messages) {
    if (!message.isMusicActivityTimeline) {
      events.add((message: message, segment: null, order: events.length));
      continue;
    }
    for (final segment in segmentsFromMusicActivityMessage(message)) {
      events.add((message: message, segment: segment, order: events.length));
    }
  }
  // An old digest's exits may occur after ordinary replies stored beside it.
  events.sort((a, b) {
    final time = (a.segment?.at ?? a.message.createdAt).compareTo(
      b.segment?.at ?? b.message.createdAt,
    );
    return time != 0 ? time : a.order.compareTo(b.order);
  });

  final visible = <ChatMessage>[];
  final projectedById = <String, List<int>>{};
  final agentPresent = <String>{};
  final sharedSessions = <String>{};
  final lastSharedStatus = <String, String>{};
  for (final event in events) {
    final message = event.message;
    final segment = event.segment;
    if (segment == null) {
      visible.add(message);
      continue;
    }
    final sessionId = segment.sessionId.isEmpty
        ? message.conversationId
        : segment.sessionId;
    final session = '${message.conversationId}:$sessionId';
    MusicActivitySegment? shared;
    if (segment.shared && (segment.isJoined || segment.isExited)) {
      shared = segment;
      if (segment.isJoined) {
        agentPresent.add(session);
        sharedSessions.add(session);
      } else {
        agentPresent.remove(session);
        sharedSessions.remove(session);
      }
    } else if (segment.isJoined && segment.actor == 'agent') {
      // Legacy agent joins were emitted only after accepting a user's invite.
      agentPresent.add(session);
      sharedSessions.add(session);
      shared = segment.asShared();
    } else if (segment.isJoined &&
        segment.actor == 'user' &&
        agentPresent.contains(session)) {
      sharedSessions.add(session);
      shared = segment.asShared();
    } else if (segment.isListened && segment.actor == 'agent') {
      // The agent's exit closes the shared session, including its wait period.
      if (sharedSessions.remove(session)) {
        shared = segment.asShared(exited: true);
      }
      agentPresent.remove(session);
    }
    if (shared == null) continue;
    final trackKey = shared.trackId.isNotEmpty
        ? shared.trackId
        : shared.trackTitle;
    final statusKey = '${shared.action}:$trackKey';
    if (lastSharedStatus[session] == statusKey) continue;
    lastSharedStatus[session] = statusKey;
    final positions = projectedById.putIfAbsent(message.id, () => []);
    positions.add(visible.length);
    visible.add(
      ChatMessage(
        id: '${message.id}:music-status:${positions.length}',
        conversationId: message.conversationId,
        role: message.role,
        content: musicSharedStatusLabel(shared),
        createdAt: shared.at,
        metadata: {
          'kind': 'music_activity_burst',
          'music_track_id': shared.trackId,
          'music_track_title': shared.trackTitle,
          'segments': [shared.toJson()],
        },
        read: message.read,
      ),
    );
  }

  // Preserve the server ID for reconciliation, scrolling and history anchors.
  for (final entry in projectedById.entries) {
    final last = entry.value.last;
    visible[last] = visible[last].copyWith(id: entry.key);
  }
  final hidden = {
    for (final message in messages)
      if (message.isMusicActivityTimeline &&
          !projectedById.containsKey(message.id))
        message.id,
  };
  return (visible, hidden);
}

(List<ChatMessage> visibleMessages, Set<String> hiddenMessageIds)
preprocessTimelineActivityMessages(List<ChatMessage> messages) {
  final game = preprocessGameActivityMessages(messages);
  final music = preprocessMusicActivityMessages(game.$1);
  return (music.$1, {...game.$2, ...music.$2});
}
