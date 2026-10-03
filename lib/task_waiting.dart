import 'models.dart';

class WaitingTask {
  const WaitingTask({
    required this.runId,
    required this.pendingId,
    required this.revision,
    required this.sequence,
    required this.expiresAt,
    required this.question,
    this.preview,
  });
  final String runId;
  final String pendingId;
  final int revision;
  final int sequence;
  final DateTime expiresAt;
  final String question;
  final String? preview;
}

class TaskViewState {
  const TaskViewState(this.sequence, [this.waiting]);
  final int sequence;
  final WaitingTask? waiting;
}

TaskViewState? taskEvent(
  TaskViewState? previous,
  WsEnvelope event, {
  DateTime? now,
}) {
  final data = event.data;
  if (!['task_waiting', 'task_state', 'done'].contains(event.type) ||
      data['agent_run_id'] is! String ||
      (data['agent_run_id'] as String).isEmpty) {
    return previous;
  }
  if (event.type == 'done' && previous == null && data['task_status'] == null) {
    return previous;
  }
  final sequence = data['event_sequence'];
  if (sequence is! int ||
      sequence < 1 ||
      (previous != null && sequence <= previous.sequence)) {
    return previous;
  }
  if (event.type != 'task_waiting' ||
      data['actionable'] != true ||
      data['run_status'] != 'waiting' ||
      data['cancel_requested'] == true) {
    return TaskViewState(sequence);
  }
  final expiresAt = data['expires_at'] is String
      ? DateTime.tryParse(data['expires_at'] as String)
      : null;
  final pendingId = data['pending_action_id'];
  final revision = data['revision'];
  if (expiresAt == null ||
      !expiresAt.isAfter(now ?? DateTime.now()) ||
      pendingId is! String ||
      pendingId.isEmpty ||
      revision is! int ||
      revision < 1) {
    return TaskViewState(sequence);
  }
  final proposal = data['proposal'];
  return TaskViewState(
    sequence,
    WaitingTask(
      runId: data['agent_run_id'] as String,
      pendingId: pendingId,
      revision: revision,
      sequence: sequence,
      expiresAt: expiresAt,
      question: data['question'] is String
          ? data['question'] as String
          : '请补充信息后继续。',
      preview: proposal is Map && proposal['preview'] is String
          ? proposal['preview'] as String
          : null,
    ),
  );
}
