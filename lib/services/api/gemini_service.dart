import 'package:dio/dio.dart';
import '../../core/constants/app_constants.dart';
import '../../features/portfolio/domain/entities/portfolio_entities.dart';

/// Service for interacting with Google Gemini API
class GeminiService {
  final Dio _dio;
  String? _apiKey;

  GeminiService({Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options.baseUrl = AppConstants.geminiBaseUrl;
    _dio.options.connectTimeout = AppConstants.apiTimeout;
    _dio.options.receiveTimeout = const Duration(seconds: 60);
  }

  /// Set API key
  void setApiKey(String? apiKey) {
    _apiKey = apiKey;
  }

  /// Check if API key is set
  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;

  /// Test API connection
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

  /// Generate portfolio analysis
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
  }) async {
    if (!hasApiKey) {
      throw Exception('API key not configured');
    }

    final prompt = _buildAnalysisPrompt(
      portfolio: portfolio,
      customPrompt: customPrompt,
      language: language,
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
      if (e.response?.statusCode == 400) {
        throw Exception('Invalid request: ${e.response?.data}');
      } else if (e.response?.statusCode == 401) {
        throw Exception('Invalid API key');
      } else if (e.response?.statusCode == 429) {
        throw Exception('Rate limit exceeded. Please try again later.');
      }
      throw Exception('API error: ${e.message}');
    }
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
      throw Exception('API error: ${e.message}');
    }
  }

  /// Build the analysis prompt
  String _buildAnalysisPrompt({
    required Portfolio portfolio,
    String? customPrompt,
    required String language,
  }) {
    final buffer = StringBuffer();

    // Language instruction
    buffer.writeln(_getLanguageInstruction(language));
    buffer.writeln();

    // Role and context
    buffer.writeln(
        'You are a professional financial analyst and portfolio advisor.');
    buffer.writeln(
        'Analyze the following investment portfolio and provide detailed insights.');
    buffer.writeln();

    // Portfolio data
    buffer.writeln('=== PORTFOLIO DATA ===');
    buffer
        .writeln('Account: ${portfolio.accountName} (${portfolio.accountId})');
    buffer.writeln('Base Currency: ${portfolio.baseCurrency}');
    buffer.writeln(
        'Total Value: ${portfolio.baseCurrency} ${portfolio.totalValue.toStringAsFixed(2)}');
    buffer.writeln(
        'Total Cost Basis: ${portfolio.baseCurrency} ${portfolio.totalCostBasis.toStringAsFixed(2)}');
    buffer.writeln(
        'Unrealized P&L: ${portfolio.baseCurrency} ${portfolio.totalUnrealizedPnL.toStringAsFixed(2)} (${portfolio.totalPnLPercent.toStringAsFixed(2)}%)');
    buffer.writeln();

    // Statistics if available
    if (portfolio.statistics != null) {
      final stats = portfolio.statistics!;
      buffer.writeln('=== KEY STATISTICS ===');
      buffer.writeln(
          'Cumulative Return: ${stats.cumulativeReturn.toStringAsFixed(2)}%');
      buffer.writeln(
          '1 Month Return: ${stats.oneMonthReturn.toStringAsFixed(2)}%');
      buffer.writeln(
          '3 Month Return: ${stats.threeMonthReturn.toStringAsFixed(2)}%');
      if (stats.bestReturn != null) {
        buffer.writeln(
            'Best Return: ${stats.bestReturn!.toStringAsFixed(2)}% (${stats.bestReturnDate})');
      }
      if (stats.worstReturn != null) {
        buffer.writeln(
            'Worst Return: ${stats.worstReturn!.toStringAsFixed(2)}% (${stats.worstReturnDate})');
      }
      buffer.writeln(
          'Dividends Received: ${portfolio.baseCurrency} ${stats.dividends.toStringAsFixed(2)}');
      buffer.writeln(
          'Fees & Commissions: ${portfolio.baseCurrency} ${stats.feesCommissions.toStringAsFixed(2)}');
      buffer.writeln();
    }

    // Positions
    buffer.writeln('=== POSITIONS (${portfolio.positions.length} total) ===');
    for (final position in portfolio.positions) {
      buffer.writeln('- ${position.symbol} (${position.name})');
      buffer
          .writeln('  Type: ${position.assetType}, Sector: ${position.sector}');
      buffer.writeln(
          '  Qty: ${position.quantity.toStringAsFixed(4)}, Price: ${position.currency} ${position.closePrice.toStringAsFixed(2)}');
      buffer.writeln(
          '  Value: ${position.currency} ${position.value.toStringAsFixed(2)}');
      buffer.writeln(
          '  Cost: ${position.currency} ${position.costBasis.toStringAsFixed(2)}');
      buffer.writeln(
          '  P&L: ${position.currency} ${position.unrealizedPnL.toStringAsFixed(2)} (${position.pnlPercent.toStringAsFixed(2)}%)');
    }
    buffer.writeln();

    // Allocations
    buffer.writeln('=== SECTOR ALLOCATION ===');
    final sectorAlloc = portfolio.sectorAllocation;
    for (final entry in sectorAlloc.entries) {
      final percent =
          (entry.value / portfolio.totalValue * 100).toStringAsFixed(1);
      buffer.writeln(
          '- ${entry.key}: ${portfolio.baseCurrency} ${entry.value.toStringAsFixed(2)} ($percent%)');
    }
    buffer.writeln();

    buffer.writeln('=== ASSET TYPE ALLOCATION ===');
    final assetAlloc = portfolio.assetTypeAllocation;
    for (final entry in assetAlloc.entries) {
      final percent =
          (entry.value / portfolio.totalValue * 100).toStringAsFixed(1);
      buffer.writeln(
          '- ${entry.key}: ${portfolio.baseCurrency} ${entry.value.toStringAsFixed(2)} ($percent%)');
    }
    buffer.writeln();

    buffer.writeln('=== CURRENCY ALLOCATION ===');
    final currencyAlloc = portfolio.currencyAllocation;
    for (final entry in currencyAlloc.entries) {
      final percent =
          (entry.value / portfolio.totalValue * 100).toStringAsFixed(1);
      buffer.writeln(
          '- ${entry.key}: ${portfolio.baseCurrency} ${entry.value.toStringAsFixed(2)} ($percent%)');
    }
    buffer.writeln();

    // Custom prompt or default analysis request
    if (customPrompt != null && customPrompt.isNotEmpty) {
      buffer.writeln('=== USER REQUEST ===');
      buffer.writeln(customPrompt);
    } else {
      buffer.writeln('=== ANALYSIS REQUEST ===');
      buffer.writeln('Please provide a comprehensive analysis including:');
      buffer.writeln('1. Portfolio Summary - Overall health and key metrics');
      buffer.writeln(
          '2. Risk Assessment - Concentration risk, sector exposure, currency risk');
      buffer.writeln(
          '3. Diversification Analysis - How well diversified is the portfolio');
      buffer.writeln('4. Performance Analysis - Review of gains/losses');
      buffer.writeln(
          '5. Recommendations - Actionable suggestions for improvement');
      buffer.writeln('6. Key Concerns - Any red flags or areas of concern');
    }

    return buffer.toString();
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
