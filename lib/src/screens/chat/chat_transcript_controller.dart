import 'package:companion_flutter/models.dart';
import 'package:flutter/foundation.dart';

/// Transcript + message-column UI state for [ChatPage].
///
/// Mutations should go through [ChatPage]'s `_notifyTranscript` helper so the
/// message list rebuilds without rebuilding header/composer/music chrome.
class ChatTranscriptController extends ChangeNotifier {
  final List<ChatMessage> messages = [];

  bool loadingInitial = true;
  bool loadingOlder = false;
  bool hasOlderMessages = false;
  bool agentTyping = false;
  String? historyError;
  int newMessageCount = 0;
  int loadedServerMessages = 0;

  bool isJumpedToHistory = false;
  int jumpOldestRank = 0;
  int jumpNewestRank = 0;
  bool hasMoreOlderJump = false;
  bool hasMoreNewerJump = false;
  bool loadingOlderJump = false;
  bool loadingNewerJump = false;

  String? highlightMessageId;
  bool highlightVisible = false;
  String? highlightQuery;

  void publish() => notifyListeners();

  void resetForConversationSwitch() {
    messages.clear();
    loadingInitial = true;
    loadingOlder = false;
    hasOlderMessages = false;
    agentTyping = false;
    historyError = null;
    newMessageCount = 0;
    loadedServerMessages = 0;
    isJumpedToHistory = false;
    jumpOldestRank = 0;
    jumpNewestRank = 0;
    hasMoreOlderJump = false;
    hasMoreNewerJump = false;
    loadingOlderJump = false;
    loadingNewerJump = false;
    highlightMessageId = null;
    highlightVisible = false;
    highlightQuery = null;
  }
}
