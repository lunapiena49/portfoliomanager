import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../services/storage/local_storage_service.dart';
import '../../domain/entities/rebalancing_entities.dart';
import '../../../portfolio/domain/entities/portfolio_entities.dart';

// Events
abstract class RebalancingEvent extends Equatable {
  const RebalancingEvent();

  @override
  List<Object?> get props => [];
}

class LoadRebalancingEvent extends RebalancingEvent {
  final Portfolio portfolio;

  const LoadRebalancingEvent({required this.portfolio});

  @override
  List<Object?> get props => [portfolio];
}

class UpdateTargetPercentEvent extends RebalancingEvent {
  final String positionId;
  final double targetPercent;

  const UpdateTargetPercentEvent({
    required this.positionId,
    required this.targetPercent,
  });

  @override
  List<Object?> get props => [positionId, targetPercent];
}

class ResetTargetsEvent extends RebalancingEvent {}

class SaveTargetsEvent extends RebalancingEvent {}

class SetTargetsFromCurrentEvent extends RebalancingEvent {}

// States
abstract class RebalancingState extends Equatable {
  const RebalancingState();

  @override
  List<Object?> get props => [];
}

class RebalancingInitial extends RebalancingState {}

class RebalancingLoading extends RebalancingState {}

class RebalancingLoaded extends RebalancingState {
  final List<RebalanceTarget> targets;
  final List<RebalanceResult> results;
  final double totalTargetPercent;
  final double totalPortfolioValue;
  final String baseCurrency;
  final bool isSaved;

  const RebalancingLoaded({
    required this.targets,
    required this.results,
    required this.totalTargetPercent,
    required this.totalPortfolioValue,
    required this.baseCurrency,
    this.isSaved = false,
  });

  bool get isValid => (totalTargetPercent - 100.0).abs() < 0.01;

  bool get isBalanced =>
      results.every((r) => r.isAtTarget) && isValid;

  @override
  List<Object?> get props => [
        targets,
        results,
        totalTargetPercent,
        totalPortfolioValue,
        baseCurrency,
        isSaved,
      ];

  RebalancingLoaded copyWith({
    List<RebalanceTarget>? targets,
    List<RebalanceResult>? results,
    double? totalTargetPercent,
    double? totalPortfolioValue,
    String? baseCurrency,
    bool? isSaved,
  }) {
    return RebalancingLoaded(
      targets: targets ?? this.targets,
      results: results ?? this.results,
      totalTargetPercent: totalTargetPercent ?? this.totalTargetPercent,
      totalPortfolioValue: totalPortfolioValue ?? this.totalPortfolioValue,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      isSaved: isSaved ?? this.isSaved,
    );
  }
}

class RebalancingError extends RebalancingState {
  final String message;

  const RebalancingError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class RebalancingBloc extends Bloc<RebalancingEvent, RebalancingState> {
  final LocalStorageService _storageService;
  Portfolio? _currentPortfolio;

  RebalancingBloc({required LocalStorageService storageService})
      : _storageService = storageService,
        super(RebalancingInitial()) {
    on<LoadRebalancingEvent>(_onLoad);
    on<UpdateTargetPercentEvent>(_onUpdateTarget);
    on<ResetTargetsEvent>(_onReset);
    on<SaveTargetsEvent>(_onSave);
    on<SetTargetsFromCurrentEvent>(_onSetFromCurrent);
  }

  Future<void> _onLoad(
    LoadRebalancingEvent event,
    Emitter<RebalancingState> emit,
  ) async {
    emit(RebalancingLoading());

    try {
      _currentPortfolio = event.portfolio;
      final portfolio = event.portfolio;
      final totalValue = portfolio.totalValue;

      // Load saved targets
      final savedTargets = await _storageService.getRebalanceTargets();

      // Build targets list from current positions
      final targets = <RebalanceTarget>[];
      for (final position in portfolio.positions) {
        final saved = savedTargets.firstWhere(
          (t) => t.positionId == position.id,
          orElse: () => RebalanceTarget(
            positionId: position.id,
            symbol: position.symbol,
            name: position.name,
            targetPercent: totalValue > 0
                ? (position.valueInBaseCurrency / totalValue * 100)
                : 0.0,
          ),
        );
        // Always update symbol/name from current portfolio
        targets.add(saved.copyWith(
          symbol: position.symbol,
          name: position.name,
        ));
      }

      final results = _calculateResults(portfolio, targets);
      final totalTarget =
          targets.fold<double>(0, (sum, t) => sum + t.targetPercent);

      emit(RebalancingLoaded(
        targets: targets,
        results: results,
        totalTargetPercent: totalTarget,
        totalPortfolioValue: totalValue,
        baseCurrency: portfolio.baseCurrency,
      ));
    } catch (e) {
      emit(RebalancingError('Failed to load rebalancing data: $e'));
    }
  }

  Future<void> _onUpdateTarget(
    UpdateTargetPercentEvent event,
    Emitter<RebalancingState> emit,
  ) async {
    final currentState = state;
    if (currentState is! RebalancingLoaded || _currentPortfolio == null) return;

    final updatedTargets = currentState.targets.map((t) {
      if (t.positionId == event.positionId) {
        return t.copyWith(targetPercent: event.targetPercent);
      }
      return t;
    }).toList();

    final totalTarget =
        updatedTargets.fold<double>(0, (sum, t) => sum + t.targetPercent);
    final results = _calculateResults(_currentPortfolio!, updatedTargets);

    emit(currentState.copyWith(
      targets: updatedTargets,
      results: results,
      totalTargetPercent: totalTarget,
      isSaved: false,
    ));
  }

  Future<void> _onReset(
    ResetTargetsEvent event,
    Emitter<RebalancingState> emit,
  ) async {
    if (_currentPortfolio == null) return;
    add(LoadRebalancingEvent(portfolio: _currentPortfolio!));
  }

  Future<void> _onSetFromCurrent(
    SetTargetsFromCurrentEvent event,
    Emitter<RebalancingState> emit,
  ) async {
    final currentState = state;
    if (currentState is! RebalancingLoaded || _currentPortfolio == null) return;

    final portfolio = _currentPortfolio!;
    final totalValue = portfolio.totalValue;

    final targets = portfolio.positions.map((position) {
      final currentPercent = totalValue > 0
          ? (position.valueInBaseCurrency / totalValue * 100)
          : 0.0;
      return RebalanceTarget(
        positionId: position.id,
        symbol: position.symbol,
        name: position.name,
        targetPercent: double.parse(currentPercent.toStringAsFixed(2)),
      );
    }).toList();

    final totalTarget =
        targets.fold<double>(0, (sum, t) => sum + t.targetPercent);
    final results = _calculateResults(portfolio, targets);

    emit(currentState.copyWith(
      targets: targets,
      results: results,
      totalTargetPercent: totalTarget,
      isSaved: false,
    ));
  }

  Future<void> _onSave(
    SaveTargetsEvent event,
    Emitter<RebalancingState> emit,
  ) async {
    final currentState = state;
    if (currentState is! RebalancingLoaded) return;

    try {
      await _storageService.saveRebalanceTargets(currentState.targets);
      emit(currentState.copyWith(isSaved: true));
    } catch (e) {
      emit(RebalancingError('Failed to save targets: $e'));
    }
  }

  List<RebalanceResult> _calculateResults(
    Portfolio portfolio,
    List<RebalanceTarget> targets,
  ) {
    final totalValue = portfolio.totalValue;
    final results = <RebalanceResult>[];

    for (final target in targets) {
      final position = portfolio.positions.firstWhere(
        (p) => p.id == target.positionId,
        orElse: () => Position(
          id: target.positionId,
          symbol: target.symbol,
          name: target.name,
          assetType: '',
          sector: '',
          currency: portfolio.baseCurrency,
          quantity: 0,
          closePrice: 0,
          value: 0,
          costBasis: 0,
          unrealizedPnL: 0,
        ),
      );

      final currentValue = position.valueInBaseCurrency;
      final currentPercent =
          totalValue > 0 ? (currentValue / totalValue * 100) : 0.0;
      final targetValue = totalValue * target.targetPercent / 100;
      final deltaPercent = target.targetPercent - currentPercent;
      final deltaValue = targetValue - currentValue;

      results.add(RebalanceResult(
        positionId: target.positionId,
        symbol: target.symbol,
        name: target.name,
        currentPercent: currentPercent,
        targetPercent: target.targetPercent,
        deltaPercent: deltaPercent,
        currentValue: currentValue,
        targetValue: targetValue,
        deltaValue: deltaValue,
        currency: portfolio.baseCurrency,
      ));
    }

    // Sort by absolute delta descending
    results.sort(
        (a, b) => b.deltaPercent.abs().compareTo(a.deltaPercent.abs()));

    return results;
  }
}
