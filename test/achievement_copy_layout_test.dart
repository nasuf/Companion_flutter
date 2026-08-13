import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'achievement_copy_fixtures.dart';

/// Mirrors `_AchievementPopupOneLine` in achievement_feedback.dart: one line,
/// scale down to the CSS slot instead of wrapping or overflowing.
Widget _popupOneLine({required String text, required TextStyle style}) {
  return FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.center,
    child: Text(
      text.trim(),
      maxLines: 1,
      softWrap: false,
      textAlign: TextAlign.center,
      style: style,
    ),
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

void _expectOneLineFits({
  required List<String> copies,
  required List<RenderBox> slots,
  required List<RenderParagraph> paragraphs,
  required double maxWidth,
  required double maxHeight,
  required double minScale,
}) {
  expect(slots.length, copies.length);
  expect(paragraphs.length, copies.length);
  for (var i = 0; i < copies.length; i++) {
    final parent = slots[i].size;
    final child = paragraphs[i].size;
    expect(parent.width, lessThanOrEqualTo(maxWidth + 0.01), reason: copies[i]);
    expect(
      parent.height,
      lessThanOrEqualTo(maxHeight + 0.01),
      reason: copies[i],
    );
    expect(paragraphs[i].maxLines, 1, reason: copies[i]);
    expect(paragraphs[i].didExceedMaxLines, isFalse, reason: copies[i]);
    final scale = math.min(
      1.0,
      math.min(parent.width / child.width, parent.height / child.height),
    );
    expect(
      child.width * scale,
      lessThanOrEqualTo(parent.width + 0.5),
      reason: copies[i],
    );
    expect(scale, greaterThanOrEqualTo(minScale), reason: copies[i]);
  }
}

void main() {
  testWidgets('all popup body copy stays on one 296pt line', (tester) async {
    await _pumpColumn(
      tester,
      width: 296,
      height: 31,
      copies: kAchievementPopupCopy,
      style: const TextStyle(
        fontSize: 18,
        height: 22 / 18,
        fontWeight: FontWeight.w700,
      ),
    );
    expect(tester.takeException(), isNull);
    _expectOneLineFits(
      copies: kAchievementPopupCopy,
      slots: tester
          .renderObjectList<RenderBox>(find.byType(FittedBox))
          .toList(),
      paragraphs: tester
          .renderObjectList<RenderParagraph>(find.byType(RichText))
          .toList(),
      maxWidth: 296,
      maxHeight: 31,
      minScale: 0.65,
    );
  });

  testWidgets('all achievement names stay on one 296pt line', (tester) async {
    await _pumpColumn(
      tester,
      width: 296,
      height: 47,
      copies: kAchievementNames,
      style: const TextStyle(
        fontSize: 24,
        height: 29 / 24,
        fontWeight: FontWeight.w700,
      ),
    );
    expect(tester.takeException(), isNull);
    _expectOneLineFits(
      copies: kAchievementNames,
      slots: tester
          .renderObjectList<RenderBox>(find.byType(FittedBox))
          .toList(),
      paragraphs: tester
          .renderObjectList<RenderParagraph>(find.byType(RichText))
          .toList(),
      maxWidth: 296,
      maxHeight: 47,
      minScale: 0.85,
    );
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
