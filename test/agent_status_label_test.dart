import 'package:companion_flutter/src/utils/agent_status_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prefers the backend occupancy label over the status code', () {
    expect(
      formatAgentStatusLabel(status: 'very_busy', label: '很忙碌'),
      '很忙碌',
    );
    expect(formatAgentStatusLabel(status: 'idle', label: '空闲'), '空闲');
  });

  test('falls back to occupancy words when the label is missing', () {
    expect(formatAgentStatusLabel(status: 'idle', label: null), '空闲');
    expect(formatAgentStatusLabel(status: 'busy', label: ' '), '忙碌');
    expect(formatAgentStatusLabel(status: 'very_busy', label: null), '很忙碌');
    expect(formatAgentStatusLabel(status: 'sleep', label: null), '睡眠');
  });

  test('does not append the current activity after the occupancy flag', () {
    expect(
      formatAgentStatusLabel(status: 'very_busy', label: '很忙碌'),
      isNot(contains('·')),
    );
  });

  test('returns null when neither label nor status is available', () {
    expect(formatAgentStatusLabel(status: null, label: null), isNull);
    expect(formatAgentStatusLabel(status: '  ', label: ''), isNull);
  });
}
