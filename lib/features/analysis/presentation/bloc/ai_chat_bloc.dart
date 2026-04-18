import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../portfolio/domain/entities/portfolio_entities.dart';
import '../../../../services/api/gemini_service.dart';

// ==================== ENTITIES ====================

class ChatMessage extends Equatable {
  final String content;
  final bool isUser;
  final DateTime timestamp;

  const ChatMessage({
    required this.content,
    required this.isUser,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [content, isUser, timestamp];
}

// ==================== EVENTS ====================

abstract class AIChatEvent extends Equatable {
  const AIChatEvent();

  @override
  List<Object?> get props => [];
}

class InitializeChatEvent extends AIChatEvent {
  final String welcomeMessage;

  const InitializeChatEvent(this.welcomeMessage);

  @override
  List<Object?> get props => [welcomeMessage];
}

class UpdateChatApiKeyEvent extends AIChatEvent {
  final String? apiKey;

  const UpdateChatApiKeyEvent(this.apiKey);

  @override
  List<Object?> get props => [apiKey];
}

class SendChatMessageEvent extends AIChatEvent {
  final String message;
  final Portfolio portfolio;
  final String language;

  const SendChatMessageEvent({
    required this.message,
    required this.portfolio,
    required this.language,
  });

  @override
  List<Object?> get props => [message, portfolio, language];
}

class ClearChatEvent extends AIChatEvent {
  final String welcomeMessage;

  const ClearChatEvent(this.welcomeMessage);

  @override
  List<Object?> get props => [welcomeMessage];
}

// ==================== STATES ====================

abstract class AIChatState extends Equatable {
  const AIChatState();

  @override
  List<Object?> get props => [];
}

class AIChatInitial extends AIChatState {}

class AIChatReady extends AIChatState {
  final List<ChatMessage> messages;
  final bool isSending;
  final String? errorMessage;

  const AIChatReady({
    required this.messages,
    this.isSending = false,
    this.errorMessage,
  });

  @override
  List<Object?> get props => [messages, isSending, errorMessage];

  AIChatReady copyWith({
    List<ChatMessage>? messages,
    bool? isSending,
    Object? errorMessage = _errorUnset,
  }) {
    return AIChatReady(
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      errorMessage: errorMessage == _errorUnset
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  static const Object _errorUnset = Object();
}

// ==================== BLOC ====================

class AIChatBloc extends Bloc<AIChatEvent, AIChatState> {
  final GeminiService _geminiService;

  AIChatBloc({GeminiService? geminiService})
      : _geminiService = geminiService ?? GeminiService(),
        super(AIChatInitial()) {
    on<InitializeChatEvent>(_onInitialize);
    on<UpdateChatApiKeyEvent>(_onUpdateApiKey);
    on<SendChatMessageEvent>(_onSendMessage);
    on<ClearChatEvent>(_onClear);
  }

  void _onInitialize(
    InitializeChatEvent event,
    Emitter<AIChatState> emit,
  ) {
    if (state is AIChatReady) return;
    emit(AIChatReady(
      messages: [
        ChatMessage(
          content: event.welcomeMessage,
          isUser: false,
          timestamp: DateTime.now(),
        ),
      ],
    ));
  }

  void _onUpdateApiKey(
    UpdateChatApiKeyEvent event,
    Emitter<AIChatState> emit,
  ) {
    _geminiService.setApiKey(event.apiKey);
  }

  Future<void> _onSendMessage(
    SendChatMessageEvent event,
    Emitter<AIChatState> emit,
  ) async {
    if (state is! AIChatReady) return;
    final current = state as AIChatReady;
    if (current.isSending) return;

    if (!_geminiService.hasApiKey) {
      emit(current.copyWith(errorMessage: 'analysis.api_key_required'));
      return;
    }

    final trimmed = event.message.trim();
    if (trimmed.isEmpty) return;

    final userMessage = ChatMessage(
      content: trimmed,
      isUser: true,
      timestamp: DateTime.now(),
    );
    final historyBeforeSend = [...current.messages, userMessage];
    emit(current.copyWith(
      messages: historyBeforeSend,
      isSending: true,
      errorMessage: null,
    ));

    try {
      // Build history excluding the welcome message (first bot message) and
      // the current user message just appended.
      final historyPayload = historyBeforeSend
          .skip(1)
          .take(historyBeforeSend.length - 2)
          .map((m) => {
                'role': m.isUser ? 'user' : 'assistant',
                'content': m.content,
              })
          .toList();

      final response = await _geminiService.chat(
        portfolio: event.portfolio,
        userMessage: trimmed,
        conversationHistory: historyPayload.isEmpty ? null : historyPayload,
        language: event.language,
      );

      final botMessage = ChatMessage(
        content: response,
        isUser: false,
        timestamp: DateTime.now(),
      );
      emit(AIChatReady(
        messages: [...historyBeforeSend, botMessage],
      ));
    } catch (e) {
      emit(current.copyWith(
        messages: historyBeforeSend,
        isSending: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  void _onClear(
    ClearChatEvent event,
    Emitter<AIChatState> emit,
  ) {
    emit(AIChatReady(
      messages: [
        ChatMessage(
          content: event.welcomeMessage,
          isUser: false,
          timestamp: DateTime.now(),
        ),
      ],
    ));
  }
}
