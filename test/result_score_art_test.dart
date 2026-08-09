import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Result screens show a piece of art when the round settles for exactly what
/// that art reads, and fall back to drawing the number otherwise. A game that
/// names a value therefore has to ship the matching image — 数字合并 pays out
/// milestones instead and deliberately ships none.
///
/// This guards the case where a game's art is removed (or a value is added)
/// without the other half following: the mismatch would only surface as a
/// broken image on the result screen, at the end of a real round.
void main() {
  const base = 'assets/prototype/games/';
  // 目录 → 是否声明了 win / lose 分值（即是否需要素材）
  const games = <String, bool>{
    'gomoku': true,
    'go': true,
    'reversi': true,
    'xiangqi': true,
    'chess-figma': true,
    'checkers-figma': true,
    'minesweeper-figma': true,
    'tetris-figma': true,
    'merge-figma': false,
  };

  games.forEach((dir, needsArt) {
    test('$dir ${needsArt ? 'ships' : 'ships no'} score art', () {
      for (final name in ['result_score_win.png', 'result_score_lose.png']) {
        final path = '$base$dir/$name';
        expect(
          File(path).existsSync(),
          needsArt,
          reason: needsArt
              ? '$path 缺失，结算页会显示破图'
              : '$path 不该存在：该游戏的分值是动态的，只能画文字',
        );
      }
    });
  });
}
