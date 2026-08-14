import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'achievement_copy_fixtures.dart';

/// Mirrors `_AchievementPopupOneLine`: one line at the Figma font size,
/// clipped instead of wrapping or shrinking.
Widget _popupOneLine({required String text, required TextStyle style}) {
  return Text(
    text.trim(),
    maxLines: 1,
    textAlign: TextAlign.center,
    overflow: TextOverflow.clip,
    style: style,
  );
}

Future<void> _pumpColumn(
  WidgetTester tester, {
  required double width,
  required double height,
  required List<String> copies,
  required TextStyle style,
}) async {
  final columnHeight = height * copies.length;
  tester.view.physicalSize = Size(width, columnHeight);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: Size(width, columnHeight)),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final copy in copies)
                  SizedBox(
                    width: width,
                    height: height,
                    child: _popupOneLine(text: copy, style: style),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('popup body copy stays one 18px line without shrinking', (
    tester,
  ) async {
    const style = TextStyle(
      fontSize: 18,
      height: 22 / 18,
      fontWeight: FontWeight.w700,
    );
    await _pumpColumn(
      tester,
      width: 358,
      height: 31,
      copies: kAchievementPopupCopy,
      style: style,
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(FittedBox), findsNothing);

    final paragraphs = tester
        .renderObjectList<RenderParagraph>(find.byType(RichText))
        .toList();
    expect(paragraphs.length, kAchievementPopupCopy.length);
    for (var i = 0; i < paragraphs.length; i++) {
      expect(paragraphs[i].maxLines, 1, reason: kAchievementPopupCopy[i]);
      expect(paragraphs[i].text.style?.fontSize, 18, reason: kAchievementPopupCopy[i]);
    }
  });

  testWidgets('all achievement names stay on one 24px line', (tester) async {
    const width = 358.0;
    const style = TextStyle(
      fontSize: 24,
      height: 29 / 24,
      fontWeight: FontWeight.w700,
    );
    await _pumpColumn(
      tester,
      width: width,
      height: 47,
      copies: kAchievementNames,
      style: style,
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(FittedBox), findsNothing);

    final paragraphs = tester
        .renderObjectList<RenderParagraph>(find.byType(RichText))
        .toList();
    expect(paragraphs.length, kAchievementNames.length);
    for (var i = 0; i < paragraphs.length; i++) {
      expect(paragraphs[i].maxLines, 1, reason: kAchievementNames[i]);
      expect(paragraphs[i].text.style?.fontSize, 24, reason: kAchievementNames[i]);
      expect(
        paragraphs[i].getMaxIntrinsicWidth(double.infinity),
        lessThanOrEqualTo(width + 0.5),
        reason: kAchievementNames[i],
      );
    }
  });

  testWidgets('card copy stays on one line in a 140pt tile', (tester) async {
    const width = 140.0;
    const height = 18.0;
    final columnHeight = height * kAchievementPopupCopy.length;
    tester.view.physicalSize = Size(width, columnHeight);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: Size(width, columnHeight)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final copy in kAchievementPopupCopy)
                    SizedBox(
                      width: width,
                      height: height,
                      child: Text(
                        copy,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, height: 1.34),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final paragraphs = tester
        .renderObjectList<RenderParagraph>(find.byType(RichText))
        .toList();
    expect(paragraphs.length, kAchievementPopupCopy.length);
    for (var i = 0; i < paragraphs.length; i++) {
      expect(paragraphs[i].maxLines, 1, reason: kAchievementPopupCopy[i]);
      expect(
        paragraphs[i].size.width,
        lessThanOrEqualTo(width + 0.01),
        reason: kAchievementPopupCopy[i],
      );
    }
  });
}
