import 'dart:async';
import 'package:flutter/material.dart';
import '../../../task_waiting.dart';

class TaskWaitingCard extends StatefulWidget {
  const TaskWaitingCard({
    super.key,
    required this.task,
    required this.resume,
    required this.cancel,
    required this.onAccepted,
  });
  final WaitingTask task;
  final Future<void> Function(WaitingTask task, Map<String, dynamic> response)
  resume;
  final Future<void> Function(WaitingTask task) cancel;
  final void Function(WaitingTask task) onAccepted;
  @override
  State<TaskWaitingCard> createState() => _TaskWaitingCardState();
}

class _TaskWaitingCardState extends State<TaskWaitingCard> {
  final _text = TextEditingController();
  bool _busy = false;
  bool _expired = false;
  String? _error;
  Timer? _expiry;
  int _actionGeneration = 0;

  @override
  void initState() {
    super.initState();
    _setDeadline();
  }

  @override
  void didUpdateWidget(covariant TaskWaitingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.task;
    final current = widget.task;
    if (old.runId != current.runId ||
        old.pendingId != current.pendingId ||
        old.revision != current.revision ||
        old.sequence != current.sequence ||
        old.expiresAt != current.expiresAt) {
      _actionGeneration++;
      _busy = false;
      _error = null;
      _text.clear();
      _setDeadline();
    }
  }

  void _setDeadline() {
    _expiry?.cancel();
    final remaining = widget.task.expiresAt.difference(DateTime.now());
    _expired = remaining <= Duration.zero;
    if (!_expired) {
      _expiry = Timer(remaining, () {
        if (mounted) setState(() => _expired = true);
      });
    }
  }

  @override
  void dispose() {
    _expiry?.cancel();
    _text.dispose();
    super.dispose();
  }

  Future<void> _act([Map<String, dynamic>? response]) async {
    if (_busy || _expired) return;
    if (!widget.task.expiresAt.isAfter(DateTime.now())) {
      setState(() => _expired = true);
      return;
    }
    final task = widget.task;
    final accepted = widget.onAccepted;
    final generation = ++_actionGeneration;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (response == null) {
        await widget.cancel(task);
      } else {
        await widget.resume(task, response);
      }
      if (mounted && generation == _actionGeneration) accepted(task);
    } catch (error) {
      if (mounted && generation == _actionGeneration) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && generation == _actionGeneration) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.task.question),
          if (widget.task.preview != null)
            Text(widget.task.preview!)
          else
            TextField(
              controller: _text,
              enabled: !_busy && !_expired,
              maxLength: 2000,
              decoration: const InputDecoration(labelText: '补充信息'),
              onChanged: (_) => setState(() {}),
            ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_expired)
            const Text('这项确认已过期，请重新发起。')
          else
            Wrap(
              children: [
                TextButton(
                  onPressed:
                      _busy ||
                          (widget.task.preview == null &&
                              _text.text.trim().isEmpty)
                      ? null
                      : () => unawaited(
                          _act(
                            widget.task.preview != null
                                ? {'approved': true}
                                : {'text': _text.text.trim()},
                          ),
                        ),
                  child: Text(
                    _busy
                        ? '提交中…'
                        : widget.task.preview != null
                        ? '确认操作'
                        : '继续',
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : () => unawaited(_act()),
                  child: const Text('取消任务'),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}
