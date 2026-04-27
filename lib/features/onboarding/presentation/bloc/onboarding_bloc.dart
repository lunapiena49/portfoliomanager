import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../services/storage/disclosure_service.dart';
import '../../../../services/storage/local_storage_service.dart';

// ==================== EVENTS ====================

abstract class OnboardingEvent extends Equatable {
  const OnboardingEvent();

  @override
  List<Object?> get props => [];
}

class CheckOnboardingStatusEvent extends OnboardingEvent {}

class CompleteOnboardingEvent extends OnboardingEvent {}

class ResetOnboardingEvent extends OnboardingEvent {}

// ==================== STATES ====================

abstract class OnboardingState extends Equatable {
  const OnboardingState();

  @override
  List<Object?> get props => [];
}

class OnboardingInitial extends OnboardingState {}

class OnboardingLoading extends OnboardingState {}

class OnboardingRequired extends OnboardingState {
  const OnboardingRequired();
}

class OnboardingCompleted extends OnboardingState {}

// ==================== BLOC ====================

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  OnboardingBloc() : super(OnboardingInitial()) {
    on<CheckOnboardingStatusEvent>(_onCheckStatus);
    on<CompleteOnboardingEvent>(_onComplete);
    on<ResetOnboardingEvent>(_onReset);
  }

  Future<void> _onCheckStatus(
    CheckOnboardingStatusEvent event,
    Emitter<OnboardingState> emit,
  ) async {
    emit(OnboardingLoading());

    final isComplete = LocalStorageService.isOnboardingComplete();

    if (isComplete) {
      emit(OnboardingCompleted());
    } else {
      emit(const OnboardingRequired());
    }
  }

  Future<void> _onComplete(
    CompleteOnboardingEvent event,
    Emitter<OnboardingState> emit,
  ) async {
    // Defensive guard: the UI already disables the CTA until all three
    // disclosures are accepted, but if the event is dispatched
    // programmatically we must not bypass consent.
    if (!DisclosureService.allAccepted()) {
      debugPrint(
        'OnboardingBloc: CompleteOnboardingEvent blocked -- '
        'disclosures not all accepted',
      );
      emit(const OnboardingRequired());
      return;
    }
    await LocalStorageService.setOnboardingComplete(true);
    emit(OnboardingCompleted());
  }

  Future<void> _onReset(
    ResetOnboardingEvent event,
    Emitter<OnboardingState> emit,
  ) async {
    await LocalStorageService.setOnboardingComplete(false);
    await DisclosureService.resetAll();
    emit(const OnboardingRequired());
  }
}
