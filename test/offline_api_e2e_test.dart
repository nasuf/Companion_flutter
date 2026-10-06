// Run through tests/test_offline_quality_e2e.py with an isolated local server.
import 'dart:io';
import 'package:companion_flutter/companion_api.dart';
import 'package:flutter_test/flutter_test.dart';

class _RealHttp extends HttpOverrides {}

void main() {
  final base = Platform.environment['OFFLINE_E2E_API'];
  test(
    'Flutter API -> authenticated HTTP -> PostgreSQL arrival/archive/delete',
    () async {
      final uri = Uri.parse(base!);
      expect(uri.host, '127.0.0.1');
      await HttpOverrides.runZoned(() async {
        final api = CompanionApi(baseUrl: base)
          ..authToken = Platform.environment['OFFLINE_E2E_TOKEN'];
        await expectLater(
          api.createOfflineActivityRecommendation(),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'status', 503)
                .having((e) => e.message, 'message', '暂时没找到合适的新去处，请稍后再试。'),
          ),
        );
        final id = Platform.environment['OFFLINE_E2E_ACTIVITY']!;
        final toDelete = Platform.environment['OFFLINE_E2E_DELETE']!;
        final activity = await api.fetchOfflineActivity(id);
        expect(activity.title, '莲湖公园走走');
        final expectedImages = [
          for (var i = 0; i < 3; i++)
            '$base/offline/media/place_fixture_$i.jpg',
        ];
        expect(activity.imageUrls, expectedImages);
        expect(activity.arrivalVerificationAvailable, isFalse);
        await expectLater(
          api.arriveOfflineActivity(id),
          throwsA(isA<ApiException>()),
        );
        final arrived = await api.arriveOfflineActivity(
          id,
          manualConfirmation: true,
        );
        expect(arrived.reached, isTrue);
        expect(arrived.arrivalVerified, isFalse);
        final archived = await api.archiveOfflineActivity(id);
        expect(archived.status, 'completed');
        final review = await api.fetchOfflineActivityReview(id);
        expect(archived.imageUrls, expectedImages);
        expect(review.imageUrls, expectedImages);
        expect(review.coverUrl, expectedImages.first);
        expect(review.gallery, isEmpty);
        expect(
          (await api.fetchOfflineActivityReview(id)).imageUrls,
          expectedImages,
        );
        expect(review.canGenerateMemoryNote, isFalse);
        expect(review.story, contains('还没有留下'));
        await expectLater(
          api.generateOfflineMemoryNote(id),
          throwsA(isA<ApiException>()),
        );
        await api.deleteOfflineActivity(toDelete);
        final listing = await api.fetchOfflineActivities();
        expect(listing.pending.any((a) => a.id == toDelete), isFalse);
      }, createHttpClient: _RealHttp().createHttpClient);
    },
    skip: base == null ? 'Requires isolated backend E2E runner' : false,
  );
}
