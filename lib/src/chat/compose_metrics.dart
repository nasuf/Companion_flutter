/// Compose timing for the admin "真人判定" view. Counts only; the draft text
/// never leaves this object.
///
/// A session starts when an empty composer gets text and ends at send or when
/// the composer is emptied. The largest single insertion tells a paste (or a
/// voice-input sentence) from typing, which grows a few characters at a time.
class ComposeMetrics {
  ComposeMetrics({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  DateTime? _startedAt;
  int _maxInsert = 0;
  int _edits = 0;

  void textChanged(String previous, String current) {
    if (current.isEmpty) {
      discard();
      return;
    }
    if (previous.isEmpty) {
      _startedAt = _clock();
      _maxInsert = 0;
      _edits = 0;
    }
    if (_startedAt == null) return;
    _edits += 1;
    final inserted = current.length - previous.length;
    if (inserted > _maxInsert) _maxInsert = inserted;
  }

  /// Text placed by the app itself (restored draft, retry) is not composing.
  void discard() {
    _startedAt = null;
    _maxInsert = 0;
    _edits = 0;
  }

  /// Metrics for the message being sent, then reset. Null when unknown.
  Map<String, int>? take() {
    final started = _startedAt;
    if (started == null) return null;
    final metrics = {
      'compose_ms': _clock().difference(started).inMilliseconds,
      'max_insert_chars': _maxInsert,
      'edit_count': _edits,
    };
    discard();
    return metrics;
  }
}
