import 'package:flutter/material.dart';

class AppStyles {
  static const double cardRadius = 16.0;
  static const double pillRadius = 25.0;

  static const double borderWidth = 1.0;
  static Color get border => Colors.grey.shade300;

  static Color get surface => Colors.white;
  static Color get surfaceMuted => Colors.grey.shade50;

  static Color get _shadowColor => const Color.fromRGBO(0, 0, 0, 0.1);
  static BoxShadow get shadow => BoxShadow(
        color: _shadowColor,
        offset: const Offset(0, 6),
        blurRadius: 10,
      );

  static Color get textPrimary => Colors.grey.shade800;
  static Color get textSecondary => Colors.grey.shade800;

  static Color get accentActive => Colors.grey.shade700;
  static Color get accentInactive => Colors.grey.shade500;

  static Color get controlBgActive => Colors.grey.shade200;
  static Color get controlBg => Colors.transparent;

  static Color get compassDotBg => Colors.white;
  static Color get compassDotBorder => Colors.grey.shade400;
  static Color get compassArc => Colors.grey.shade300;

  static Color get hotspotBg => Colors.white;
  static Color get hotspotIcon => Colors.grey.shade800;
  static Color get hotspotBorder => Colors.grey.shade300;
  static Color get hotspotLabelBg => Colors.white;
  static Color get hotspotLabelText => Colors.grey.shade800;
}
