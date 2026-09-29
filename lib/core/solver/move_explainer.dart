import 'package:flutter/material.dart';

class MoveExplanation {
  final String token;
  final String faceName;
  final Color faceColor;
  final String action;
  final String mnemonic;
  final String detail;

  const MoveExplanation({
    required this.token,
    required this.faceName,
    required this.faceColor,
    required this.action,
    required this.mnemonic,
    required this.detail,
  });
}

class MoveExplainer {
  static const Map<String, MoveExplanation> _moveDatabase = {
    'U': MoveExplanation(
      token: 'U',
      faceName: '顶层 (白色面)',
      faceColor: Colors.white,
      action: '向左拨转 90°',
      mnemonic: '顶左',
      detail: '用右手食指将顶层向左拨动 90°（顺时针）',
    ),
    "U'": MoveExplanation(
      token: "U'",
      faceName: '顶层 (白色面)',
      faceColor: Colors.white,
      action: '向右拨转 90°',
      mnemonic: '顶右',
      detail: '用左手食指将顶层向右拨动 90°（逆时针）',
    ),
    'U2': MoveExplanation(
      token: 'U2',
      faceName: '顶层 (白色面)',
      faceColor: Colors.white,
      action: '转动 180° (半圈)',
      mnemonic: '顶转半圈',
      detail: '食指拨动两次顶层，旋转 180 度',
    ),
    'D': MoveExplanation(
      token: 'D',
      faceName: '底层 (黄色面)',
      faceColor: Color(0xFFFDD835),
      action: '向右拨转 90°',
      mnemonic: '底右',
      detail: '用右手无名指将底层向右拨动 90°（顺时针）',
    ),
    "D'": MoveExplanation(
      token: "D'",
      faceName: '底层 (黄色面)',
      faceColor: Color(0xFFFDD835),
      action: '向左拨转 90°',
      mnemonic: '底左',
      detail: '用左手无名指将底层向左拨动 90°（逆时针）',
    ),
    'D2': MoveExplanation(
      token: 'D2',
      faceName: '底层 (黄色面)',
      faceColor: Color(0xFFFDD835),
      action: '转动 180° (半圈)',
      mnemonic: '底转半圈',
      detail: '旋转底层 180 度（顺逆皆可）',
    ),
    'R': MoveExplanation(
      token: 'R',
      faceName: '右层 (红色面)',
      faceColor: Color(0xFFE53935),
      action: '向上推转 90°',
      mnemonic: '右上',
      detail: '右手握住右侧层，向上推转 90°（顺时针）',
    ),
    "R'": MoveExplanation(
      token: "R'",
      faceName: '右层 (红色面)',
      faceColor: Color(0xFFE53935),
      action: '向下拉转 90°',
      mnemonic: '右下',
      detail: '右手握住右侧层，向下拉转 90°（逆时针）',
    ),
    'R2': MoveExplanation(
      token: 'R2',
      faceName: '右层 (红色面)',
      faceColor: Color(0xFFE53935),
      action: '转动 180° (半圈)',
      mnemonic: '右转半圈',
      detail: '右手连续推转右层 180 度',
    ),
    'L': MoveExplanation(
      token: 'L',
      faceName: '左层 (橙色面)',
      faceColor: Color(0xFFFB8C00),
      action: '向下拉转 90°',
      mnemonic: '左下',
      detail: '左手握住左侧层，向下拉转 90°（顺时针）',
    ),
    "L'": MoveExplanation(
      token: "L'",
      faceName: '左层 (橙色面)',
      faceColor: Color(0xFFFB8C00),
      action: '向上推转 90°',
      mnemonic: '左上',
      detail: '左手握住左侧层，向上推转 90°（逆时针）',
    ),
    'L2': MoveExplanation(
      token: 'L2',
      faceName: '左层 (橙色面)',
      faceColor: Color(0xFFFB8C00),
      action: '转动 180° (半圈)',
      mnemonic: '左转半圈',
      detail: '左手连续拉转左层 180 度',
    ),
    'F': MoveExplanation(
      token: 'F',
      faceName: '正面 (绿色面)',
      faceColor: Color(0xFF43A047),
      action: '顺时针转 90°',
      mnemonic: '前顺',
      detail: '面向正对自己的一面，顺时针旋转 90°',
    ),
    "F'": MoveExplanation(
      token: "F'",
      faceName: '正面 (绿色面)',
      faceColor: Color(0xFF43A047),
      action: '逆时针转 90°',
      mnemonic: '前逆',
      detail: '面向正对自己的一面，逆时针旋转 90°',
    ),
    'F2': MoveExplanation(
      token: 'F2',
      faceName: '正面 (绿色面)',
      faceColor: Color(0xFF43A047),
      action: '转动 180° (半圈)',
      mnemonic: '前转半圈',
      detail: '正面旋转 180 度（半圈）',
    ),
    'B': MoveExplanation(
      token: 'B',
      faceName: '背面 (蓝色面)',
      faceColor: Color(0xFF1E88E5),
      action: '顺时针转 90°',
      mnemonic: '后顺',
      detail: '从后方向前看顺时针转 90°（正视向右向下）',
    ),
    "B'": MoveExplanation(
      token: "B'",
      faceName: '背面 (蓝色面)',
      faceColor: Color(0xFF1E88E5),
      action: '逆时针转 90°',
      mnemonic: '后逆',
      detail: '从后方向前看逆时针转 90°（正视向左向下）',
    ),
    'B2': MoveExplanation(
      token: 'B2',
      faceName: '背面 (蓝色面)',
      faceColor: Color(0xFF1E88E5),
      action: '转动 180° (半圈)',
      mnemonic: '后转半圈',
      detail: '背面层转动 180 度',
    ),
  };

  /// Common known speedcubing algorithm names
  static const Map<String, String> _knownFormulas = {
    "R U R' U'": '经典右手手法（上左下右）',
    "L' U' L U": '经典左手手法（上右下左）',
    "R' F R F'": '雪橇手法（Sledgehammer）',
    "F R U R' U' F'": '顶面黄色十字公式',
    "R U R' U R U2 R'": '小鱼1公式（Sune）',
    "R U2 R' U' R U' R'": '小鱼2公式（Anti-Sune）',
    "U R U' R'": '右手藏块手法',
    "U' L' U L": '左手藏块手法',
  };

  /// Returns detailed explanation of a single move token (e.g. "R'", "U2")
  static MoveExplanation explainMove(String token) {
    final t = token.trim();
    if (_moveDatabase.containsKey(t)) {
      return _moveDatabase[t]!;
    }
    // Fallback if token has spaces or modifiers
    final face = t.isNotEmpty ? t[0].toUpperCase() : 'U';
    final isPrime = t.contains("'");
    final isDouble = t.contains('2');
    final mod = isDouble ? '2' : (isPrime ? "'" : '');
    final norm = '$face$mod';

    return _moveDatabase[norm] ??
        MoveExplanation(
          token: t,
          faceName: '$face 层',
          faceColor: Colors.white,
          action: '转动 $t',
          mnemonic: t,
          detail: '转动 $face 层',
        );
  }

  /// Translates a full sequence like "R U R' U'" into a concise readable mnemonic string.
  /// Example: "右上 → 顶左 → 右下 → 顶右 (经典右手手法)"
  static String translateSequence(String notation) {
    final tokens = notation.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (tokens.isEmpty) return '';

    final mnemonics = tokens.map((t) => explainMove(t).mnemonic).join(' → ');
    final cleanFormula = tokens.join(' ');
    if (_knownFormulas.containsKey(cleanFormula)) {
      return '$mnemonics （${_knownFormulas[cleanFormula]}）';
    }
    return mnemonics;
  }

  /// Returns a full list of token explanations for multi-step rendering
  static List<MoveExplanation> explainSequence(String notation) {
    final tokens = notation.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    return tokens.map(explainMove).toList();
  }
}
