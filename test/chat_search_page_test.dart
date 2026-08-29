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
  final Map<String, Completer<MessageSearchResult>> _pending = {};

  Completer<MessageSearchResult> completerFor(String query) {
    return _pending.putIfAbsent(query, () => Completer<MessageSearchResult>());
  }

  @override
  Future<MessageSearchResult> searchMessages(
    String conversationId, {
    String? query,
    String scope = 'all',
    int limit = 30,
    int offset = 0,
  }) {
    final key = query ?? '';
    calls.add(key);
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
}
