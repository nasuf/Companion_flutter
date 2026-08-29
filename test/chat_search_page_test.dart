import 'dart:async';

import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

const _session = AuthSession(
  token: 'test-token',
  userId: 'user-1',
  username: 'tester',
  role: UserRole.user,
  hasAgent: true,
  agentId: 'agent-1',
  agentName: '小芜',
  workspaceId: 'ws-1',
  conversationId: 'conv-1',
);

void _useDesignCanvas(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
}

MessageSearchResult _textResult(String label) {
  return MessageSearchResult(
    text: [
      MessageSearchHit(
        message: ChatMessage(
          id: label,
          conversationId: 'conv-1',
          role: 'user',
          content: label,
          createdAt: DateTime(2026, 8, 1),
        ),
        matchType: 'text',
        rank: 0,
      ),
    ],
    cards: const [],
    images: const [],
    hasMoreText: false,
    hasMoreCards: false,
    hasMoreImages: false,
  );
}

const _emptyResult = MessageSearchResult(
  text: [],
  cards: [],
  images: [],
  hasMoreText: false,
  hasMoreCards: false,
  hasMoreImages: false,
);

/// Records every `q` searched for and lets the test resolve each call's
/// response independently and in any order, to reproduce out-of-order
/// network responses.
class _FakeSearchApi extends CompanionApi {
  _FakeSearchApi() : super(baseUrl: 'https://example.test') {
    authToken = 'test-token';
  }

  final List<String> calls = [];
  final List<({String query, String scope, String? cardCategory})> fullCalls = [];
  final Map<String, Completer<MessageSearchResult>> _pending = {};

  Completer<MessageSearchResult> completerFor(String query) {
    return _pending.putIfAbsent(query, () => Completer<MessageSearchResult>());
  }

  @override
  Future<MessageSearchResult> searchMessages(
    String conversationId, {
    String? query,
    String scope = 'all',
    String? cardCategory,
    int limit = 30,
    int offset = 0,
  }) {
    final key = query ?? '';
    calls.add(key);
    fullCalls.add((query: key, scope: scope, cardCategory: cardCategory));
    return completerFor(key).future;
  }
}

Widget _harness(CompanionApi api) {
  return MaterialApp(
    home: ChatSearchPage(
      api: api,
      session: _session,
      conversationId: 'conv-1',
      onOpenComponentCard: (_) async {},
      onPreviewAttachment: (_) async {},
    ),
  );
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets(
    'a slower response for an earlier query does not clobber a newer one',
    (tester) async {
      _useDesignCanvas(tester);
      final api = _FakeSearchApi();
      await tester.pumpWidget(_harness(api));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'A');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.enterText(find.byType(TextField), 'B');
      await tester.pump(const Duration(milliseconds: 350));

      expect(api.calls, ['A', 'B']);

      // Resolve out of order: the newer query's response lands first, the
      // stale/earlier one arrives after — it must be discarded, not shown.
      api.completerFor('B').complete(_textResult('b-hit'));
      await tester.pump();
      api.completerFor('A').complete(_textResult('a-hit'));
      await tester.pump();

      expect(find.text('b-hit'), findsOneWidget);
      expect(find.text('a-hit'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('clearing the query back to empty does not re-hit the API', (
    tester,
  ) async {
    _useDesignCanvas(tester);
    final api = _FakeSearchApi();
    await tester.pumpWidget(_harness(api));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'A');
    await tester.pump(const Duration(milliseconds: 350));
    expect(api.calls, ['A']);
    api.completerFor('A').complete(_emptyResult);
    await tester.pump();

    await tester.enterText(find.byType(TextField), '');
    await tester.pump(const Duration(milliseconds: 350));

    expect(api.calls, ['A']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'tapping a card-category quick filter searches that category, not the generic "卡片" scope',
    (tester) async {
      _useDesignCanvas(tester);
      final api = _FakeSearchApi();
      await tester.pumpWidget(_harness(api));
      await tester.pump();

      await tester.tap(find.text('音乐'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(api.fullCalls, hasLength(1));
      expect(api.fullCalls.single.scope, 'card');
      expect(api.fullCalls.single.cardCategory, 'music');
      expect(find.text('音乐'), findsOneWidget); // now the pushed page's _ScopeHeader
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the 图片 quick filter does not send a card_category', (
    tester,
  ) async {
    _useDesignCanvas(tester);
    final api = _FakeSearchApi();
    await tester.pumpWidget(_harness(api));
    await tester.pump();

    await tester.tap(find.text('图片'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(api.fullCalls, hasLength(1));
    expect(api.fullCalls.single.scope, 'image');
    expect(api.fullCalls.single.cardCategory, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('取消 clears the field immediately without a debounce wait', (
    tester,
  ) async {
    _useDesignCanvas(tester);
    final api = _FakeSearchApi();
    await tester.pumpWidget(_harness(api));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'A');
    await tester.pump(const Duration(milliseconds: 350));
    expect(api.calls, ['A']);
    api.completerFor('A').complete(_emptyResult);
    await tester.pump();

    await tester.tap(find.text('取消'));
    await tester.pump(); // no 300ms debounce needed for the explicit cancel

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller!.text, isEmpty);
    expect(find.text('音乐'), findsOneWidget); // back to the landing page's quick filters
    expect(api.calls, ['A']); // no extra request fired by cancelling
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mid-pinyin composition does not search; committing it searches exactly once',
    (tester) async {
      _useDesignCanvas(tester);
      final api = _FakeSearchApi();
      await tester.pumpWidget(_harness(api));
      await tester.pump();

      final controller = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;

      // Each candidate keystroke while composing "ce shi" (pinyin for 测试,
      // not yet committed) — an IME marks this with a non-collapsed
      // `composing` range, same as a real keyboard would.
      for (final candidate in ['c', 'ce', 'ce ', 'ce s', 'ce sh', 'ce shi']) {
        controller.value = TextEditingValue(
          text: candidate,
          selection: TextSelection.collapsed(offset: candidate.length),
          composing: TextRange(start: 0, end: candidate.length),
        );
        await tester.pump(const Duration(milliseconds: 350));
      }
      expect(api.calls, isEmpty);

      // The user picks "测试" from the candidate list — composing collapses.
      controller.value = const TextEditingValue(
        text: '测试',
        selection: TextSelection.collapsed(offset: 2),
      );
      await tester.pump(const Duration(milliseconds: 350));

      expect(api.calls, ['测试']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a single-scope list spanning two months renders a sticky header per month',
    (tester) async {
      _useDesignCanvas(tester);
      final api = _FakeSearchApi();
      final result = MessageSearchResult(
        text: [
          MessageSearchHit(
            message: ChatMessage(
              id: 'newer',
              conversationId: 'conv-1',
              role: 'user',
              content: 'newer',
              createdAt: DateTime(2026, 8, 20),
            ),
            matchType: 'text',
            rank: 0,
          ),
          MessageSearchHit(
            message: ChatMessage(
              id: 'older',
              conversationId: 'conv-1',
              role: 'user',
              content: 'older',
              createdAt: DateTime(2023, 4, 8),
            ),
            matchType: 'text',
            rank: 1,
          ),
        ],
        cards: const [],
        images: const [],
        hasMoreText: false,
        hasMoreCards: false,
        hasMoreImages: false,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ChatSearchPage(
            api: api,
            session: _session,
            conversationId: 'conv-1',
            initialScope: ChatSearchScope.text,
            onOpenComponentCard: (_) async {},
            onPreviewAttachment: (_) async {},
          ),
        ),
      );
      await tester.pump();
      api.completerFor('').complete(result);
      await tester.pump();

      expect(find.text('2026-8'), findsOneWidget);
      expect(find.text('2023-4'), findsOneWidget);
      expect(find.text('newer'), findsOneWidget);
      expect(find.text('older'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
