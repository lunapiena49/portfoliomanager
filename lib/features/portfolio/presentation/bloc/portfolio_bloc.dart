import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/portfolio_entities.dart';
import '../../../../services/storage/local_storage_service.dart';
import '../../../../services/parsers/base_parser.dart';
import '../../../../services/parsers/parser_factory.dart';
import '../../../../services/parsers/pdf_import_parser.dart';
import '../../../../services/parsers/generic_parser.dart';

// ==================== EVENTS ====================

abstract class PortfolioEvent extends Equatable {
  const PortfolioEvent();

  @override
  List<Object?> get props => [];
}

class LoadPortfolioEvent extends PortfolioEvent {}

// [UPDATED] Merge strategy for import conflicts
enum PositionMergeStrategy { add, replace, ignore }

class ImportFileData extends Equatable {
  final String name;
  final String extension;
  final Uint8List bytes;

  const ImportFileData({
    required this.name,
    required this.extension,
    required this.bytes,
  });

  @override
  List<Object?> get props => [name, extension, bytes];
}

class CreatePortfolioFromImportEvent extends PortfolioEvent {
  final List<ImportFileData> files;
  final String broker;
  final String portfolioName;
  final PositionMergeStrategy mergeStrategy;

  const CreatePortfolioFromImportEvent({
    required this.files,
    required this.broker,
    required this.portfolioName,
    this.mergeStrategy = PositionMergeStrategy.add,
  });

  @override
  List<Object?> get props => [files, broker, portfolioName, mergeStrategy];
}

// [UPDATED] Add positions from import into an existing portfolio
class AddPositionsFromImportEvent extends PortfolioEvent {
  final List<ImportFileData> files;
  final String broker;
  final String portfolioId;
  final PositionMergeStrategy mergeStrategy;

  const AddPositionsFromImportEvent({
    required this.files,
    required this.broker,
    required this.portfolioId,
    this.mergeStrategy = PositionMergeStrategy.add,
  });

  @override
  List<Object?> get props => [files, broker, portfolioId, mergeStrategy];
}

class UpdatePortfolioEvent extends PortfolioEvent {
  final Portfolio portfolio;

  const UpdatePortfolioEvent(this.portfolio);

  @override
  List<Object?> get props => [portfolio];
}

class DeletePortfolioEvent extends PortfolioEvent {
  final String portfolioId;

  const DeletePortfolioEvent(this.portfolioId);

  @override
  List<Object?> get props => [portfolioId];
}

class CreatePortfolioEvent extends PortfolioEvent {
  final String name;

  const CreatePortfolioEvent(this.name);

  @override
  List<Object?> get props => [name];
}

class RenamePortfolioEvent extends PortfolioEvent {
  final String portfolioId;
  final String name;

  const RenamePortfolioEvent({
    required this.portfolioId,
    required this.name,
  });

  @override
  List<Object?> get props => [portfolioId, name];
}

class SelectPortfolioEvent extends PortfolioEvent {
  final String portfolioId;

  const SelectPortfolioEvent(this.portfolioId);

  @override
  List<Object?> get props => [portfolioId];
}

class AddPositionEvent extends PortfolioEvent {
  final Position position;

  const AddPositionEvent(this.position);

  @override
  List<Object?> get props => [position];
}

class UpdatePositionEvent extends PortfolioEvent {
  final Position position;

  const UpdatePositionEvent(this.position);

  @override
  List<Object?> get props => [position];
}

class DeletePositionEvent extends PortfolioEvent {
  final String positionId;

  const DeletePositionEvent(this.positionId);

  @override
  List<Object?> get props => [positionId];
}

class FilterPositionsEvent extends PortfolioEvent {
  final String? assetType;
  final String? sector;
  final String? currency;

  const FilterPositionsEvent({
    this.assetType,
    this.sector,
    this.currency,
  });

  @override
  List<Object?> get props => [assetType, sector, currency];
}

class SortPositionsEvent extends PortfolioEvent {
  final String sortBy;
  final bool ascending;

  const SortPositionsEvent({
    required this.sortBy,
    this.ascending = false,
  });

  @override
  List<Object?> get props => [sortBy, ascending];
}

// ==================== STATES ====================

abstract class PortfolioState extends Equatable {
  const PortfolioState();

  @override
  List<Object?> get props => [];
}

class PortfolioInitial extends PortfolioState {}

class PortfolioLoading extends PortfolioState {}

class PortfolioEmpty extends PortfolioState {}

class PortfolioLoaded extends PortfolioState {
  static const Object _filterAssetTypeUnset = Object();
  static const Object _filterSectorUnset = Object();
  static const Object _filterCurrencyUnset = Object();

  final Portfolio portfolio;
  final List<Portfolio> allPortfolios;
  final List<Position> filteredPositions;
  final String? filterAssetType;
  final String? filterSector;
  final String? filterCurrency;
  final String sortBy;
  final bool sortAscending;

  const PortfolioLoaded({
    required this.portfolio,
    this.allPortfolios = const [],
    List<Position>? filteredPositions,
    this.filterAssetType,
    this.filterSector,
    this.filterCurrency,
    this.sortBy = 'value',
    this.sortAscending = false,
  }) : filteredPositions = filteredPositions ?? const [];

  @override
  List<Object?> get props => [
        portfolio,
        allPortfolios,
        filteredPositions,
        filterAssetType,
        filterSector,
        filterCurrency,
        sortBy,
        sortAscending,
      ];

  PortfolioLoaded copyWith({
    Portfolio? portfolio,
    List<Portfolio>? allPortfolios,
    List<Position>? filteredPositions,
    Object? filterAssetType = _filterAssetTypeUnset,
    Object? filterSector = _filterSectorUnset,
    Object? filterCurrency = _filterCurrencyUnset,
    String? sortBy,
    bool? sortAscending,
  }) {
    return PortfolioLoaded(
      portfolio: portfolio ?? this.portfolio,
      allPortfolios: allPortfolios ?? this.allPortfolios,
      filteredPositions: filteredPositions ?? this.filteredPositions,
      filterAssetType: filterAssetType == _filterAssetTypeUnset
          ? this.filterAssetType
          : filterAssetType as String?,
      filterSector: filterSector == _filterSectorUnset
          ? this.filterSector
          : filterSector as String?,
      filterCurrency: filterCurrency == _filterCurrencyUnset
          ? this.filterCurrency
          : filterCurrency as String?,
      sortBy: sortBy ?? this.sortBy,
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }
}

class PortfolioImporting extends PortfolioState {}

class PortfolioImportSuccess extends PortfolioState {
  final Portfolio portfolio;

  const PortfolioImportSuccess(this.portfolio);

  @override
  List<Object?> get props => [portfolio];
}

class PortfolioError extends PortfolioState {
  final String message;

  const PortfolioError(this.message);

  @override
  List<Object?> get props => [message];
}

// ==================== BLOC ====================

class PortfolioBloc extends Bloc<PortfolioEvent, PortfolioState> {
  PortfolioBloc() : super(PortfolioInitial()) {
    on<LoadPortfolioEvent>(_onLoadPortfolio);
    on<CreatePortfolioFromImportEvent>(_onCreatePortfolioFromImport);
    on<AddPositionsFromImportEvent>(_onAddPositionsFromImport);
    on<UpdatePortfolioEvent>(_onUpdatePortfolio);
    on<DeletePortfolioEvent>(_onDeletePortfolio);
    on<CreatePortfolioEvent>(_onCreatePortfolio);
    on<RenamePortfolioEvent>(_onRenamePortfolio);
    on<SelectPortfolioEvent>(_onSelectPortfolio);
    on<AddPositionEvent>(_onAddPosition);
    on<UpdatePositionEvent>(_onUpdatePosition);
    on<DeletePositionEvent>(_onDeletePosition);
    on<FilterPositionsEvent>(_onFilterPositions);
    on<SortPositionsEvent>(_onSortPositions);
  }

  Future<void> _onLoadPortfolio(
    LoadPortfolioEvent event,
    Emitter<PortfolioState> emit,
  ) async {
    emit(PortfolioLoading());

    try {
      final portfolio = LocalStorageService.getCurrentPortfolio();
      final allPortfolios = LocalStorageService.getAllPortfolios();

      if (portfolio == null) {
        emit(PortfolioEmpty());
      } else {
        final consolidatedPortfolio = _consolidatePortfolio(portfolio);
        final storedFilter = _normalizeMacroFilter(
          LocalStorageService.getPositionsFilterAssetType(),
        );
        emit(PortfolioLoaded(
          portfolio: consolidatedPortfolio,
          allPortfolios: allPortfolios,
          filterAssetType: storedFilter,
          filteredPositions: _applyFiltersAndSort(
            consolidatedPortfolio.positions,
            storedFilter,
            null,
            null,
            'value',
            false,
          ),
        ));
      }
    } catch (e) {
      emit(PortfolioError(e.toString()));
    }
  }

  Future<void> _onCreatePortfolioFromImport(
    CreatePortfolioFromImportEvent event,
    Emitter<PortfolioState> emit,
  ) async {
    emit(PortfolioImporting());

    try {
      final parsedImport = _parseImportFiles(
        event.files,
        event.broker,
        event.mergeStrategy,
      );
      var portfolio = parsedImport.portfolio;
      if (event.portfolioName.trim().isNotEmpty) {
        portfolio = portfolio.copyWith(accountName: event.portfolioName.trim());
      }

      portfolio = portfolio.copyWith(
        importSources: [...portfolio.importSources, ...parsedImport.sources],
      );

      final consolidatedPortfolio = _consolidatePortfolio(portfolio);
      final storedFilter = _normalizeMacroFilter(
        LocalStorageService.getPositionsFilterAssetType(),
      );

      await LocalStorageService.savePortfolio(consolidatedPortfolio);
      final allPortfolios = LocalStorageService.getAllPortfolios();

      emit(PortfolioImportSuccess(consolidatedPortfolio));
      emit(PortfolioLoaded(
        portfolio: consolidatedPortfolio,
        allPortfolios: allPortfolios,
        filterAssetType: storedFilter,
        filteredPositions: _applyFiltersAndSort(
          consolidatedPortfolio.positions,
          storedFilter,
          null,
          null,
          'value',
          false,
        ),
      ));
    } catch (e) {
      emit(PortfolioError('Failed to import portfolio: ${e.toString()}'));
    }
  }

  Future<void> _onAddPositionsFromImport(
    AddPositionsFromImportEvent event,
    Emitter<PortfolioState> emit,
  ) async {
    emit(PortfolioImporting());

    try {
      final previousState = state;
      final allPortfolios = LocalStorageService.getAllPortfolios();
      final targetIndex = allPortfolios.indexWhere((p) => p.id == event.portfolioId);

      if (targetIndex == -1) {
        emit(const PortfolioError('errors.storage_error'));
        return;
      }

      final targetPortfolio = allPortfolios[targetIndex];
      final parsedImport = _parseImportFiles(
        event.files,
        event.broker,
        event.mergeStrategy,
      );
      final importedPortfolio = parsedImport.portfolio;

      final mergedPositions = _mergePositions(
        BaseBrokerParser.normalizeAndDeduplicatePositions(targetPortfolio.positions),
        importedPortfolio.positions,
        event.mergeStrategy,
      );

      final updatedPortfolio = targetPortfolio.copyWith(
        positions: mergedPositions,
        importSources: [...targetPortfolio.importSources, ...parsedImport.sources],
        lastUpdated: DateTime.now(),
      );

      final isCurrent = state is PortfolioLoaded &&
          (state as PortfolioLoaded).portfolio.id == updatedPortfolio.id;

      await LocalStorageService.savePortfolio(
        updatedPortfolio,
        setCurrent: isCurrent,
      );

      final refreshedPortfolios = LocalStorageService.getAllPortfolios();

      emit(PortfolioImportSuccess(updatedPortfolio));

      if (previousState is PortfolioLoaded) {
        final currentState = previousState;
        emit(currentState.copyWith(
          portfolio: isCurrent ? updatedPortfolio : currentState.portfolio,
          allPortfolios: refreshedPortfolios,
          filteredPositions: isCurrent
              ? _applyFiltersAndSort(
                  updatedPortfolio.positions,
                  currentState.filterAssetType,
                  currentState.filterSector,
                  currentState.filterCurrency,
                  currentState.sortBy,
                  currentState.sortAscending,
                )
              : currentState.filteredPositions,
        ));
      }
    } catch (e) {
      emit(PortfolioError('Failed to import positions: ${e.toString()}'));
    }
  }

  Future<void> _onUpdatePortfolio(
    UpdatePortfolioEvent event,
    Emitter<PortfolioState> emit,
  ) async {
    try {
      final consolidatedPortfolio = _consolidatePortfolio(event.portfolio);
      await LocalStorageService.savePortfolio(consolidatedPortfolio);
      final allPortfolios = LocalStorageService.getAllPortfolios();

      if (state is PortfolioLoaded) {
        final currentState = state as PortfolioLoaded;
        emit(currentState.copyWith(
          portfolio: consolidatedPortfolio,
          allPortfolios: allPortfolios,
          filteredPositions: _applyFiltersAndSort(
            consolidatedPortfolio.positions,
            currentState.filterAssetType,
            currentState.filterSector,
            currentState.filterCurrency,
            currentState.sortBy,
            currentState.sortAscending,
          ),
        ));
      }
    } catch (e) {
      emit(PortfolioError(e.toString()));
    }
  }

  Future<void> _onDeletePortfolio(
    DeletePortfolioEvent event,
    Emitter<PortfolioState> emit,
  ) async {
    try {
      await LocalStorageService.deletePortfolio(event.portfolioId);
      add(LoadPortfolioEvent());
    } catch (e) {
      emit(PortfolioError(e.toString()));
    }
  }

  Future<void> _onSelectPortfolio(
    SelectPortfolioEvent event,
    Emitter<PortfolioState> emit,
  ) async {
    if (state is PortfolioLoaded) {
      final currentState = state as PortfolioLoaded;
      final portfolio = currentState.allPortfolios.firstWhere(
        (p) => p.id == event.portfolioId,
        orElse: () => currentState.portfolio,
      );

      final consolidatedPortfolio = _consolidatePortfolio(portfolio);

      await LocalStorageService.savePortfolio(consolidatedPortfolio);

      emit(currentState.copyWith(
        portfolio: consolidatedPortfolio,
        filteredPositions: _applyFiltersAndSort(
          consolidatedPortfolio.positions,
          currentState.filterAssetType,
          currentState.filterSector,
          currentState.filterCurrency,
          currentState.sortBy,
          currentState.sortAscending,
        ),
      ));
    }
  }

  List<Position> _consolidatePositions(List<Position> positions) {
    return BaseBrokerParser.normalizeAndDeduplicatePositions(positions);
  }

  Portfolio _consolidatePortfolio(Portfolio portfolio) {
    return portfolio.copyWith(
      positions: _consolidatePositions(portfolio.positions),
    );
  }

  String? _normalizeMacroFilter(String? assetType) {
    if (assetType == null) return null;
    final normalized = assetType.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    if (normalized.contains('stock') || normalized.contains('equity')) return 'stocks';
    if (normalized.contains('bond') || normalized.contains('fixed')) return 'bonds';
    if (normalized.contains('commod')) return 'commodities';
    if (normalized.contains('crypto')) return 'crypto';
    if (normalized.contains('cash') || normalized.contains('forex')) return 'cash';
    if (normalized == 'unassigned') return 'unassigned';

    return 'unassigned';
  }


  Future<void> _onCreatePortfolio(
    CreatePortfolioEvent event,
    Emitter<PortfolioState> emit,
  ) async {
    emit(PortfolioLoading());

    try {
      final baseCurrency = LocalStorageService.getBaseCurrency();
      final uuid = const Uuid();
      final now = DateTime.now();

      final newPortfolio = Portfolio(
        id: uuid.v4(),
        accountId: 'manual_${uuid.v4().substring(0, 8)}',
        accountName: event.name.trim(),
        baseCurrency: baseCurrency,
        broker: 'Manual',
        positions: const [],
        lastUpdated: now,
        importedAt: now,
      );

      await LocalStorageService.savePortfolio(newPortfolio, setCurrent: true);
      final allPortfolios = LocalStorageService.getAllPortfolios();
      final storedFilter = _normalizeMacroFilter(
        LocalStorageService.getPositionsFilterAssetType(),
      );

      emit(PortfolioLoaded(
        portfolio: newPortfolio,
        allPortfolios: allPortfolios,
        filterAssetType: storedFilter,
        filteredPositions: _applyFiltersAndSort(
          newPortfolio.positions,
          storedFilter,
          null,
          null,
          'value',
          false,
        ),
      ));
    } catch (e) {
      emit(PortfolioError('errors.storage_error'));
    }
  }

  Future<void> _onRenamePortfolio(
    RenamePortfolioEvent event,
    Emitter<PortfolioState> emit,
  ) async {
    try {
      final allPortfolios = LocalStorageService.getAllPortfolios();
      final target = allPortfolios.firstWhere(
        (p) => p.id == event.portfolioId,
        orElse: () => Portfolio.empty(),
      );

      if (target.id.isEmpty) {
        emit(PortfolioError('errors.storage_error'));
        return;
      }

      final updatedPortfolio = target.copyWith(
        accountName: event.name.trim(),
        lastUpdated: DateTime.now(),
      );

      final isCurrent = state is PortfolioLoaded &&
          (state as PortfolioLoaded).portfolio.id == updatedPortfolio.id;

      await LocalStorageService.savePortfolio(
        updatedPortfolio,
        setCurrent: isCurrent,
      );

      final refreshedPortfolios = LocalStorageService.getAllPortfolios();

      if (state is PortfolioLoaded) {
        final currentState = state as PortfolioLoaded;
        emit(currentState.copyWith(
          portfolio: isCurrent ? updatedPortfolio : currentState.portfolio,
          allPortfolios: refreshedPortfolios,
        ));
      }
    } catch (e) {
      emit(PortfolioError('errors.storage_error'));
    }
  }
  Future<void> _onAddPosition(
    AddPositionEvent event,
    Emitter<PortfolioState> emit,
  ) async {
    try {
      if (state is PortfolioLoaded) {
        // Add position to existing portfolio
        final currentState = state as PortfolioLoaded;
        final updatedPositions = _consolidatePositions(
          [...currentState.portfolio.positions, event.position],
        );
        final updatedPortfolio = currentState.portfolio.copyWith(
          positions: updatedPositions,
          lastUpdated: DateTime.now(),
        );

        add(UpdatePortfolioEvent(updatedPortfolio));
      }
    } catch (e) {
      emit(PortfolioError('Failed to add position: ${e.toString()}'));
    }
  }

  Future<void> _onUpdatePosition(
    UpdatePositionEvent event,
    Emitter<PortfolioState> emit,
  ) async {
    if (state is PortfolioLoaded) {
      final currentState = state as PortfolioLoaded;
      final updatedPositions = _consolidatePositions(
        currentState.portfolio.positions.map((p) {
          return p.id == event.position.id ? event.position : p;
        }).toList(),
      );
      final updatedPortfolio = currentState.portfolio.copyWith(
        positions: updatedPositions,
        lastUpdated: DateTime.now(),
      );

      add(UpdatePortfolioEvent(updatedPortfolio));
    }
  }

  Future<void> _onDeletePosition(
    DeletePositionEvent event,
    Emitter<PortfolioState> emit,
  ) async {
    if (state is PortfolioLoaded) {
      final currentState = state as PortfolioLoaded;
      final updatedPositions = currentState.portfolio.positions
          .where((p) => p.id != event.positionId)
          .toList();
      final updatedPortfolio = currentState.portfolio.copyWith(
        positions: updatedPositions,
        lastUpdated: DateTime.now(),
      );

      add(UpdatePortfolioEvent(updatedPortfolio));
    }
  }

  Future<void> _onFilterPositions(
    FilterPositionsEvent event,
    Emitter<PortfolioState> emit,
  ) async {
    if (state is PortfolioLoaded) {
      final currentState = state as PortfolioLoaded;
      final normalizedAssetType = _normalizeMacroFilter(event.assetType);
      await LocalStorageService.setPositionsFilterAssetType(normalizedAssetType);
      emit(currentState.copyWith(
        filterAssetType: normalizedAssetType,
        filterSector: event.sector,
        filterCurrency: event.currency,
        filteredPositions: _applyFiltersAndSort(
          currentState.portfolio.positions,
          normalizedAssetType,
          event.sector,
          event.currency,
          currentState.sortBy,
          currentState.sortAscending,
        ),
      ));
    }
  }

  void _onSortPositions(
    SortPositionsEvent event,
    Emitter<PortfolioState> emit,
  ) {
    if (state is PortfolioLoaded) {
      final currentState = state as PortfolioLoaded;
      emit(currentState.copyWith(
        sortBy: event.sortBy,
        sortAscending: event.ascending,
        filteredPositions: _applyFiltersAndSort(
          currentState.portfolio.positions,
          currentState.filterAssetType,
          currentState.filterSector,
          currentState.filterCurrency,
          event.sortBy,
          event.ascending,
        ),
      ));
    }
  }

  List<Position> _applyFiltersAndSort(
    List<Position> positions,
    String? assetType,
    String? sector,
    String? currency,
    String sortBy,
    bool ascending,
  ) {
    final normalizedAssetType = _normalizeMacroFilter(assetType);
    var filtered = positions.where((p) {
      if (normalizedAssetType != null) {
        if (_resolveMacroAssetType(p) != normalizedAssetType) return false;
      }
      if (sector != null && sector.isNotEmpty) {
        if (p.sector.toLowerCase() != sector.toLowerCase()) return false;
      }
      if (currency != null && currency.isNotEmpty) {
        if (p.currency.toUpperCase() != currency.toUpperCase()) return false;
      }
      return true;
    }).toList();

    return _sortPositions(filtered, sortBy, ascending);
  }

  String _resolveMacroAssetType(Position position) {
    final normalized = position.assetType.toLowerCase();
    if (normalized.contains('stock') || normalized.contains('equity')) return 'stocks';
    if (normalized.contains('bond') || normalized.contains('fixed')) return 'bonds';
    if (normalized.contains('commod')) return 'commodities';
    if (normalized.contains('crypto')) return 'crypto';
    if (normalized.contains('cash') || normalized.contains('forex')) return 'cash';
    return 'unassigned';
  }

  // [UPDATED] Parse multi-file imports (CSV/PDF) into a combined portfolio
  _ParsedImport _parseImportFiles(
    List<ImportFileData> files,
    String brokerId,
    PositionMergeStrategy mergeStrategy,
  ) {
    if (files.isEmpty) {
      throw const FormatException('No files provided');
    }

    final importSources = <ImportSource>[];
    Portfolio? basePortfolio;
    var mergedPositions = <Position>[];

    for (final file in files) {
      final parsed = _parseImportFile(file, brokerId);
      final normalizedPositions = BaseBrokerParser.normalizeAndDeduplicatePositions(
        parsed.positions,
      );

      if (basePortfolio == null) {
        basePortfolio = parsed.copyWith(positions: normalizedPositions);
        mergedPositions = normalizedPositions;
      } else {
        mergedPositions = _mergePositions(
          mergedPositions,
          normalizedPositions,
          mergeStrategy,
        );
      }

      importSources.add(ImportSource(
        brokerId: brokerId,
        fileName: file.name,
        importedAt: DateTime.now(),
        positionCount: normalizedPositions.length,
      ));
    }

    if (basePortfolio == null) {
      throw const FormatException('Empty import');
    }

    return _ParsedImport(
      portfolio: basePortfolio.copyWith(positions: mergedPositions),
      sources: importSources,
    );
  }

  Portfolio _parseImportFile(ImportFileData file, String brokerId) {
    final extension = file.extension.toLowerCase();
    if (extension == 'pdf') {
      return PdfImportParser.parse(file.bytes, brokerId: brokerId);
    }

    final content = _decodeFileBytes(file.bytes);
    if (brokerId.trim().isEmpty) {
      return BrokerParserFactory.autoParseCSV(content);
    }

    try {
      return BrokerParserFactory.parseWithBroker(content, brokerId);
    } catch (_) {
      try {
        return BrokerParserFactory.autoParseCSV(content);
      } catch (_) {
        return GenericCSVParser().parse(content);
      }
    }
  }

  String _decodeFileBytes(Uint8List bytes) {
    return utf8.decode(bytes, allowMalformed: true);
  }

  // [UPDATED] Merge positions with conflict strategy
  List<Position> _mergePositions(
    List<Position> existing,
    List<Position> incoming,
    PositionMergeStrategy strategy,
  ) {
    final merged = <String, Position>{};

    for (final position in existing) {
      final key = _buildPositionKey(position);
      merged[key.isEmpty ? BaseBrokerParser.generateId() : key] = position;
    }

    for (final position in incoming) {
      final key = _buildPositionKey(position);
      if (key.isEmpty || !merged.containsKey(key)) {
        merged[key.isEmpty ? BaseBrokerParser.generateId() : key] = position;
        continue;
      }

      final current = merged[key]!;
      switch (strategy) {
        case PositionMergeStrategy.add:
          merged[key] = _mergePositionValues(current, position);
          break;
        case PositionMergeStrategy.replace:
          merged[key] = position.copyWith(id: current.id);
          break;
        case PositionMergeStrategy.ignore:
          merged[key] = current;
          break;
      }
    }

    return merged.values.toList();
  }

  String _buildPositionKey(Position position) {
    final isin = position.isin?.trim().toUpperCase();
    if (isin != null && isin.isNotEmpty) {
      return 'ISIN:$isin';
    }

    final symbol = BaseBrokerParser.normalizeSymbol(position.symbol);
    if (symbol.isEmpty) {
      final name = position.name.trim().toUpperCase();
      return name.isEmpty
          ? ''
          : 'NAME:$name:${position.currency.toUpperCase()}';
    }

    return 'SYM:$symbol:${position.currency.toUpperCase()}';
  }

  Position _mergePositionValues(Position base, Position incoming) {
    final combinedQuantity = base.quantity + incoming.quantity;
    final combinedValue = base.value + incoming.value;
    final combinedCostBasis = base.costBasis + incoming.costBasis;
    final combinedPnL = base.unrealizedPnL + incoming.unrealizedPnL;
    final combinedPrice = combinedQuantity == 0
        ? base.closePrice
        : combinedValue / combinedQuantity;

    return base.copyWith(
      symbol: base.symbol.isNotEmpty ? base.symbol : incoming.symbol,
      name: base.name.isNotEmpty ? base.name : incoming.name,
      assetType: base.assetType.isNotEmpty ? base.assetType : incoming.assetType,
      sector: base.sector.isNotEmpty ? base.sector : incoming.sector,
      currency: base.currency.isNotEmpty ? base.currency : incoming.currency,
      exchange: base.exchange ?? incoming.exchange,
      isin: base.isin ?? incoming.isin,
      quantity: combinedQuantity,
      closePrice: combinedPrice,
      value: combinedValue,
      costBasis: combinedCostBasis,
      unrealizedPnL: combinedPnL,
      fxRateToBase: base.fxRateToBase != 1.0
          ? base.fxRateToBase
          : incoming.fxRateToBase,
      lastUpdated: DateTime.now(),
    );
  }

  List<Position> _sortPositions(
    List<Position> positions,
    String sortBy,
    bool ascending,
  ) {
    final sorted = List<Position>.from(positions);

    sorted.sort((a, b) {
      int comparison;
      switch (sortBy) {
        case 'name':
          comparison = a.name.compareTo(b.name);
          break;
        case 'symbol':
          comparison = a.symbol.compareTo(b.symbol);
          break;
        case 'value':
          comparison = a.valueInBaseCurrency.compareTo(b.valueInBaseCurrency);
          break;
        case 'pnl':
          comparison = a.unrealizedPnLInBaseCurrency.compareTo(b.unrealizedPnLInBaseCurrency);
          break;
        case 'pnl_percent':
          comparison = a.pnlPercent.compareTo(b.pnlPercent);
          break;
        case 'sector':
          comparison = a.sector.compareTo(b.sector);
          break;
        default:
          comparison = a.valueInBaseCurrency.compareTo(b.valueInBaseCurrency);
      }

      return ascending ? comparison : -comparison;
    });

    return sorted;
  }
}

class _ParsedImport {
  final Portfolio portfolio;
  final List<ImportSource> sources;

  const _ParsedImport({
    required this.portfolio,
    required this.sources,
  });
}
