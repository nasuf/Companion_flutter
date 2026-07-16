import 'dart:ui' as ui;

import 'package:companion_flutter/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
    await tester.pumpAndSettle();

    expect(find.text('灵魂倾向'), findsOneWidget);
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
}
