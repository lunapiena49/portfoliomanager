import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../portfolio/domain/entities/portfolio_entities.dart';
import '../../../../services/api/gemini_service.dart';
import '../../domain/analysis_preset.dart';

// ==================== EVENTS ====================

abstract class AnalysisEvent extends Equatable {
  const AnalysisEvent();

  @override
  List<Object?> get props => [];
}

class UpdateAnalysisApiKeyEvent extends AnalysisEvent {
  final String? apiKey;

  const UpdateAnalysisApiKeyEvent(this.apiKey);

  @override
  List<Object?> get props => [apiKey];
}

class GenerateAnalysisEvent extends AnalysisEvent {
  final Portfolio portfolio;
  final String language;
  final String? customPrompt;
  final AnalysisPreset preset;

  /// When non-null, overrides the slice set required by [preset]. The UI uses
  /// this to honor the user's per-slice opt-out toggles in the transparency
  /// panel.
  final Set<AnalysisDataSlice>? slices;

  const GenerateAnalysisEvent({
    required this.portfolio,
    required this.language,
    this.customPrompt,
    this.preset = AnalysisPreset.fullReview,
    this.slices,
  });

  @override
  List<Object?> get props => [portfolio, language, customPrompt, preset, slices];
}

class ClearAnalysisEvent extends AnalysisEvent {}

// ==================== STATES ====================

abstract class AnalysisState extends Equatable {
  const AnalysisState();

  @override
  List<Object?> get props => [];
}

class AnalysisInitial extends AnalysisState {}

class AnalysisInProgress extends AnalysisState {}

class AnalysisSuccess extends AnalysisState {
  final String result;

  const AnalysisSuccess(this.result);

  @override
  List<Object?> get props => [result];
}

class AnalysisFailure extends AnalysisState {
  final String message;

  const AnalysisFailure(this.message);

  @override
  List<Object?> get props => [message];
}

// ==================== BLOC ====================

class AnalysisBloc extends Bloc<AnalysisEvent, AnalysisState> {
  final GeminiService _geminiService;

  AnalysisBloc({GeminiService? geminiService})
      : _geminiService = geminiService ?? GeminiService(),
        super(AnalysisInitial()) {
    on<UpdateAnalysisApiKeyEvent>(_onUpdateApiKey);
    on<GenerateAnalysisEvent>(_onGenerate);
    on<ClearAnalysisEvent>(_onClear);
  }

  void _onUpdateApiKey(
    UpdateAnalysisApiKeyEvent event,
    Emitter<AnalysisState> emit,
  ) {
    _geminiService.setApiKey(event.apiKey);
  }

  Future<void> _onGenerate(
    GenerateAnalysisEvent event,
    Emitter<AnalysisState> emit,
  ) async {
    if (state is AnalysisInProgress) return;

    if (!_geminiService.hasApiKey) {
      emit(const AnalysisFailure('analysis.api_key_required'));
      return;
    }

    emit(AnalysisInProgress());

    try {
      final result = await _geminiService.analyzePortfolio(
        portfolio: event.portfolio,
        customPrompt: event.customPrompt,
        language: event.language,
        preset: event.preset,
        slices: event.slices,
      );
      emit(AnalysisSuccess(result));
    } catch (e) {
      emit(AnalysisFailure(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  void _onClear(
    ClearAnalysisEvent event,
    Emitter<AnalysisState> emit,
  ) {
    emit(AnalysisInitial());
  }
}
