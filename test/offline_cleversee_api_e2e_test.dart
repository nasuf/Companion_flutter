// Run by the backend's isolated CleverSee E2E fixture.
import 'dart:io';

import 'package:companion_flutter/companion_api.dart';
import 'package:flutter_test/flutter_test.dart';

class _RealHttp extends HttpOverrides {}

void main() {
  final base = Platform.environment['OFFLINE_E2E_API'];
  test(
    'CleverSee recommendation -> Flutter HTTP -> GPS -> archive with full gallery',
    () async {
      expect(Uri.parse(base!).host, '127.0.0.1');
      await HttpOverrides.runZoned(() async {
        final api = CompanionApi(baseUrl: base)
          ..authToken = Platform.environment['OFFLINE_E2E_TOKEN'];
        final activity = (await api.createOfflineActivityRecommendation(
          workspaceId: Platform.environment['OFFLINE_E2E_WORKSPACE'],
        ))!;
        expect(activity.title, Platform.environment['OFFLINE_E2E_PLACE']);
        expect(activity.kind, 'place');
        expect(activity.imageUrls, hasLength(3));
        expect(activity.arrivalVerificationAvailable, isTrue);
        expect(activity.placeLat, isNotNull);
        expect(activity.placeLng, isNotNull);
        expect(activity.coordinateSystem, 'gcj02');
        final detail = await api.fetchOfflineActivity(activity.id);
        expect(detail.title, activity.title);
        expect(detail.imageUrls, activity.imageUrls);
        expect(detail.placeLat, activity.placeLat);
        await api.acceptOfflineActivity(activity.id);
        await expectLater(
          api.arriveOfflineActivity(
            activity.id,
            lat: 31.2,
            lng: 119.43,
            accuracyMeters: 10,
            observedAt: DateTime.now(),
          ),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 422),
          ),
        );
        await expectLater(
          api.arriveOfflineActivity(
            activity.id,
            lat: 32.21,
            lng: 119.43,
            accuracyMeters: 10,
            observedAt: DateTime.now().subtract(const Duration(minutes: 5)),
          ),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 422),
          ),
        );
        final arrived = await api.arriveOfflineActivity(
          activity.id,
          lat: 32.21,
          lng: 119.43,
          accuracyMeters: 10,
          observedAt: DateTime.now(),
        );
        expect(arrived.arrivalVerified, isTrue);
        final archived = await api.archiveOfflineActivity(activity.id);
        expect(archived.status, 'completed');
        final review = await api.fetchOfflineActivityReview(activity.id);
        expect(review.imageUrls, activity.imageUrls);
        expect(review.gallery, isEmpty);
        expect(review.canGenerateMemoryNote, isFalse);
      }, createHttpClient: _RealHttp().createHttpClient);
    },
    skip: base == null
        ? 'Requires isolated CleverSee backend E2E runner'
        : false,
  );
}
