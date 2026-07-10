import 'package:flutter/material.dart';

class AppStyles {
  static const double cardRadius = 16.0;
  static const double pillRadius = 25.0;

  static const double borderWidth = 1.0;

  static const Color _colDark = Color(0xFF333d4d);
  static const Color _colMid = Color(0xFF98bccf);
  static const Color _colAccent = Color(0xFFfcd532);
  static const Color _colBeige = Color(0xFFf5ede0);
  static const Color _colBeigeLighter = Color.fromARGB(255, 255, 254, 252);
  static const Color _colWhite = Color(0xFFfffdfe);

  static const Color _colWhiteDarker = Color.fromARGB(255, 184, 177, 177);

  static Color get border => _colWhiteDarker;

  static Color get surface => _colWhite;
  static Color get surfaceMuted => _colBeigeLighter;
  static Color get surfaceAccent => _colBeige;

  static Color get _shadowColor => _colDark.withOpacity(0.1);
  static BoxShadow get shadow => BoxShadow(
        color: _shadowColor,
        offset: const Offset(0, 6),
        blurRadius: 10,
      );

  static Color get textPrimary => _colDark;
  static Color get textSecondary => _colDark.withOpacity(0.6);

  static Color get accentActive => _colDark;
  static Color get accentInactive => _colMid;

  static Color get controlBgActive => _colAccent;
  static Color get controlBg => Colors.transparent;

  static Color get compassDotBg => _colAccent;
  static Color get compassDotBorder => _colDark;
  static Color get compassArc => _colMid;

  static Color get hotspotBg => _colAccent;
  static Color get hotspotIcon => _colDark;
  static Color get hotspotBorder => _colDark;
  static Color get hotspotLabelBg => _colWhite;
  static Color get hotspotLabelText => _colDark;
}
