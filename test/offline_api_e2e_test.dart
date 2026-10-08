// Run through tests/test_offline_quality_e2e.py with an isolated local server.
import 'dart:io';
import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/src/services/device_location.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'offline_journey_flow_test.dart' as flow;

class _RealHttp extends HttpOverrides {}

void main() {
  final base = Platform.environment['OFFLINE_E2E_API'];
  testWidgets(
    'arrival UI -> location rejection -> cancel/confirm -> real HTTP/DB -> archive',
    (tester) async {
      await HttpOverrides.runZoned(() async {
        final api = CompanionApi(baseUrl: base!)
          ..authToken = Platform.environment['OFFLINE_E2E_TOKEN'];
        final id = Platform.environment['OFFLINE_E2E_CONFIRM']!;
        final initial = await tester.runAsync(
          () => api.fetchOfflineActivity(id),
        );
        expect(initial!.arrivalVerificationAvailable, isTrue);
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var navigated = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: OfflineCheckinPage(
              api: api,
              session: flow.session,
              activityId: id,
              initialActivity: initial,
              onNavigateToChat: () => navigated++,
              locationLoader: () async => const DeviceLocationSnapshot(
                latitude: 24,
                longitude: 113.75,
                permissionStatus: 'granted',
                accuracyMeters: 10,
              ),
            ),
          ),
        );
        Future<void> waitFor(Finder finder) async {
          for (var i = 0; i < 100; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await tester.pump();
            if (finder.evaluate().isNotEmpty) {
              await tester.pumpAndSettle();
              return;
            }
          }
          fail('Expected UI was not shown: $finder');
        }

        await tester.tap(find.text('我已经抵达这里'));
        await waitFor(find.text('我已确认到达'));
        expect(find.textContaining('定位显示你好像还没到附近'), findsOneWidget);
        await tester.tap(find.text('再等等'));
        await tester.pumpAndSettle();
        expect(
          (await tester.runAsync(() => api.fetchOfflineActivity(id)))!.reached,
          isFalse,
        );
        expect(navigated, 0);
        await tester.tap(find.text('我已经抵达这里'));
        await waitFor(find.text('我已确认到达'));
        await tester.tap(find.text('我已确认到达'));
        await waitFor(find.text('已确认到达'));
        expect(navigated, 1);
        final arrived = await tester.runAsync(
          () => api.fetchOfflineActivity(id),
        );
        expect(arrived!.reached, isTrue);
        expect(arrived.arrivalVerified, isFalse);
        await tester.runAsync(() => api.archiveOfflineActivity(id));
        final review = await tester.runAsync(
          () => api.fetchOfflineActivityReview(id),
        );
        expect(review!.canGenerateMemoryNote, isFalse);
        expect(review.story, contains('还没有留下'));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }, createHttpClient: _RealHttp().createHttpClient);
    },
    skip: base == null,
  );
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
