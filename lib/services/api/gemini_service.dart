import 'package:dio/dio.dart';
import '../../core/constants/app_constants.dart';
import '../../features/analysis/domain/analysis_preset.dart';
import '../../features/analysis/domain/analysis_prompt_builder.dart';
import '../../features/portfolio/domain/entities/portfolio_entities.dart';
import 'api_quota_alert_service.dart';
import 'gemini_client.dart';
import 'retry_interceptor.dart';

/// Default in-process [IGeminiClient] used in v1.0: hits Google's
/// generativelanguage.googleapis.com directly with the user-provided
/// key. The same class still works as the legacy `GeminiService` so the
/// callers that have not migrated to [IGeminiClient] yet keep compiling.
class GeminiService implements IGeminiClient {
  final Dio _dio;
  String? _apiKey;

  GeminiService({Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options.baseUrl = AppConstants.geminiBaseUrl;
    _dio.options.connectTimeout = AppConstants.apiTimeout;
    _dio.options.receiveTimeout = const Duration(seconds: 60);
    _dio.options.sendTimeout = const Duration(seconds: 30);
    _dio.interceptors.add(RetryInterceptor(dio: _dio));
  }

  @override
  void setApiKey(String? apiKey) {
    _apiKey = apiKey;
  }

  @override
  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;

  @override
  Future<bool> testConnection() async {
    if (!hasApiKey) return false;

    try {
      final response = await _dio.post(
        '/models/${AppConstants.geminiModel}:generateContent',
        queryParameters: {'key': _apiKey},
        data: {
          'contents': [
            {
              'parts': [
                {'text': 'Hello, respond with just "OK" if you can read this.'}
              ]
            }
          ],
          'generationConfig': {
            'maxOutputTokens': 10,
            'temperature': 0,
          },
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Generate portfolio analysis.
  ///
  /// When [slices] is null, the slice set is derived from [preset] (defaulting
  /// to [AnalysisPresets.fullReview]). The user-facing transparency UI is
  /// expected to provide the same [slices] it shows, so the prompt and the
  /// preview match exactly.
  @override
  Future<String> analyzePortfolio({
    required Portfolio portfolio,
    String? customPrompt,
    String language = 'en',
    bool useWebSearch = false,
    bool responseAsJson = false,
    double? temperature,
    int? maxOutputTokens,
    String? model,
    bool allowToolsFallback = true,
    AnalysisPreset preset = AnalysisPreset.fullReview,
    Set<AnalysisDataSlice>? slices,
  }) async {
    if (!hasApiKey) {
      throw Exception('API key not configured');
    }

    final definition = AnalysisPresets.byPreset(preset);
    final effectiveSlices = slices ?? definition.requiredSlices;

    final prompt = AnalysisPromptBuilder.build(
      portfolio: portfolio,
      customPrompt: customPrompt,
      language: language,
      slices: effectiveSlices,
      presetInstruction:
          definition.instruction.isEmpty ? null : definition.instruction,
    );

    try {
      final requestData = <String, dynamic>{
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'maxOutputTokens': maxOutputTokens ?? AppConstants.geminiMaxTokens,
          'temperature': temperature ?? AppConstants.geminiTemperature,
          if (responseAsJson) 'responseMimeType': 'application/json',
        },
        'safetySettings': [
          {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_NONE'},
          {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'BLOCK_NONE'},
          {
            'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
            'threshold': 'BLOCK_NONE'
          },
          {
            'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
            'threshold': 'BLOCK_NONE'
          },
        ],
        if (useWebSearch)
          'tools': [
            {'google_search': <String, dynamic>{}},
          ],
      };

      final response = await _postGenerateContent(
        requestData,
        allowToolsFallback: useWebSearch && allowToolsFallback,
        model: model,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final parts = content['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            return parts[0]['text'] as String;
          }
        }
      }

      throw Exception('Failed to get response from Gemini');
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// Map a DioException to a domain exception without leaking response body.
  Exception _mapDioException(DioException e) {
    // Centralized notification: surfaces a user-facing alert when the call
    // failed because of a quota/rate-limit/invalid-key condition. Always
    // safe to call -- the helper is a no-op for unrelated failures.
    reportProviderDioException(ApiQuotaProvider.gemini, e);

    final status = e.response?.statusCode;
    if (status == 400) {
      return Exception('Invalid request');
    } else if (status == 401 || status == 403) {
      return Exception('Invalid API key');
    } else if (status == 429) {
      return Exception('Rate limit exceeded. Please try again later.');
    } else if (status != null && status >= 500) {
      return Exception('Gemini service unavailable. Please retry.');
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return Exception('Request timed out. Please retry.');
    }
    if (e.type == DioExceptionType.connectionError) {
      return Exception('Network error. Check your connection.');
    }
    return Exception('API error: ${e.message ?? 'unknown'}');
  }

  Future<Response<dynamic>> _postGenerateContent(
    Map<String, dynamic> requestData, {
    required bool allowToolsFallback,
    String? model,
  }) async {
    final selectedModel = (model != null && model.trim().isNotEmpty)
        ? model.trim()
        : AppConstants.geminiModel;

    try {
      return await _dio.post(
        '/models/$selectedModel:generateContent',
        queryParameters: {'key': _apiKey},
        data: requestData,
      );
    } on DioException catch (e) {
      final canRetryWithoutTools =
          allowToolsFallback && requestData.containsKey('tools');
      if (!canRetryWithoutTools || e.response?.statusCode != 400) {
        rethrow;
      }

      final fallbackData = Map<String, dynamic>.from(requestData)
        ..remove('tools');
      return _dio.post(
        '/models/$selectedModel:generateContent',
        queryParameters: {'key': _apiKey},
        data: fallbackData,
      );
    }
  }

  /// Chat with AI about portfolio
  @override
  Future<String> chat({
    required Portfolio portfolio,
    required String userMessage,
    List<Map<String, String>>? conversationHistory,
    String language = 'en',
  }) async {
    if (!hasApiKey) {
      throw Exception('API key not configured');
    }

    final systemPrompt = _buildSystemPrompt(portfolio, language);

    final contents = <Map<String, dynamic>>[];

    // Add system context as first user message
    contents.add({
      'role': 'user',
      'parts': [
        {'text': systemPrompt}
      ]
    });

    contents.add({
      'role': 'model',
      'parts': [
        {'text': _getAcknowledgement(language)}
      ]
    });

    // Add conversation history
    if (conversationHistory != null) {
      for (final message in conversationHistory) {
        contents.add({
          'role': message['role'] == 'user' ? 'user' : 'model',
          'parts': [
            {'text': message['content']}
          ]
        });
      }
    }

    // Add current user message
    contents.add({
      'role': 'user',
      'parts': [
        {'text': userMessage}
      ]
    });

    try {
      final response = await _dio.post(
        '/models/${AppConstants.geminiModel}:generateContent',
        queryParameters: {'key': _apiKey},
        data: {
          'contents': contents,
          'generationConfig': {
            'maxOutputTokens': AppConstants.geminiMaxTokens,
            'temperature': AppConstants.geminiTemperature,
          },
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final parts = content['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            return parts[0]['text'] as String;
          }
        }
      }

      throw Exception('Failed to get response from Gemini');
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// Build system prompt for chat
  String _buildSystemPrompt(Portfolio portfolio, String language) {
    final buffer = StringBuffer();

    buffer.writeln(_getLanguageInstruction(language));
    buffer.writeln();
    buffer.writeln(
        'You are an expert financial advisor helping a user analyze their investment portfolio.');
    buffer.writeln('You have access to the following portfolio data:');
    buffer.writeln();
    buffer.writeln('Account: ${portfolio.accountName}');
    buffer.writeln('Base Currency: ${portfolio.baseCurrency}');
    buffer.writeln(
        'Total Value: ${portfolio.baseCurrency} ${portfolio.totalValue.toStringAsFixed(2)}');
    buffer.writeln(
        'Total P&L: ${portfolio.totalUnrealizedPnL.toStringAsFixed(2)} (${portfolio.totalPnLPercent.toStringAsFixed(2)}%)');
    buffer.writeln('Number of Positions: ${portfolio.positions.length}');
    buffer.writeln();

    // Summarize positions
    buffer.writeln('Top Holdings:');
    final sortedByValue = List<Position>.from(portfolio.positions)
      ..sort((a, b) => b.valueInBaseCurrency.compareTo(a.valueInBaseCurrency));
    for (final position in sortedByValue.take(10)) {
      buffer.writeln(
          '- ${position.symbol}: ${portfolio.baseCurrency} ${position.valueInBaseCurrency.toStringAsFixed(2)} (P&L: ${position.pnlPercent.toStringAsFixed(2)}%)');
    }
    buffer.writeln();

    buffer.writeln(
        'Be helpful, accurate, and provide actionable insights when answering questions about this portfolio.');
    buffer.writeln(
        'When performing web searches for market data, always cite your sources.');

    return buffer.toString();
  }

  /// Get language instruction
  String _getLanguageInstruction(String language) {
    switch (language) {
      case 'it':
        return 'Rispondi sempre in italiano.';
      case 'fr':
        return 'Reponds toujours en francais.';
      case 'de':
        return 'Antworte immer auf Deutsch.';
      case 'es':
        return 'Responde siempre en espanol.';
      case 'pt':
        return 'Responda sempre em portugues.';
      default:
        return 'Always respond in English.';
    }
  }

  /// Get acknowledgement in language
  String _getAcknowledgement(String language) {
    switch (language) {
      case 'it':
        return 'Ho ricevuto i dati del portafoglio. Sono pronto ad aiutarti con l\'analisi.';
      case 'fr':
        return 'J\'ai recu les donnees du portefeuille. Je suis pret a vous aider avec l\'analyse.';
      case 'de':
        return 'Ich habe die Portfoliodaten erhalten. Ich bin bereit, Ihnen bei der Analyse zu helfen.';
      case 'es':
        return 'He recibido los datos de la cartera. Estoy listo para ayudarte con el analisis.';
      case 'pt':
        return 'Recebi os dados da carteira. Estou pronto para ajuda-lo com a analise.';
      default:
        return 'I have received the portfolio data. I am ready to help you with the analysis.';
    }
  }
}
