import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:portfolio_manager/features/goals/domain/entities/goals_entities.dart';
import 'package:portfolio_manager/features/goals/presentation/bloc/goals_bloc.dart';
import 'package:portfolio_manager/features/portfolio/domain/entities/portfolio_entities.dart';
import 'package:portfolio_manager/services/storage/local_storage_service.dart';

class _MockLocalStorageService extends Mock implements LocalStorageService {}

InvestmentGoal _goal({
  required String id,
  required GoalType type,
  required String currency,
  GoalStatus status = GoalStatus.active,
  double currentAmount = 0,
  double targetAmount = 100000,
}) {
  return InvestmentGoal(
    id: id,
    name: 'Goal $id',
    type: type,
    status: status,
    targetAmount: targetAmount,
    currentAmount: currentAmount,
    currency: currency,
    createdAt: DateTime(2026, 1, 1),
  );
}

Portfolio _portfolio({required String baseCurrency, required double value}) {
  return Portfolio(
    id: 'p',
    accountId: 'acc',
    accountName: 'Test',
    baseCurrency: baseCurrency,
    broker: 'test',
    positions: [
      Position(
        id: 'pos-1',
        symbol: 'AAPL',
        name: 'Apple',
        assetType: 'Stocks',
        sector: 'Technology',
        currency: baseCurrency,
        quantity: 1,
        closePrice: value,
        value: value,
        costBasis: value / 2,
        unrealizedPnL: value / 2,
      ),
    ],
  );
}

void main() {
  late _MockLocalStorageService storage;

  setUpAll(() {
    registerFallbackValue(<InvestmentGoal>[]);
  });

  setUp(() {
    storage = _MockLocalStorageService();
    when(() => storage.saveGoals(any())).thenAnswer((_) async {});
  });

  group('GoalsBloc SyncWithPortfolio', () {
    blocTest<GoalsBloc, GoalsState>(
      'updates retirement goal with matching currency',
      build: () => GoalsBloc(storageService: storage),
      seed: () => GoalsLoaded(goals: [
        _goal(id: 'r1', type: GoalType.retirement, currency: 'EUR'),
      ]),
      act: (bloc) => bloc.add(SyncWithPortfolioEvent(
        portfolio: _portfolio(baseCurrency: 'EUR', value: 50000),
      )),
      verify: (bloc) {
        final state = bloc.state as GoalsLoaded;
        expect(state.goals.first.currentAmount, 50000);
      },
    );

    blocTest<GoalsBloc, GoalsState>(
      'does not update emergency goal even if currency matches',
      build: () => GoalsBloc(storageService: storage),
      seed: () => GoalsLoaded(goals: [
        _goal(id: 'e1', type: GoalType.emergency, currency: 'EUR', currentAmount: 1000),
      ]),
      act: (bloc) => bloc.add(SyncWithPortfolioEvent(
        portfolio: _portfolio(baseCurrency: 'EUR', value: 50000),
      )),
      verify: (bloc) {
        final state = bloc.state as GoalsLoaded;
        expect(state.goals.first.currentAmount, 1000);
      },
    );

    blocTest<GoalsBloc, GoalsState>(
      'skips retirement goal when currency mismatch (no FX conversion)',
      build: () => GoalsBloc(storageService: storage),
      seed: () => GoalsLoaded(goals: [
        _goal(id: 'r2', type: GoalType.retirement, currency: 'USD', currentAmount: 2000),
      ]),
      act: (bloc) => bloc.add(SyncWithPortfolioEvent(
        portfolio: _portfolio(baseCurrency: 'EUR', value: 50000),
      )),
      verify: (bloc) {
        final state = bloc.state as GoalsLoaded;
        expect(state.goals.first.currentAmount, 2000);
      },
    );

    blocTest<GoalsBloc, GoalsState>(
      'marks retirement goal completed when current amount exceeds target',
      build: () => GoalsBloc(storageService: storage),
      seed: () => GoalsLoaded(goals: [
        _goal(
          id: 'r3',
          type: GoalType.retirement,
          currency: 'EUR',
          targetAmount: 10000,
        ),
      ]),
      act: (bloc) => bloc.add(SyncWithPortfolioEvent(
        portfolio: _portfolio(baseCurrency: 'EUR', value: 15000),
      )),
      verify: (bloc) {
        final state = bloc.state as GoalsLoaded;
        expect(state.goals.first.status, GoalStatus.completed);
        expect(state.goals.first.completedAt, isNotNull);
      },
    );

    blocTest<GoalsBloc, GoalsState>(
      'ignores inactive goals (paused/completed/cancelled)',
      build: () => GoalsBloc(storageService: storage),
      seed: () => GoalsLoaded(goals: [
        _goal(
          id: 'p1',
          type: GoalType.retirement,
          currency: 'EUR',
          status: GoalStatus.paused,
          currentAmount: 3000,
        ),
      ]),
      act: (bloc) => bloc.add(SyncWithPortfolioEvent(
        portfolio: _portfolio(baseCurrency: 'EUR', value: 50000),
      )),
      verify: (bloc) {
        final state = bloc.state as GoalsLoaded;
        expect(state.goals.first.currentAmount, 3000);
      },
    );
  });
}
