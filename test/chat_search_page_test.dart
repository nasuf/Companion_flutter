import 'dart:async';

import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:flutter/cupertino.dart';
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

/// Simulates a person typing [text] then tapping the keyboard's own search
/// action button — the *only* thing that should ever start a search from
/// typed text (see chat_search_page.dart's `_onSubmitted` doc comment).
Future<void> _submitSearch(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pump();
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('typing alone never fires a search — only pressing the keyboard search key does', (
    tester,
  ) async {
    _useDesignCanvas(tester);
    final api = _FakeSearchApi();
    await tester.pumpWidget(_harness(api));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'a');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), 'ab');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump(const Duration(milliseconds: 400));

    expect(api.calls, isEmpty);

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    expect(api.calls, ['abc']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a slower response for an earlier query does not clobber a newer one',
    (tester) async {
      _useDesignCanvas(tester);
      final api = _FakeSearchApi();
      await tester.pumpWidget(_harness(api));
      await tester.pump();

      await _submitSearch(tester, 'A');
      await _submitSearch(tester, 'B');

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

  testWidgets('取消 clears the field and returns to the landing page', (
    tester,
  ) async {
    _useDesignCanvas(tester);
    final api = _FakeSearchApi();
    await tester.pumpWidget(_harness(api));
    await tester.pump();

    await _submitSearch(tester, 'A');
    expect(api.calls, ['A']);
    api.completerFor('A').complete(_emptyResult);
    await tester.pump();

    await tester.tap(find.text('取消'));
    await tester.pump();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller!.text, isEmpty);
    expect(find.text('音乐'), findsOneWidget); // back to the landing page's quick filters
    expect(api.calls, ['A']); // no extra request fired by cancelling
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'neither mid-pinyin composing nor committing a candidate searches — only the keyboard search key does',
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
      // Committing a candidate is still not the same as pressing "search".
      controller.value = const TextEditingValue(
        text: '测试',
        selection: TextSelection.collapsed(offset: 2),
      );
      await tester.pump(const Duration(milliseconds: 350));
      expect(api.calls, isEmpty);

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

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

  testWidgets('clearing recent search history asks for confirmation first', (
    tester,
  ) async {
    _useDesignCanvas(tester);
    final api = _FakeSearchApi();
    await tester.pumpWidget(_harness(api));
    await tester.pump();

    await _submitSearch(tester, '测试');
    api.completerFor('测试').complete(_emptyResult);
    await tester.pump();
    await tester.tap(find.text('取消')); // back to landing; "测试" now in history
    await tester.pump();
    expect(find.text('测试'), findsOneWidget);

    await tester.tap(find.byIcon(CupertinoIcons.delete));
    await tester.pumpAndSettle();
    expect(find.text('清空最近搜索'), findsOneWidget);

    // Dismissing the dialog without confirming leaves history untouched.
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('测试'), findsOneWidget);

    await tester.tap(find.byIcon(CupertinoIcons.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清空'));
    await tester.pumpAndSettle();

    expect(find.text('测试'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping blank space in the body dismisses the keyboard', (
    tester,
  ) async {
    _useDesignCanvas(tester);
    final api = _FakeSearchApi();
    await tester.pumpWidget(_harness(api));
    await tester.pump();

    final focusNode = tester
        .widget<TextField>(find.byType(TextField))
        .focusNode!;
    expect(focusNode.hasFocus, isTrue); // autofocused on the landing page

    await tester.tap(find.text('按类型查找')); // plain label, no onTap of its own
    await tester.pump();

    expect(focusNode.hasFocus, isFalse);
    expect(tester.takeException(), isNull);
  });
}
