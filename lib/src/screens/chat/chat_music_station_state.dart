part of 'package:companion_flutter/main.dart';

class ChatMusicStationState {
  ChatComponentCard? card;
  String? messageId;
  String? library;
  String? lastTrackId;
  bool? lastPlaying;
  bool? lastLoading;
  String? activeMessageId;

  final Map<String, Duration> cardPositions = {};
  List<MusicTrack> history = const [];
  int historyIndex = -1;

  static bool isMusicCard(ChatComponentCard? card) {
    return card?.type == 'music_track';
  }

  static MusicTrack? trackFromCard(ChatComponentCard? card) {
    if (!isMusicCard(card)) return null;
    final rawTrack = card!.payload['track'];
    return rawTrack is Map
        ? MusicTrack.fromJson(Map<String, dynamic>.from(rawTrack))
        : null;
  }

  static String? libraryFromCard(ChatComponentCard? card) {
    if (!isMusicCard(card)) return null;
    final payloadLibrary = card!.payload['library']?.toString().trim();
    if (payloadLibrary != null && payloadLibrary.isNotEmpty) {
      return payloadLibrary;
    }
    final trackLibrary = trackFromCard(card)?.library.trim();
    return trackLibrary == null || trackLibrary.isEmpty ? null : trackLibrary;
  }

  void reset() {
    card = null;
    messageId = null;
    library = null;
    lastTrackId = null;
    lastPlaying = null;
    lastLoading = null;
    activeMessageId = null;
    cardPositions.clear();
    history = const [];
    historyIndex = -1;
  }

  bool adopt(ChatComponentCard nextCard, String nextMessageId) {
    final nextLibrary = libraryFromCard(nextCard);
    final seedTrack = trackFromCard(nextCard);
    if (nextLibrary == null || seedTrack == null) return false;
    final changed =
        card?.title != nextCard.title ||
        messageId != nextMessageId ||
        library != nextLibrary;
    card = nextCard;
    messageId = nextMessageId;
    library = nextLibrary;
    remember(seedTrack);
    return changed;
  }

  bool adoptLatestFrom(List<ChatMessage> messages) {
    for (final message in messages.reversed) {
      final nextCard = message.componentCard;
      if (!isMusicCard(nextCard)) continue;
      return adopt(nextCard!, message.id);
    }
    return false;
  }

  void activate(ChatComponentCard nextCard, String nextMessageId) {
    activeMessageId = nextMessageId;
    adopt(nextCard, nextMessageId);
  }

  void acknowledgeMessageId(String clientId, String serverMessageId) {
    if (messageId == clientId) {
      messageId = serverMessageId;
    }
    if (activeMessageId == clientId) {
      activeMessageId = serverMessageId;
      final cachedPosition = cardPositions.remove(clientId);
      if (cachedPosition != null) {
        cardPositions[serverMessageId] = cachedPosition;
      }
    }
  }

  void cacheActivePosition(MusicTrack? playbackTrack, Duration position) {
    final id = activeMessageId;
    if (id == null || playbackTrack == null) return;
    cardPositions[id] = position;
  }

  void remember(MusicTrack track) {
    if (library != null && track.library != library) return;
    if (historyIndex >= 0 &&
        historyIndex < history.length &&
        history[historyIndex].id == track.id) {
      history = [
        ...history.take(historyIndex),
        track,
        ...history.skip(historyIndex + 1),
      ];
      return;
    }
    final keptHistory = historyIndex < 0
        ? const <MusicTrack>[]
        : history.take(historyIndex + 1).toList();
    final withoutDuplicate = keptHistory
        .where((item) => item.id != track.id)
        .toList();
    history = [...withoutDuplicate, track];
    historyIndex = history.length - 1;
  }

  MusicTrack? currentTrack(MusicTrack? liveTrack) {
    if (library != null && liveTrack != null && liveTrack.library == library) {
      return liveTrack;
    }
    if (historyIndex >= 0 && historyIndex < history.length) {
      return history[historyIndex];
    }
    return trackFromCard(card);
  }

  bool get canGoPrevious => historyIndex > 0;

  MusicTrack? movePrevious() {
    if (!canGoPrevious) return null;
    historyIndex -= 1;
    return history[historyIndex];
  }
}
