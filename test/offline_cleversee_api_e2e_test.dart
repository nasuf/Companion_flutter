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
        expect(activity.description.length, greaterThanOrEqualTo(120));
        expect(activity.recommendationMessage, isNotNull);
        expect(
          activity.recommendationMessage!.length,
          greaterThanOrEqualTo(100),
        );
        expect(
          activity.copyWith(imageUrls: []).recommendationMessage,
          activity.recommendationMessage,
        );
        expect(
          activity.description.split('\n\n').length,
          greaterThanOrEqualTo(3),
        );
        expect(activity.summary, isNot('可以去${activity.locationName}看看'));
        expect(activity.arrivalVerificationAvailable, isTrue);
        expect(activity.placeLat, isNotNull);
        expect(activity.placeLng, isNotNull);
        expect(activity.coordinateSystem, 'gcj02');
        final detail = await api.fetchOfflineActivity(activity.id);
        expect(detail.title, activity.title);
        expect(detail.imageUrls, activity.imageUrls);
        expect(detail.description, activity.description);
        expect(detail.summary, activity.summary);
        expect(detail.recommendationMessage, activity.recommendationMessage);
        expect(detail.placeLat, activity.placeLat);
        for (final imageUrl in activity.imageUrls) {
          final client = HttpClient();
          try {
            final request = await client.getUrl(
              Uri.parse(base).resolve(imageUrl),
            );
            request.headers.set('Authorization', 'Bearer ${api.authToken}');
            final response = await request.close();
            expect(response.statusCode, 200);
            expect(response.headers.contentType?.mimeType, 'image/jpeg');
            final bytes = await response.fold<List<int>>(
              <int>[],
              (all, chunk) => all..addAll(chunk),
            );
            expect(bytes.take(3), <int>[0xff, 0xd8, 0xff]);
          } finally {
            client.close(force: true);
          }
        }
        final accepted = await api.acceptOfflineActivity(activity.id);
        expect(accepted.recommendationMessage, activity.recommendationMessage);
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
        expect(arrived.recommendationMessage, activity.recommendationMessage);
        final archived = await api.archiveOfflineActivity(activity.id);
        expect(archived.status, 'completed');
        expect(archived.recommendationMessage, activity.recommendationMessage);
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
