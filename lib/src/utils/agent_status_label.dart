/// Chat header status chip: occupancy only, never the current activity.
String? formatAgentStatusLabel({
  required String? status,
  required String? label,
}) {
  final cleanStatus = status?.trim();
  return _firstNonEmpty(label, switch (cleanStatus) {
    'idle' => '空闲',
    'busy' => '忙碌',
    'very_busy' => '很忙碌',
    'sleep' => '睡眠',
    _ => cleanStatus,
  });
}

String? _firstNonEmpty(String? primary, String? fallback) {
  final cleanPrimary = primary?.trim();
  if (cleanPrimary != null && cleanPrimary.isNotEmpty) return cleanPrimary;
  final cleanFallback = fallback?.trim();
  if (cleanFallback != null && cleanFallback.isNotEmpty) return cleanFallback;
  return null;
}
