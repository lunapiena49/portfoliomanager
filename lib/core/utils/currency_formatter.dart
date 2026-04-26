import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static String symbolFor(String currency) {
    switch (currency.toUpperCase()) {
      case 'USD':
        return r'$';
      case 'EUR':
        return 'EUR ';
      case 'GBP':
        return 'GBP ';
      case 'CHF':
        return 'CHF ';
      case 'JPY':
        return 'JPY ';
      case 'CAD':
        return 'CAD ';
      case 'AUD':
        return 'AUD ';
      default:
        return '${currency.toUpperCase()} ';
    }
  }

  static String format(
    double value,
    String currency, {
    String? locale,
    int decimalDigits = 2,
  }) {
    final formatter = NumberFormat.currency(
      locale: locale,
      symbol: symbolFor(currency),
      decimalDigits: decimalDigits,
    );
    return formatter.format(value);
  }

  static String formatPercent(double percent, {int decimals = 1}) {
    if (percent > 0 && percent < 0.1) {
      return '< 0.1%';
    }
    return '${percent.toStringAsFixed(decimals)}%';
  }
}
