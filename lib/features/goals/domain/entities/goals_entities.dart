import 'package:equatable/equatable.dart';

/// Investment goal types
enum GoalType {
  retirement,
  education,
  house,
  emergency,
  travel,
  custom,
}

/// Goal status
enum GoalStatus {
  active,
  completed,
  paused,
  cancelled,
}

/// Represents an investment goal
class InvestmentGoal extends Equatable {
  final String id;
  final String name;
  final String? description;
  final GoalType type;
  final GoalStatus status;
  final double targetAmount;
  final double currentAmount;
  final String currency;
  final DateTime? targetDate;
  final DateTime createdAt;
  final DateTime? completedAt;
  final double? monthlyContribution;
  final List<GoalMilestone>? milestones;
  final TargetAllocation? targetAllocation;

  const InvestmentGoal({
    required this.id,
    required this.name,
    this.description,
    required this.type,
    required this.status,
    required this.targetAmount,
    required this.currentAmount,
    required this.currency,
    this.targetDate,
    required this.createdAt,
    this.completedAt,
    this.monthlyContribution,
    this.milestones,
    this.targetAllocation,
  });

  /// Calculate progress percentage (0-100)
  double get progressPercent {
    if (targetAmount == 0) return 0;
    return (currentAmount / targetAmount * 100).clamp(0, 100);
  }

  /// Calculate remaining amount
  double get remainingAmount {
    return (targetAmount - currentAmount).clamp(0, double.infinity);
  }

  /// Calculate months remaining to target date
  int? get monthsRemaining {
    if (targetDate == null) return null;
    final now = DateTime.now();
    if (targetDate!.isBefore(now)) return 0;
    return (targetDate!.difference(now).inDays / 30).ceil();
  }

  /// Calculate required monthly contribution to reach goal
  double? get requiredMonthlyContribution {
    final months = monthsRemaining;
    if (months == null || months == 0) return null;
    return remainingAmount / months;
  }

  /// Check if on track based on current contribution rate
  bool get isOnTrack {
    if (monthlyContribution == null || requiredMonthlyContribution == null) {
      return false;
    }
    return monthlyContribution! >= requiredMonthlyContribution!;
  }

  InvestmentGoal copyWith({
    String? id,
    String? name,
    String? description,
    GoalType? type,
    GoalStatus? status,
    double? targetAmount,
    double? currentAmount,
    String? currency,
    DateTime? targetDate,
    DateTime? createdAt,
    DateTime? completedAt,
    double? monthlyContribution,
    List<GoalMilestone>? milestones,
    TargetAllocation? targetAllocation,
  }) {
    return InvestmentGoal(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      currency: currency ?? this.currency,
      targetDate: targetDate ?? this.targetDate,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      monthlyContribution: monthlyContribution ?? this.monthlyContribution,
      milestones: milestones ?? this.milestones,
      targetAllocation: targetAllocation ?? this.targetAllocation,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.name,
      'status': status.name,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'currency': currency,
      'targetDate': targetDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'monthlyContribution': monthlyContribution,
      'milestones': milestones?.map((m) => m.toJson()).toList(),
      'targetAllocation': targetAllocation?.toJson(),
    };
  }

  factory InvestmentGoal.fromJson(Map<String, dynamic> json) {
    return InvestmentGoal(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      type: GoalType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => GoalType.custom,
      ),
      status: GoalStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => GoalStatus.active,
      ),
      targetAmount: (json['targetAmount'] as num).toDouble(),
      currentAmount: (json['currentAmount'] as num).toDouble(),
      currency: json['currency'] as String,
      targetDate: json['targetDate'] != null
          ? DateTime.parse(json['targetDate'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      monthlyContribution: (json['monthlyContribution'] as num?)?.toDouble(),
      milestones: (json['milestones'] as List?)
          ?.map((m) => GoalMilestone.fromJson(m as Map<String, dynamic>))
          .toList(),
      targetAllocation: json['targetAllocation'] != null
          ? TargetAllocation.fromJson(
              json['targetAllocation'] as Map<String, dynamic>)
          : null,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        type,
        status,
        targetAmount,
        currentAmount,
        currency,
        targetDate,
        createdAt,
        completedAt,
        monthlyContribution,
        milestones,
        targetAllocation,
      ];
}

/// Milestone within a goal
class GoalMilestone extends Equatable {
  final String id;
  final String name;
  final double targetAmount;
  final bool isCompleted;
  final DateTime? completedAt;

  const GoalMilestone({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.isCompleted,
    this.completedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'targetAmount': targetAmount,
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory GoalMilestone.fromJson(Map<String, dynamic> json) {
    return GoalMilestone(
      id: json['id'] as String,
      name: json['name'] as String,
      targetAmount: (json['targetAmount'] as num).toDouble(),
      isCompleted: json['isCompleted'] as bool,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [id, name, targetAmount, isCompleted, completedAt];
}

/// Target asset allocation for rebalancing
class TargetAllocation extends Equatable {
  final Map<String, double> assetTypeTargets; // e.g., {'Stocks': 60, 'Bonds': 30, 'Cash': 10}
  final Map<String, double>? sectorTargets;
  final Map<String, double>? regionTargets;
  final double rebalanceThreshold; // Percentage deviation that triggers rebalancing

  const TargetAllocation({
    required this.assetTypeTargets,
    this.sectorTargets,
    this.regionTargets,
    this.rebalanceThreshold = 5.0,
  });

  /// Check if total allocation equals 100%
  bool get isValid {
    final total = assetTypeTargets.values.fold(0.0, (sum, val) => sum + val);
    return (total - 100).abs() < 0.01;
  }

  Map<String, dynamic> toJson() {
    return {
      'assetTypeTargets': assetTypeTargets,
      'sectorTargets': sectorTargets,
      'regionTargets': regionTargets,
      'rebalanceThreshold': rebalanceThreshold,
    };
  }

  factory TargetAllocation.fromJson(Map<String, dynamic> json) {
    return TargetAllocation(
      assetTypeTargets: Map<String, double>.from(
        (json['assetTypeTargets'] as Map).map(
          (key, value) => MapEntry(key as String, (value as num).toDouble()),
        ),
      ),
      sectorTargets: json['sectorTargets'] != null
          ? Map<String, double>.from(
              (json['sectorTargets'] as Map).map(
                (key, value) =>
                    MapEntry(key as String, (value as num).toDouble()),
              ),
            )
          : null,
      regionTargets: json['regionTargets'] != null
          ? Map<String, double>.from(
              (json['regionTargets'] as Map).map(
                (key, value) =>
                    MapEntry(key as String, (value as num).toDouble()),
              ),
            )
          : null,
      rebalanceThreshold:
          (json['rebalanceThreshold'] as num?)?.toDouble() ?? 5.0,
    );
  }

  @override
  List<Object?> get props =>
      [assetTypeTargets, sectorTargets, regionTargets, rebalanceThreshold];
}

/// Rebalancing suggestion
class RebalanceSuggestion extends Equatable {
  final String assetType;
  final String? symbol;
  final double currentAllocation;
  final double targetAllocation;
  final double deviation;
  final RebalanceAction action;
  final double suggestedAmount;
  final String currency;

  const RebalanceSuggestion({
    required this.assetType,
    this.symbol,
    required this.currentAllocation,
    required this.targetAllocation,
    required this.deviation,
    required this.action,
    required this.suggestedAmount,
    required this.currency,
  });

  @override
  List<Object?> get props => [
        assetType,
        symbol,
        currentAllocation,
        targetAllocation,
        deviation,
        action,
        suggestedAmount,
        currency,
      ];
}

enum RebalanceAction {
  buy,
  sell,
  hold,
}

/// Projection data point for goal visualization
class ProjectionPoint extends Equatable {
  final DateTime date;
  final double projectedValue;
  final double? actualValue;

  const ProjectionPoint({
    required this.date,
    required this.projectedValue,
    this.actualValue,
  });

  @override
  List<Object?> get props => [date, projectedValue, actualValue];
}