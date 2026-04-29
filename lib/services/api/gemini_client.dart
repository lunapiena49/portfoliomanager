import '../../features/analysis/domain/analysis_preset.dart';
import '../../features/portfolio/domain/entities/portfolio_entities.dart';

/// Abstraction over the Gemini transport used by the app.
///
/// v1.0 ships [DirectGeminiClient] (calls `generativelanguage.googleapis.
/// com` directly with the user-provided key). Phase 2 will introduce
/// [ProxyGeminiClient] that routes through a Cloudflare Worker so the
/// upstream key is rotated server-side and the user only authenticates
/// with the proxy.
///
/// The contract intentionally mirrors [GeminiService] so call-sites
/// (`AnalysisBloc`, `AIChatBloc`, `Settings > Test connection`) can be
/// migrated in a single step once the proxy is live.
abstract class IGeminiClient {
  /// Set/replace the credential used by this client.
  /// Direct mode -> Gemini API key. Proxy mode -> opaque session token.
  void setApiKey(String? apiKey);

  /// True when [setApiKey] has been given a non-empty value.
  bool get hasApiKey;

  /// Probe the upstream / proxy with a tiny prompt. Returns true on 200.
  Future<bool> testConnection();

  /// Run a portfolio analysis. See [GeminiService.analyzePortfolio] for
  /// parameter semantics; this signature is identical so call-sites can
  /// swap implementations without touching their call shape.
  Future<String> analyzePortfolio({
    required Portfolio portfolio,
    String? customPrompt,
    String language,
    bool useWebSearch,
    bool responseAsJson,
    double? temperature,
    int? maxOutputTokens,
    String? model,
    bool allowToolsFallback,
    AnalysisPreset preset,
    Set<AnalysisDataSlice>? slices,
  });

  /// Multi-turn chat about [portfolio]. Mirrors [GeminiService.chat].
  Future<String> chat({
    required Portfolio portfolio,
    required String userMessage,
    List<Map<String, String>>? conversationHistory,
    String language,
  });
}

/// Compile-time selector. Override at build time:
///   --dart-define=GEMINI_MODE=direct  (default for v1.0)
///   --dart-define=GEMINI_MODE=proxy   (future Cloudflare Worker)
class GeminiClientMode {
  GeminiClientMode._();

  static const String value = String.fromEnvironment(
    'GEMINI_MODE',
    defaultValue: 'direct',
  );

  static bool get isDirect => value == 'direct';
  static bool get isProxy => value == 'proxy';
}
