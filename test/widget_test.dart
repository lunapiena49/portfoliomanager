// Basic smoke test for Portfolio Manager.
//
// The full PortfolioManagerApp requires Hive + EasyLocalization + ScreenUtil
// bootstrap which is non-trivial in unit tests, and even AppTheme.lightTheme
// touches `.h` (flutter_screenutil). Here we only test pure constants that
// don't depend on runtime initialization.
//
// TODO: expand with real bloc/parser/widget tests (see Sprint 1).

import 'package:flutter_test/flutter_test.dart';

import 'package:portfolio_manager/core/theme/app_theme.dart';

void main() {
  group('AppTheme constants', () {
    test('brand colors are stable', () {
      expect(AppTheme.primaryColor.toARGB32(), 0xFF1E88E5);
      expect(AppTheme.accentColor.toARGB32(), 0xFF00BFA5);
    });

    test('semantic colors are stable', () {
      expect(AppTheme.profitColor.toARGB32(), 0xFF00C853);
      expect(AppTheme.lossColor.toARGB32(), 0xFFFF1744);
    });
  });
}
