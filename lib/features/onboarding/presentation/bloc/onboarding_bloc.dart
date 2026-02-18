import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
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

class UpdateOnboardingPageEvent extends OnboardingEvent {
  final int pageIndex;

  const UpdateOnboardingPageEvent(this.pageIndex);

  @override
  List<Object?> get props => [pageIndex];
}

// ==================== STATES ====================

abstract class OnboardingState extends Equatable {
  const OnboardingState();

  @override
  List<Object?> get props => [];
}

class OnboardingInitial extends OnboardingState {}

class OnboardingLoading extends OnboardingState {}

class OnboardingRequired extends OnboardingState {
  final int currentPage;

  const OnboardingRequired({this.currentPage = 0});

  @override
  List<Object?> get props => [currentPage];
}

class OnboardingCompleted extends OnboardingState {}

// ==================== BLOC ====================

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  OnboardingBloc() : super(OnboardingInitial()) {
    on<CheckOnboardingStatusEvent>(_onCheckStatus);
    on<CompleteOnboardingEvent>(_onComplete);
    on<ResetOnboardingEvent>(_onReset);
    on<UpdateOnboardingPageEvent>(_onUpdatePage);
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
    await LocalStorageService.setOnboardingComplete(true);
    emit(OnboardingCompleted());
  }

  Future<void> _onReset(
    ResetOnboardingEvent event,
    Emitter<OnboardingState> emit,
  ) async {
    await LocalStorageService.setOnboardingComplete(false);
    emit(const OnboardingRequired());
  }

  void _onUpdatePage(
    UpdateOnboardingPageEvent event,
    Emitter<OnboardingState> emit,
  ) {
    if (state is OnboardingRequired) {
      emit(OnboardingRequired(currentPage: event.pageIndex));
    }
  }
}
