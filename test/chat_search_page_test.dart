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

MessageSearchResult _textResult(String label, {bool hasMore = false}) {
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
    hasMoreText: hasMore,
    hasMoreCards: false,
    hasMoreImages: false,
  );
}

MessageSearchResult _cardResult(String id) {
  return MessageSearchResult(
    text: const [],
    cards: [
      MessageSearchHit(
        message: ChatMessage(
          id: id,
          conversationId: 'conv-1',
          // Not "user": the header then shows agentName ("小芜") rather than
          // "我", which would otherwise collide with the avatar's own "我"
          // fallback-initials text and make `find.text('我')` ambiguous.
          role: 'assistant',
          content: '',
          createdAt: DateTime(2026, 8, 1),
          metadata: const {
            'component_card': {
              'type': 'gift',
              'title': '美式咖啡',
              'subtitle': '待接收',
              'body': '饮品',
              'footer': '点击查看',
              'accent': '#FF8A3D',
              'payload': <String, dynamic>{},
            },
          },
        ),
        matchType: 'card',
        rank: 0,
      ),
    ],
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

Widget _harness(
  CompanionApi api, {
  Future<void> Function(MessageSearchHit hit)? onLocateMessage,
  Future<void> Function(ChatComponentCard card)? onOpenComponentCard,
}) {
  return MaterialApp(
    home: ChatSearchPage(
      api: api,
      session: _session,
      conversationId: 'conv-1',
      onOpenComponentCard: onOpenComponentCard ?? (_) async {},
      onPreviewAttachment: (_) async {},
      onLocateMessage: onLocateMessage ?? (_) async {},
    ),
  );
}

/// A harness with an actual page underneath — for asserting that locating a
/// message pops [ChatSearchPage] back to whatever pushed it (the live chat
/// page, in the real app), not just that the callback fired.
Widget _pushHarness(
  CompanionApi api, {
  required Future<void> Function(MessageSearchHit hit) onLocateMessage,
  Future<void> Function(ChatComponentCard card)? onOpenComponentCard,
}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => CupertinoButton(
        onPressed: () => ChatSearchPage.push(
          context,
          api: api,
          session: _session,
          conversationId: 'conv-1',
          onOpenComponentCard: onOpenComponentCard ?? (_) async {},
          onPreviewAttachment: (_) async {},
          onLocateMessage: onLocateMessage,
        ),
        child: const Text('open search'),
      ),
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
      expect(find.text('音乐'), findsOneWidget); // now this same page's _ScopeHeader
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
            onLocateMessage: (_) async {},
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

  testWidgets('tapping a recent search entry dismisses the keyboard', (
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

    final focusNode = tester
        .widget<TextField>(find.byType(TextField))
        .focusNode!;
    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.tap(find.text('测试'));
    await tester.pump();

    expect(focusNode.hasFocus, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'submitting a new keyword while browsing a single category returns to an all-scope search',
    (tester) async {
      _useDesignCanvas(tester);
      final api = _FakeSearchApi();
      await tester.pumpWidget(_harness(api));
      await tester.pump();

      // Open the 音乐/card category view — same as tapping its "查看全部".
      await tester.tap(find.text('音乐'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(api.fullCalls.single.scope, 'card');
      api.completerFor('').complete(_emptyResult);
      await tester.pump();

      // A brand new keyword typed at the top bar must search everything —
      // not stay confined to the 音乐/card category the user happened to
      // still be looking at.
      await _submitSearch(tester, '新关键词');

      expect(api.fullCalls.last.query, '新关键词');
      expect(api.fullCalls.last.scope, 'all');
      expect(api.fullCalls.last.cardCategory, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the back arrow returns to the search home page from a still-open category view',
    (tester) async {
      _useDesignCanvas(tester);
      final api = _FakeSearchApi();
      await tester.pumpWidget(_harness(api));
      await tester.pump();

      // Search "A", then drill into its 聊天记录 (text) "查看全部" — only the
      // text section has a hit, so its "查看全部" is the sole match.
      await _submitSearch(tester, 'A');
      api.completerFor('A').complete(_textResult('a-hit', hasMore: true));
      await tester.pump();
      await tester.tap(find.text('查看全部'));
      // Same query "A" → the fake API's completer for it is already
      // resolved from the first search, so no second .complete() call.
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('按类型查找'), findsNothing); // still in the category view

      await tester.tap(find.byIcon(CupertinoIcons.chevron_left));
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, isEmpty);
      expect(find.text('按类型查找'), findsOneWidget); // landing page's own label
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a new search clears the previous results immediately, before the response arrives',
    (tester) async {
      _useDesignCanvas(tester);
      final api = _FakeSearchApi();
      await tester.pumpWidget(_harness(api));
      await tester.pump();

      await _submitSearch(tester, 'A');
      api.completerFor('A').complete(_textResult('a-hit'));
      await tester.pump();
      expect(find.text('a-hit'), findsOneWidget);

      await _submitSearch(tester, 'B');
      await tester.pump(); // one frame — B's response has not arrived yet

      expect(find.text('a-hit'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tapping a text result pops back to the live chat and hands off the hit',
    (tester) async {
      _useDesignCanvas(tester);
      final api = _FakeSearchApi();
      final located = <MessageSearchHit>[];
      await tester.pumpWidget(
        _pushHarness(api, onLocateMessage: (hit) async => located.add(hit)),
      );
      await tester.pump();

      await tester.tap(find.text('open search'));
      await tester.pumpAndSettle();

      await _submitSearch(tester, 'A');
      api.completerFor('A').complete(_textResult('a-hit'));
      await tester.pump();

      await tester.tap(find.text('a-hit'));
      await tester.pumpAndSettle();

      expect(find.text('open search'), findsOneWidget); // popped back
      expect(located, hasLength(1));
      expect(located.single.message.id, 'a-hit');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tapping a card result opens the card without leaving the search page',
    (tester) async {
      _useDesignCanvas(tester);
      final api = _FakeSearchApi();
      final located = <MessageSearchHit>[];
      final openedCards = <ChatComponentCard>[];
      await tester.pumpWidget(
        _pushHarness(
          api,
          onLocateMessage: (hit) async => located.add(hit),
          onOpenComponentCard: (card) async => openedCards.add(card),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('open search'));
      await tester.pumpAndSettle();

      await _submitSearch(tester, 'A');
      api.completerFor('A').complete(_cardResult('card-hit'));
      await tester.pump();

      // warnIfMissed: false — the raw text sits under an IgnorePointer, so
      // the framework's own hit-test probe (aimed at the Text's exact
      // RenderParagraph) reports a miss even though the tap correctly lands
      // on the opaque GestureDetector wrapping it (asserted below).
      await tester.tap(find.text('美式咖啡'), warnIfMissed: false);
      await tester.pump();

      expect(openedCards, hasLength(1));
      expect(located, isEmpty);
      expect(find.text('open search'), findsNothing); // still on search page
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tapping a card row outside the card locates the message instead of opening it',
    (tester) async {
      _useDesignCanvas(tester);
      final api = _FakeSearchApi();
      final located = <MessageSearchHit>[];
      final openedCards = <ChatComponentCard>[];
      await tester.pumpWidget(
        _pushHarness(
          api,
          onLocateMessage: (hit) async => located.add(hit),
          onOpenComponentCard: (card) async => openedCards.add(card),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('open search'));
      await tester.pumpAndSettle();

      await _submitSearch(tester, 'A');
      api.completerFor('A').complete(_cardResult('card-hit'));
      await tester.pump();

      await tester.tap(find.text('小芜')); // the row's header, not the card
      await tester.pumpAndSettle();

      expect(openedCards, isEmpty);
      expect(located, hasLength(1));
      expect(located.single.message.id, 'card-hit');
      expect(find.text('open search'), findsOneWidget); // popped back
      expect(tester.takeException(), isNull);
    },
  );
}
