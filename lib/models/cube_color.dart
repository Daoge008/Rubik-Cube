import 'package:flutter/material.dart';

enum CubeColor {
  white,
  red,
  green,
  yellow,
  orange,
  blue,
  unknown;

  Color get displayColor {
    switch (this) {
      case CubeColor.white:
        return Colors.white;
      case CubeColor.red:
        return const Color(0xFFE53935);
      case CubeColor.green:
        return const Color(0xFF43A047);
      case CubeColor.yellow:
        return const Color(0xFFFDD835);
      case CubeColor.orange:
        return const Color(0xFFFB8C00);
      case CubeColor.blue:
        return const Color(0xFF1E88E5);
      case CubeColor.unknown:
        return Colors.grey.shade700;
    }
  }

  String get notation {
    switch (this) {
      case CubeColor.white:
        return 'U';
      case CubeColor.red:
        return 'R';
      case CubeColor.green:
        return 'F';
      case CubeColor.yellow:
        return 'D';
      case CubeColor.orange:
        return 'L';
      case CubeColor.blue:
        return 'B';
      case CubeColor.unknown:
        return '?';
    }
  }

  static CubeColor fromNotation(String char) {
    switch (char.toUpperCase()) {
      case 'U': case 'W': return CubeColor.white;
      case 'R': return CubeColor.red;
      case 'F': case 'G': return CubeColor.green;
      case 'D': case 'Y': return CubeColor.yellow;
      case 'L': case 'O': return CubeColor.orange;
      case 'B': return CubeColor.blue;
      default: return CubeColor.unknown;
    }
  }

  static CubeColor fromInt(int val) {
    if (val >= 0 && val < CubeColor.values.length) {
      return CubeColor.values[val];
    }
    return CubeColor.unknown;
  }
}
