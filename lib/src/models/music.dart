part of 'package:companion_flutter/models.dart';

/// 音乐时长上报结果：`POST /music/quota/report`。
enum MusicQuotaAction { none, confirmTicket, buyCoupon, buyVip }

class MusicQuotaReport {
  const MusicQuotaReport({
    required this.action,
    required this.acceptedSeconds,
    required this.pendingSeconds,
    required this.ticketCost,
  });

  final MusicQuotaAction action;
  final int acceptedSeconds;
  final int pendingSeconds;
  final int ticketCost;

  factory MusicQuotaReport.fromJson(Map<String, dynamic> json) {
    return MusicQuotaReport(
      action: _parseMusicQuotaAction(json['action']?.toString()),
      acceptedSeconds: (json['accepted_seconds'] as num?)?.round() ?? 0,
      pendingSeconds: (json['pending_seconds'] as num?)?.round() ?? 0,
      ticketCost: (json['ticket_cost'] as num?)?.round() ?? 0,
    );
  }
}

MusicQuotaAction _parseMusicQuotaAction(String? value) {
  switch (value) {
    case 'confirm_ticket':
      return MusicQuotaAction.confirmTicket;
    case 'buy_coupon':
      return MusicQuotaAction.buyCoupon;
    case 'buy_vip':
      return MusicQuotaAction.buyVip;
    default:
      return MusicQuotaAction.none;
  }
}


class MusicTrack {
  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.library,
    required this.url,
    required this.durationSec,
    required this.coverKey,
    required this.accentA,
    required this.accentB,
    required this.source,
    required this.isFavorite,
    required this.playedByAgent,
    this.metadata = const {},
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final String library;
  final String url;
  final int durationSec;
  final String coverKey;
  final String accentA;
  final String accentB;
  final String source;
  final bool isFavorite;
  final bool playedByAgent;
  final Map<String, dynamic> metadata;

  String? get coverImageUrl {
    final direct =
        _metadataString(metadata['image']) ??
        _metadataString(metadata['album_image']) ??
        _metadataString(metadata['cover_image']) ??
        _metadataString(metadata['cover_url']);
    if (direct != null) return direct;
    final raw = metadata['raw'];
    if (raw is Map) {
      return _metadataString(raw['image']) ??
          _metadataString(raw['album_image']) ??
          _metadataString(raw['cover_image']) ??
          _metadataString(raw['cover_url']);
    }
    return null;
  }

  String get coverAsset => 'assets/prototype/music/$visualCoverKey';
  String get visualCoverKey {
    final cleanCover = coverKey.trim();
    final generatedSource = source == 'jamendo' || source == 'mock';
    if (!generatedSource &&
        cleanCover.isNotEmpty &&
        cleanCover != 'music-cover-01.jpg') {
      return cleanCover;
    }
    final seed = '$id|$title|$url|$library';
    var hash = 17;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    final index = (hash % 11) + 1;
    return 'music-cover-${index.toString().padLeft(2, '0')}.jpg';
  }

  static String? _metadataString(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text == 'null') return null;
    if (!text.startsWith('http://') && !text.startsWith('https://')) {
      return null;
    }
    return text;
  }

  String get durationLabel {
    if (durationSec <= 0) return '--:--';
    final minutes = durationSec ~/ 60;
    final seconds = durationSec % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  factory MusicTrack.fromJson(Map<String, dynamic> json) {
    return MusicTrack(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Audio',
      artist: json['artist'] as String? ?? 'Jamendo',
      album: json['album'] as String? ?? 'Jamendo Library',
      library: json['library'] as String? ?? 'focus',
      url: json['url'] as String? ?? '',
      durationSec: (json['duration_sec'] as num?)?.round() ?? 0,
      coverKey: json['cover_key'] as String? ?? 'music-cover-01.jpg',
      accentA: json['accent_a'] as String? ?? '#1f6fff',
      accentB: json['accent_b'] as String? ?? '#18c6c0',
      source: json['source'] as String? ?? 'jamendo',
      isFavorite: json['is_favorite'] as bool? ?? false,
      playedByAgent: json['played_by_agent'] as bool? ?? false,
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'library': library,
      'url': url,
      'duration_sec': durationSec,
      'cover_key': visualCoverKey,
      'accent_a': accentA,
      'accent_b': accentB,
      'source': source,
      'metadata': metadata,
    };
  }

  MusicTrack copyWith({
    String? url,
    bool? isFavorite,
    bool? playedByAgent,
    Map<String, dynamic>? metadata,
  }) {
    return MusicTrack(
      id: id,
      title: title,
      artist: artist,
      album: album,
      library: library,
      url: url ?? this.url,
      durationSec: durationSec,
      coverKey: coverKey,
      accentA: accentA,
      accentB: accentB,
      source: source,
      isFavorite: isFavorite ?? this.isFavorite,
      playedByAgent: playedByAgent ?? this.playedByAgent,
      metadata: metadata ?? this.metadata,
    );
  }
}

class MusicTrackPlayUrl {
  const MusicTrackPlayUrl({
    required this.trackId,
    required this.url,
    this.expiresAt,
  });

  final String trackId;
  final String url;
  final DateTime? expiresAt;

  factory MusicTrackPlayUrl.fromJson(Map<String, dynamic> json) {
    final expiresRaw = json['expires_at'] as String?;
    return MusicTrackPlayUrl(
      trackId: json['track_id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      expiresAt: expiresRaw == null || expiresRaw.isEmpty
          ? null
          : DateTime.tryParse(expiresRaw),
    );
  }
}

class MusicTracksResponse {
  const MusicTracksResponse({
    required this.tracks,
    required this.apiEnabled,
    this.library,
  });

  final List<MusicTrack> tracks;
  final bool apiEnabled;
  final String? library;

  factory MusicTracksResponse.fromJson(Map<String, dynamic> json) {
    final rawTracks = json['tracks'];
    return MusicTracksResponse(
      tracks: rawTracks is List
          ? rawTracks
                .whereType<Map>()
                .map(
                  (item) =>
                      MusicTrack.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
      apiEnabled: json['api_enabled'] as bool? ?? false,
      library: json['library'] as String?,
    );
  }
}

class MusicLibrary {
  const MusicLibrary({
    required this.id,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final String title;
  final String subtitle;

  factory MusicLibrary.fromJson(Map<String, dynamic> json) {
    return MusicLibrary(
      id: json['id'] as String? ?? 'focus',
      title: json['title'] as String? ?? '专注',
      subtitle: json['subtitle'] as String? ?? '',
    );
  }
}

class MusicLibrariesResponse {
  const MusicLibrariesResponse({
    required this.libraries,
    required this.defaultLibrary,
  });

  final List<MusicLibrary> libraries;
  final String defaultLibrary;

  factory MusicLibrariesResponse.fromJson(Map<String, dynamic> json) {
    final rawLibraries = json['libraries'];
    return MusicLibrariesResponse(
      libraries: rawLibraries is List
          ? rawLibraries
                .whereType<Map>()
                .map(
                  (item) =>
                      MusicLibrary.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
      defaultLibrary: json['default_library'] as String? ?? 'focus',
    );
  }
}

class MusicPlayback {
  const MusicPlayback({
    required this.track,
    required this.positionSeconds,
    required this.isPlaying,
    this.updatedAt,
  });

  final MusicTrack? track;
  final int positionSeconds;
  final bool isPlaying;
  final DateTime? updatedAt;

  factory MusicPlayback.fromJson(Map<String, dynamic> json) {
    final rawTrack = json['track'];
    return MusicPlayback(
      track: rawTrack is Map
          ? MusicTrack.fromJson(Map<String, dynamic>.from(rawTrack))
          : null,
      positionSeconds: (json['position_seconds'] as num?)?.round() ?? 0,
      isPlaying: json['is_playing'] as bool? ?? false,
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    );
  }
}

class MusicCoListening {
  const MusicCoListening({
    required this.status,
    required this.track,
    required this.positionSeconds,
    required this.isPlaying,
    this.initiatedBy,
    this.endedReason,
    this.updatedAt,
  });

  final String status;
  final MusicTrack? track;
  final int positionSeconds;
  final bool isPlaying;
  final String? initiatedBy;
  final String? endedReason;
  final DateTime? updatedAt;

  bool get isActive => status == 'active' && track != null;

  factory MusicCoListening.fromJson(Map<String, dynamic> json) {
    final rawTrack = json['track'];
    return MusicCoListening(
      status: json['status'] as String? ?? 'ended',
      track: rawTrack is Map
          ? MusicTrack.fromJson(Map<String, dynamic>.from(rawTrack))
          : null,
      positionSeconds: (json['position_seconds'] as num?)?.round() ?? 0,
      isPlaying: json['is_playing'] as bool? ?? false,
      initiatedBy: json['initiated_by'] as String?,
      endedReason: json['ended_reason'] as String?,
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    );
  }
}
