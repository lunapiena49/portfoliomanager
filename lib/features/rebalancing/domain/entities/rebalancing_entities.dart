import 'package:equatable/equatable.dart';

/// Stores the user's target percentage for a single portfolio position
class RebalanceTarget extends Equatable {
  final String positionId;
  final String symbol;
  final String name;
  final double targetPercent;

  const RebalanceTarget({
    required this.positionId,
    required this.symbol,
    required this.name,
    required this.targetPercent,
  });

  RebalanceTarget copyWith({
    String? positionId,
    String? symbol,
    String? name,
    double? targetPercent,
  }) {
    return RebalanceTarget(
      positionId: positionId ?? this.positionId,
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      targetPercent: targetPercent ?? this.targetPercent,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'positionId': positionId,
      'symbol': symbol,
      'name': name,
      'targetPercent': targetPercent,
    };
  }

  factory RebalanceTarget.fromJson(Map<String, dynamic> json) {
    return RebalanceTarget(
      positionId: json['positionId'] as String,
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      targetPercent: (json['targetPercent'] as num).toDouble(),
    );
  }

  @override
  List<Object?> get props => [positionId, symbol, name, targetPercent];
}

/// Computed result for a single position after rebalancing calculation
class RebalanceResult extends Equatable {
  final String positionId;
  final String symbol;
  final String name;
  final double currentPercent;
  final double targetPercent;
  final double deltaPercent;
  final double currentValue;
  final double targetValue;
  final double deltaValue;
  final String currency;

  const RebalanceResult({
    required this.positionId,
    required this.symbol,
    required this.name,
    required this.currentPercent,
    required this.targetPercent,
    required this.deltaPercent,
    required this.currentValue,
    required this.targetValue,
    required this.deltaValue,
    required this.currency,
  });

  /// Whether this position needs to increase
  bool get needsIncrease => deltaPercent > 0.001;

  /// Whether this position needs to decrease
  bool get needsDecrease => deltaPercent < -0.001;

  /// Whether this position is already at target
  bool get isAtTarget => !needsIncrease && !needsDecrease;

  @override
  List<Object?> get props => [
        positionId,
        symbol,
        name,
        currentPercent,
        targetPercent,
        deltaPercent,
        currentValue,
        targetValue,
        deltaValue,
        currency,
      ];
}
