import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import '../../../../services/storage/local_storage_service.dart';
import '../../domain/entities/goals_entities.dart';
import '../../../portfolio/domain/entities/portfolio_entities.dart';

// Events
abstract class GoalsEvent extends Equatable {
  const GoalsEvent();

  @override
  List<Object?> get props => [];
}

class LoadGoalsEvent extends GoalsEvent {}

class AddGoalEvent extends GoalsEvent {
  final String name;
  final String? description;
  final GoalType type;
  final double targetAmount;
  final String currency;
  final DateTime? targetDate;
  final double? monthlyContribution;
  final TargetAllocation? targetAllocation;

  const AddGoalEvent({
    required this.name,
    this.description,
    required this.type,
    required this.targetAmount,
    required this.currency,
    this.targetDate,
    this.monthlyContribution,
    this.targetAllocation,
  });

  @override
  List<Object?> get props => [
        name,
        description,
        type,
        targetAmount,
        currency,
        targetDate,
        monthlyContribution,
        targetAllocation,
      ];
}

class UpdateGoalEvent extends GoalsEvent {
  final InvestmentGoal goal;

  const UpdateGoalEvent({required this.goal});

  @override
  List<Object?> get props => [goal];
}

class DeleteGoalEvent extends GoalsEvent {
  final String goalId;

  const DeleteGoalEvent({required this.goalId});

  @override
  List<Object?> get props => [goalId];
}

class UpdateGoalProgressEvent extends GoalsEvent {
  final String goalId;
  final double newAmount;

  const UpdateGoalProgressEvent({
    required this.goalId,
    required this.newAmount,
  });

  @override
  List<Object?> get props => [goalId, newAmount];
}

class SyncWithPortfolioEvent extends GoalsEvent {
  final Portfolio portfolio;

  const SyncWithPortfolioEvent({required this.portfolio});

  @override
  List<Object?> get props => [portfolio];
}

class CalculateRebalanceEvent extends GoalsEvent {
  final String goalId;
  final Portfolio portfolio;

  const CalculateRebalanceEvent({
    required this.goalId,
    required this.portfolio,
  });

  @override
  List<Object?> get props => [goalId, portfolio];
}

// States
abstract class GoalsState extends Equatable {
  const GoalsState();

  @override
  List<Object?> get props => [];
}

class GoalsInitial extends GoalsState {}

class GoalsLoading extends GoalsState {}

class GoalsLoaded extends GoalsState {
  final List<InvestmentGoal> goals;
  final List<RebalanceSuggestion>? rebalanceSuggestions;
  final String? selectedGoalId;

  const GoalsLoaded({
    required this.goals,
    this.rebalanceSuggestions,
    this.selectedGoalId,
  });

  @override
  List<Object?> get props => [goals, rebalanceSuggestions, selectedGoalId];

  GoalsLoaded copyWith({
    List<InvestmentGoal>? goals,
    List<RebalanceSuggestion>? rebalanceSuggestions,
    String? selectedGoalId,
  }) {
    return GoalsLoaded(
      goals: goals ?? this.goals,
      rebalanceSuggestions: rebalanceSuggestions ?? this.rebalanceSuggestions,
      selectedGoalId: selectedGoalId ?? this.selectedGoalId,
    );
  }
}

class GoalsError extends GoalsState {
  final String message;

  const GoalsError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class GoalsBloc extends Bloc<GoalsEvent, GoalsState> {
  final LocalStorageService _storageService;
  static const _uuid = Uuid();

  GoalsBloc({required LocalStorageService storageService})
      : _storageService = storageService,
        super(GoalsInitial()) {
    on<LoadGoalsEvent>(_onLoadGoals);
    on<AddGoalEvent>(_onAddGoal);
    on<UpdateGoalEvent>(_onUpdateGoal);
    on<DeleteGoalEvent>(_onDeleteGoal);
    on<UpdateGoalProgressEvent>(_onUpdateGoalProgress);
    on<SyncWithPortfolioEvent>(_onSyncWithPortfolio);
    on<CalculateRebalanceEvent>(_onCalculateRebalance);
  }

  Future<void> _onLoadGoals(
    LoadGoalsEvent event,
    Emitter<GoalsState> emit,
  ) async {
    emit(GoalsLoading());

    try {
      final goals = await _storageService.getGoals();
      emit(GoalsLoaded(goals: goals));
    } catch (e) {
      emit(GoalsError('Failed to load goals: $e'));
    }
  }

  Future<void> _onAddGoal(
    AddGoalEvent event,
    Emitter<GoalsState> emit,
  ) async {
    final currentState = state;
    if (currentState is! GoalsLoaded) return;

    try {
      final newGoal = InvestmentGoal(
        id: _uuid.v4(),
        name: event.name,
        description: event.description,
        type: event.type,
        status: GoalStatus.active,
        targetAmount: event.targetAmount,
        currentAmount: 0,
        currency: event.currency,
        targetDate: event.targetDate,
        createdAt: DateTime.now(),
        monthlyContribution: event.monthlyContribution,
        targetAllocation: event.targetAllocation,
      );

      final updatedGoals = [...currentState.goals, newGoal];
      await _storageService.saveGoals(updatedGoals);

      emit(currentState.copyWith(goals: updatedGoals));
    } catch (e) {
      emit(GoalsError('Failed to add goal: $e'));
    }
  }

  Future<void> _onUpdateGoal(
    UpdateGoalEvent event,
    Emitter<GoalsState> emit,
  ) async {
    final currentState = state;
    if (currentState is! GoalsLoaded) return;

    try {
      final updatedGoals = currentState.goals.map((g) {
        return g.id == event.goal.id ? event.goal : g;
      }).toList();

      await _storageService.saveGoals(updatedGoals);
      emit(currentState.copyWith(goals: updatedGoals));
    } catch (e) {
      emit(GoalsError('Failed to update goal: $e'));
    }
  }

  Future<void> _onDeleteGoal(
    DeleteGoalEvent event,
    Emitter<GoalsState> emit,
  ) async {
    final currentState = state;
    if (currentState is! GoalsLoaded) return;

    try {
      final updatedGoals =
          currentState.goals.where((g) => g.id != event.goalId).toList();

      await _storageService.saveGoals(updatedGoals);
      emit(currentState.copyWith(goals: updatedGoals));
    } catch (e) {
      emit(GoalsError('Failed to delete goal: $e'));
    }
  }

  Future<void> _onUpdateGoalProgress(
    UpdateGoalProgressEvent event,
    Emitter<GoalsState> emit,
  ) async {
    final currentState = state;
    if (currentState is! GoalsLoaded) return;

    try {
      final updatedGoals = currentState.goals.map((g) {
        if (g.id == event.goalId) {
          var updatedGoal = g.copyWith(currentAmount: event.newAmount);

          // Check if goal is completed
          if (event.newAmount >= g.targetAmount &&
              g.status == GoalStatus.active) {
            updatedGoal = updatedGoal.copyWith(
              status: GoalStatus.completed,
              completedAt: DateTime.now(),
            );
          }

          return updatedGoal;
        }
        return g;
      }).toList();

      await _storageService.saveGoals(updatedGoals);
      emit(currentState.copyWith(goals: updatedGoals));
    } catch (e) {
      emit(GoalsError('Failed to update progress: $e'));
    }
  }

  Future<void> _onSyncWithPortfolio(
    SyncWithPortfolioEvent event,
    Emitter<GoalsState> emit,
  ) async {
    final currentState = state;
    if (currentState is! GoalsLoaded) return;

    try {
      final portfolioValue = event.portfolio.totalValue;

      // Update all active goals with current portfolio value
      final updatedGoals = currentState.goals.map((g) {
        if (g.status == GoalStatus.active) {
          var updatedGoal = g.copyWith(currentAmount: portfolioValue);

          if (portfolioValue >= g.targetAmount) {
            updatedGoal = updatedGoal.copyWith(
              status: GoalStatus.completed,
              completedAt: DateTime.now(),
            );
          }

          return updatedGoal;
        }
        return g;
      }).toList();

      await _storageService.saveGoals(updatedGoals);
      emit(currentState.copyWith(goals: updatedGoals));
    } catch (e) {
      emit(GoalsError('Failed to sync with portfolio: $e'));
    }
  }

  Future<void> _onCalculateRebalance(
    CalculateRebalanceEvent event,
    Emitter<GoalsState> emit,
  ) async {
    final currentState = state;
    if (currentState is! GoalsLoaded) return;

    try {
      final goal =
          currentState.goals.firstWhere((g) => g.id == event.goalId);

      if (goal.targetAllocation == null) {
        emit(currentState.copyWith(rebalanceSuggestions: []));
        return;
      }

      final suggestions = _calculateRebalanceSuggestions(
        portfolio: event.portfolio,
        targetAllocation: goal.targetAllocation!,
      );

      emit(currentState.copyWith(
        rebalanceSuggestions: suggestions,
        selectedGoalId: event.goalId,
      ));
    } catch (e) {
      emit(GoalsError('Failed to calculate rebalance: $e'));
    }
  }

  List<RebalanceSuggestion> _calculateRebalanceSuggestions({
    required Portfolio portfolio,
    required TargetAllocation targetAllocation,
  }) {
    final suggestions = <RebalanceSuggestion>[];
    final totalValue = portfolio.totalValue;

    if (totalValue == 0) return suggestions;

    // Get current allocation by asset type
    final currentAllocation = portfolio.assetTypeAllocation;

    // Calculate suggestions for each target
    for (final entry in targetAllocation.assetTypeTargets.entries) {
      final assetType = entry.key;
      final targetPercent = entry.value;

      final currentValue = currentAllocation[assetType] ?? 0.0;
      final currentPercent =
          totalValue > 0 ? (currentValue / totalValue * 100) : 0.0;

      final deviation = currentPercent - targetPercent;

      // Only suggest if deviation exceeds threshold
      if (deviation.abs() > targetAllocation.rebalanceThreshold) {
        final targetValue = totalValue * targetPercent / 100;
        final adjustmentAmount = (targetValue - currentValue).abs();

        suggestions.add(RebalanceSuggestion(
          assetType: assetType,
          currentAllocation: currentPercent,
          targetAllocation: targetPercent,
          deviation: deviation,
          action: deviation > 0 ? RebalanceAction.sell : RebalanceAction.buy,
          suggestedAmount: adjustmentAmount,
          currency: portfolio.baseCurrency,
        ));
      } else {
        suggestions.add(RebalanceSuggestion(
          assetType: assetType,
          currentAllocation: currentPercent,
          targetAllocation: targetPercent,
          deviation: deviation,
          action: RebalanceAction.hold,
          suggestedAmount: 0.0,
          currency: portfolio.baseCurrency,
        ));
      }
    }

    // Sort by deviation magnitude
    suggestions.sort((a, b) => b.deviation.abs().compareTo(a.deviation.abs()));

    return suggestions;
  }
}