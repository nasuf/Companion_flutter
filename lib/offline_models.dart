import 'models.dart';

class OfflineHome {
  const OfflineHome({
    required this.pendingActivityCount,
    required this.acceptedActivityCount,
    required this.completedActivityCount,
    required this.giftCount,
    required this.shippingGiftCount,
    required this.hasLocation,
    required this.tags,
    this.latestActivity,
    required this.giftSummary,
  });

  final int pendingActivityCount;
  final int acceptedActivityCount;
  final int completedActivityCount;
  final int giftCount;
  final int shippingGiftCount;
  final bool hasLocation;
  final List<String> tags;
  final OfflineActivity? latestActivity;
  final String giftSummary;

  factory OfflineHome.fromJson(Map<String, dynamic> json) => OfflineHome(
    pendingActivityCount: _asInt(json['pending_activity_count']),
    acceptedActivityCount: _asInt(json['accepted_activity_count']),
    completedActivityCount: _asInt(json['completed_activity_count']),
    giftCount: _asInt(json['gift_count']),
    shippingGiftCount: _asInt(json['shipping_gift_count']),
    hasLocation: json['has_location'] == true,
    tags: _stringList(json['tags']),
    latestActivity: json['latest_activity'] is Map
        ? OfflineActivity.fromJson(
            Map<String, dynamic>.from(json['latest_activity'] as Map),
          )
        : null,
    giftSummary: json['gift_summary']?.toString() ?? '你有一份惊喜在路上',
  );
}

class OfflineActivities {
  const OfflineActivities({
    this.latest,
    required this.pending,
    required this.ignored,
    required this.completed,
  });

  final OfflineActivity? latest;
  final List<OfflineActivity> pending;
  final List<OfflineActivity> ignored;
  final List<OfflineActivity> completed;

  factory OfflineActivities.fromJson(Map<String, dynamic> json) =>
      OfflineActivities(
        latest: json['latest'] is Map
            ? OfflineActivity.fromJson(
                Map<String, dynamic>.from(json['latest'] as Map),
              )
            : null,
        pending: _activityList(json['pending']),
        ignored: _activityList(json['ignored']),
        completed: _activityList(json['completed']),
      );
}

class AdminActivityClearResult {
  const AdminActivityClearResult({
    required this.deletedActivities,
    required this.deletedFeedback,
  });

  final int deletedActivities;
  final int deletedFeedback;

  factory AdminActivityClearResult.fromJson(Map<String, dynamic> json) =>
      AdminActivityClearResult(
        deletedActivities: _asInt(json['deleted_activities']),
        deletedFeedback: _asInt(json['deleted_feedback']),
      );
}

class OfflineActivity {
  const OfflineActivity({
    required this.id,
    required this.status,
    required this.title,
    required this.summary,
    required this.description,
    this.category,
    this.city,
    this.locationName,
    this.address,
    this.startsAt,
    this.endsAt,
    this.officialUrl,
    required this.imageUrls,
    this.taskHint,
    this.easterEggTask,
    required this.searchSources,
    this.acceptedAt,
    this.ignoredAt,
    this.completedAt,
    this.expiresAt,
    this.completionFeedback,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String status;
  final String title;
  final String summary;
  final String description;
  final String? category;
  final String? city;
  final String? locationName;
  final String? address;
  final String? startsAt;
  final String? endsAt;
  final String? officialUrl;
  final List<String> imageUrls;
  final String? taskHint;
  final Map<String, dynamic>? easterEggTask;
  final List<Map<String, dynamic>> searchSources;
  final String? acceptedAt;
  final String? ignoredAt;
  final String? completedAt;
  final String? expiresAt;
  final OfflineActivityCompletionFeedback? completionFeedback;
  final String createdAt;
  final String updatedAt;

  factory OfflineActivity.fromJson(Map<String, dynamic> json) =>
      OfflineActivity(
        id: json['id']?.toString() ?? '',
        status: json['status']?.toString() ?? 'pending',
        title: json['title']?.toString() ?? '',
        summary: json['summary']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        category: _asString(json['category']),
        city: _asString(json['city']),
        locationName: _asString(json['location_name']),
        address: _asString(json['address']),
        startsAt: _asString(json['starts_at']),
        endsAt: _asString(json['ends_at']),
        officialUrl: _asString(json['official_url']),
        imageUrls: _stringList(json['image_urls']),
        taskHint: _asString(json['task_hint']),
        easterEggTask: json['easter_egg_task'] is Map
            ? Map<String, dynamic>.from(json['easter_egg_task'] as Map)
            : null,
        searchSources: _mapList(json['search_sources']),
        acceptedAt: _asString(json['accepted_at']),
        ignoredAt: _asString(json['ignored_at']),
        completedAt: _asString(json['completed_at']),
        expiresAt: _asString(json['expires_at']),
        completionFeedback: json['completion_feedback'] is Map
            ? OfflineActivityCompletionFeedback.fromJson(
                Map<String, dynamic>.from(json['completion_feedback'] as Map),
              )
            : null,
        createdAt: json['created_at']?.toString() ?? '',
        updatedAt: json['updated_at']?.toString() ?? '',
      );

  OfflineActivity copyWith({
    List<String>? imageUrls,
    OfflineActivityCompletionFeedback? completionFeedback,
  }) {
    return OfflineActivity(
      id: id,
      status: status,
      title: title,
      summary: summary,
      description: description,
      category: category,
      city: city,
      locationName: locationName,
      address: address,
      startsAt: startsAt,
      endsAt: endsAt,
      officialUrl: officialUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      taskHint: taskHint,
      easterEggTask: easterEggTask,
      searchSources: searchSources,
      acceptedAt: acceptedAt,
      ignoredAt: ignoredAt,
      completedAt: completedAt,
      expiresAt: expiresAt,
      completionFeedback: completionFeedback ?? this.completionFeedback,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class OfflineActivityCompletionFeedback {
  const OfflineActivityCompletionFeedback({
    required this.text,
    required this.photoAttachments,
    this.audioAttachment,
    this.createdAt,
  });

  final String text;
  final List<ChatAttachment> photoAttachments;
  final ChatAttachment? audioAttachment;
  final DateTime? createdAt;

  factory OfflineActivityCompletionFeedback.fromJson(
    Map<String, dynamic> json,
  ) {
    return OfflineActivityCompletionFeedback(
      text: json['text']?.toString() ?? '',
      photoAttachments: [
        for (final item in (json['photo_attachments'] as List? ?? const []))
          if (item is Map)
            ChatAttachment.fromJson(Map<String, dynamic>.from(item)),
      ],
      audioAttachment: json['audio_attachment'] is Map
          ? ChatAttachment.fromJson(
              Map<String, dynamic>.from(json['audio_attachment'] as Map),
            )
          : null,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  OfflineActivityCompletionFeedback copyWith({
    List<ChatAttachment>? photoAttachments,
    ChatAttachment? audioAttachment,
  }) {
    return OfflineActivityCompletionFeedback(
      text: text,
      photoAttachments: photoAttachments ?? this.photoAttachments,
      audioAttachment: audioAttachment ?? this.audioAttachment,
      createdAt: createdAt,
    );
  }
}

class GiftAddress {
  const GiftAddress({
    this.id,
    this.recipientName,
    this.phone,
    this.province,
    this.city,
    this.district,
    this.detail,
    this.display,
  });

  final String? id;
  final String? recipientName;
  final String? phone;
  final String? province;
  final String? city;
  final String? district;
  final String? detail;
  final String? display;

  bool get hasAddress => (id ?? '').isNotEmpty || (display ?? '').isNotEmpty;

  factory GiftAddress.fromJson(Map<String, dynamic> json) => GiftAddress(
    id: _asString(json['id']),
    recipientName: _asString(json['recipient_name']),
    phone: _asString(json['phone']),
    province: _asString(json['province']),
    city: _asString(json['city']),
    district: _asString(json['district']),
    detail: _asString(json['detail']),
    display: _asString(json['display']),
  );
}

class GiftsHome {
  const GiftsHome({this.address, this.shippingGift, required this.groups});

  final GiftAddress? address;
  final RealWorldGift? shippingGift;
  final List<GiftYearGroup> groups;

  factory GiftsHome.fromJson(Map<String, dynamic> json) => GiftsHome(
    address: json['address'] is Map
        ? GiftAddress.fromJson(
            Map<String, dynamic>.from(json['address'] as Map),
          )
        : null,
    shippingGift: json['shipping_gift'] is Map
        ? RealWorldGift.fromJson(
            Map<String, dynamic>.from(json['shipping_gift'] as Map),
          )
        : null,
    groups: [
      for (final item in (json['groups'] as List? ?? const []))
        if (item is Map)
          GiftYearGroup.fromJson(Map<String, dynamic>.from(item)),
    ],
  );
}

class GiftYearGroup {
  const GiftYearGroup({required this.year, required this.gifts});

  final int year;
  final List<RealWorldGift> gifts;

  factory GiftYearGroup.fromJson(Map<String, dynamic> json) => GiftYearGroup(
    year: _asInt(json['year']),
    gifts: [
      for (final item in (json['gifts'] as List? ?? const []))
        if (item is Map)
          RealWorldGift.fromJson(Map<String, dynamic>.from(item)),
    ],
  );
}

class RealWorldGift {
  const RealWorldGift({
    required this.id,
    required this.status,
    required this.triggerType,
    required this.giftName,
    this.giftReason,
    this.giftNote,
    this.productImageUrl,
    this.provider = 'mock',
    this.providerProductId,
    this.providerOrderId,
    this.productUrl,
    this.logisticsProvider,
    this.lastTrackingSyncedAt,
    required this.paidAmountCents,
    this.trackingNumber,
    this.thanksSentAt,
    this.orderedAt,
    this.shippedAt,
    this.deliveredAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String status;
  final String triggerType;
  final String giftName;
  final String? giftReason;
  final String? giftNote;
  final String? productImageUrl;
  final String provider;
  final String? providerProductId;
  final String? providerOrderId;
  final String? productUrl;
  final String? logisticsProvider;
  final String? lastTrackingSyncedAt;
  final int paidAmountCents;
  final String? trackingNumber;
  final String? thanksSentAt;
  final String? orderedAt;
  final String? shippedAt;
  final String? deliveredAt;
  final String createdAt;
  final String updatedAt;

  factory RealWorldGift.fromJson(Map<String, dynamic> json) => RealWorldGift(
    id: json['id']?.toString() ?? '',
    status: json['status']?.toString() ?? 'pending_address',
    triggerType: json['trigger_type']?.toString() ?? 'daily_probability',
    giftName: json['gift_name']?.toString() ?? '',
    giftReason: _asString(json['gift_reason']),
    giftNote: _asString(json['gift_note']),
    productImageUrl: _asString(json['product_image_url']),
    provider: json['provider']?.toString() ?? 'mock',
    providerProductId: _asString(json['provider_product_id']),
    providerOrderId: _asString(json['provider_order_id']),
    productUrl: _asString(json['product_url']),
    logisticsProvider: _asString(json['logistics_provider']),
    lastTrackingSyncedAt: _asString(json['last_tracking_synced_at']),
    paidAmountCents: _asInt(json['paid_amount_cents']),
    trackingNumber: _asString(json['tracking_number']),
    thanksSentAt: _asString(json['thanks_sent_at']),
    orderedAt: _asString(json['ordered_at']),
    shippedAt: _asString(json['shipped_at']),
    deliveredAt: _asString(json['delivered_at']),
    createdAt: json['created_at']?.toString() ?? '',
    updatedAt: json['updated_at']?.toString() ?? '',
  );
}

class GiftTracking {
  const GiftTracking({required this.giftId, required this.events});

  final String giftId;
  final List<GiftTrackingEvent> events;

  factory GiftTracking.fromJson(Map<String, dynamic> json) => GiftTracking(
    giftId: json['gift_id']?.toString() ?? '',
    events: [
      for (final item in (json['events'] as List? ?? const []))
        if (item is Map)
          GiftTrackingEvent.fromJson(Map<String, dynamic>.from(item)),
    ],
  );
}

class GiftTrackingEvent {
  const GiftTrackingEvent({
    required this.id,
    required this.status,
    required this.title,
    this.description,
    this.location,
    required this.occurredAt,
  });

  final String id;
  final String status;
  final String title;
  final String? description;
  final String? location;
  final String occurredAt;

  factory GiftTrackingEvent.fromJson(Map<String, dynamic> json) =>
      GiftTrackingEvent(
        id: json['id']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        description: _asString(json['description']),
        location: _asString(json['location']),
        occurredAt: json['occurred_at']?.toString() ?? '',
      );
}

List<OfflineActivity> _activityList(dynamic raw) => [
  for (final item in (raw as List? ?? const []))
    if (item is Map) OfflineActivity.fromJson(Map<String, dynamic>.from(item)),
];

List<Map<String, dynamic>> _mapList(dynamic raw) => [
  for (final item in (raw as List? ?? const []))
    if (item is Map) Map<String, dynamic>.from(item),
];

List<String> _stringList(dynamic raw) => [
  for (final item in (raw as List? ?? const []))
    if (item != null) item.toString(),
];

String? _asString(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
