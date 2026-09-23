import 'dart:ui' as ui;

import 'package:companion_flutter/companion_api.dart';
import 'package:companion_flutter/main.dart';
import 'package:companion_flutter/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingCreateApi extends CompanionApi {
  _RecordingCreateApi() : super(baseUrl: 'http://localhost:8000');

  String? submittedName;
  String? submittedGender;
  var nameWasPassed = false;

  @override
  Future<AgentProfile> createAgent({
    required String userId,
    String? name,
    required String gender,
    required Map<String, int> personality,
  }) async {
    nameWasPassed = true;
    submittedName = name;
    submittedGender = gender;
    throw const ApiException(500, 'stop-before-provision');
  }
}

Future<void> _pumpAgentCreatePage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AgentCreatePage(),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('follows the two-step Figma agent creation flow', (tester) async {
    await _pumpAgentCreatePage(tester);

    expect(find.text('寻找专属你的TA'), findsOneWidget);
    expect(find.text('TA是男生还是女生？'), findsOneWidget);
    expect(find.text('性别设置后将无法修改'), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-gender-female')), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-gender-male')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('agent-gender-male')));
    await tester.pumpAndSettle();
    final maleSemantics = tester.getSemantics(
      find.byKey(const ValueKey('agent-gender-male')),
    );
    expect(maleSemantics.flagsCollection.isSelected, ui.Tristate.isTrue);

    await tester.tap(find.byKey(const ValueKey('agent-create-next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    final traitsTitle = find.text('灵魂倾向');
    final enteringX = tester.getTopLeft(traitsTitle).dx;
    expect(enteringX, greaterThan(20));
    expect(enteringX, lessThan(410));

    await tester.pumpAndSettle();

    expect(tester.getTopLeft(traitsTitle).dx, closeTo(20, 0.1));
    expect(find.text('随机生成'), findsOneWidget);
    expect(find.text('活泼度'), findsOneWidget);
    expect(find.text('理性度'), findsOneWidget);
    expect(find.text('幽默度'), findsOneWidget);
    expect(find.text('上一步'), findsOneWidget);
    expect(find.text('让故事开始'), findsOneWidget);

    const tooltipCopy = {
      '活泼度': '代表日常表达与相处状态',
      '理性度': '代表遇事思考方式',
      '感性度': '代表共情感知能力',
      '计划度': '代表生活处事习惯',
      '随性度': '代表行事包容程度',
      '脑洞度': '代表想象力与思维模式',
      '幽默度': '代表相处趣味感',
    };
    for (final entry in tooltipCopy.entries) {
      final infoButton = find.byKey(ValueKey('agent-trait-info-${entry.key}'));
      await tester.tap(infoButton);
      await tester.pump();
      expect(find.text(entry.value), findsOneWidget);
      await tester.tap(infoButton);
      await tester.pump();
      expect(find.text(entry.value), findsNothing);
    }

    await tester.tap(find.byKey(const ValueKey('agent-create-previous')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getTopLeft(traitsTitle).dx, greaterThan(20));
    await tester.pumpAndSettle();
    expect(find.text('TA是男生还是女生？'), findsOneWidget);
  });

  testWidgets('keeps the real submission guard on the final action', (
    tester,
  ) async {
    await _pumpAgentCreatePage(tester);
    await tester.tap(find.byKey(const ValueKey('agent-create-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('agent-create-submit')));
    await tester.pump();

    expect(find.text('请先完成账号登录，再创建 Agent。'), findsOneWidget);
  });

  testWidgets('submits the selected gender and lets the server name the agent', (
    tester,
  ) async {
    final api = _RecordingCreateApi();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: AgentCreatePage(
          api: api,
          session: const AuthSession(
            token: 'token',
            userId: 'user-1',
            username: 'anan',
            role: UserRole.user,
            hasAgent: false,
          ),
          onCreated: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('小芜'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('agent-gender-male')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('agent-create-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('agent-create-submit')));
    await tester.pump();

    expect(api.nameWasPassed, isTrue);
    expect(api.submittedName, isNull);
    expect(api.submittedGender, 'male');
    expect(find.text('stop-before-provision'), findsOneWidget);
  });
}
