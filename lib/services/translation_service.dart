import 'dart:convert';
import 'package:http/http.dart' as http;

/// Translation Service using Sarvam AI Backend with Redis Caching
/// Supports 22 Indian languages
///
/// Features:
/// - Single text translation
/// - Batch translation (optimized for multiple texts)
/// - Redis caching (5ms cached vs 250ms API call)
/// - Cache hit/miss tracking
class TranslationService {
  static const String baseUrl = "http://10.0.2.2:8000/api/v1/translate";

  /// Supported Indian Languages (22 languages)
  static const Map<String, String> supportedLanguages = {
    'en': 'English',
    'hi': 'Hindi (हिन्दी)',
    'gu': 'Gujarati (ગુજરાતી)',
    'mr': 'Marathi (मराठी)',
    'ta': 'Tamil (தமிழ்)',
    'te': 'Telugu (తెలుగు)',
    'kn': 'Kannada (ಕನ್ನಡ)',
    'ml': 'Malayalam (മലയാളം)',
    'bn': 'Bengali (বাংলা)',
    'pa': 'Punjabi (ਪੰਜਾਬੀ)',
    'or': 'Odia (ଓଡ଼ିଆ)',
    'as': 'Assamese (অসমীয়া)',
    'ur': 'Urdu (اردو)',
    'sa': 'Sanskrit (संस्कृतम्)',
    'ks': 'Kashmiri (कॉशुर)',
    'ne': 'Nepali (नेपाली)',
    'sd': 'Sindhi (سنڌي)',
    'mai': 'Maithili (मैथिली)',
    'brx': 'Bodo (बड़ो)',
    'doi': 'Dogri (डोगरी)',
    'gom': 'Konkani (कोंकणी)',
    'mni': 'Manipuri (মৈতৈলোন্)',
  };

  /// Translate text to target language
  ///
  /// [text] - English text to translate
  /// [targetLang] - Language code (e.g., 'hi', 'gu', 'mr')
  ///
  /// Returns TranslationResult with translated text and cache status
  static Future<TranslationResult> translateText({
    required String text,
    required String targetLang,
  }) async {
    try {
      print('🔵 Translating: "$text" to $targetLang');

      final response = await http.post(
        Uri.parse('$baseUrl/'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"text": text, "lang": targetLang}),
      );

      print('📥 Response Status: ${response.statusCode}');
      print('📥 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final translatedText = data['translated'] ?? text;
        final cached = data['cached'] ?? false;

        print(
          cached
              ? '⚡ Cache HIT: $translatedText'
              : '🌐 Cache MISS: $translatedText',
        );

        return TranslationResult(
          original: text,
          translated: translatedText,
          cached: cached,
          language: targetLang,
        );
      } else {
        throw Exception(
          'Translation failed: ${response.statusCode} → ${response.body}',
        );
      }
    } catch (e) {
      print('❌ Translation error: $e');
      // Return original text as fallback
      return TranslationResult(
        original: text,
        translated: text,
        cached: false,
        language: targetLang,
        error: e.toString(),
      );
    }
  }

  /// Translate multiple texts using batch endpoint (OPTIMIZED!)
  ///
  /// Uses backend's /batch endpoint which:
  /// - Checks cache with single MGET (4x faster than sequential)
  /// - Only calls API for cache misses
  /// - Caches new translations automatically
  ///
  /// Perfect for disease results with 4 fields:
  /// - Disease name, Symptoms, Treatment, Prevention
  ///
  /// [texts] - List of English texts to translate
  /// [targetLang] - Language code
  ///
  /// Returns BatchTranslationResult with translations and cache stats
  static Future<BatchTranslationResult> translateBatchOptimized({
    required List<String> texts,
    required String targetLang,
  }) async {
    try {
      print('🔵 Batch translating ${texts.length} texts to $targetLang');

      final response = await http.post(
        Uri.parse('$baseUrl/batch'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"texts": texts, "lang": targetLang}),
      );

      print('📥 Batch Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final translations = List<String>.from(data['translations'] ?? []);
        final cachedCount = data['cached_count'] ?? 0;
        final apiCalls = data['api_calls'] ?? 0;
        final cacheHitRate = data['cache_hit_rate'] ?? 0.0;

        print(
          '📊 Batch Stats: $cachedCount cached, $apiCalls API calls (${cacheHitRate.toStringAsFixed(1)}% hit rate)',
        );

        return BatchTranslationResult(
          originals: texts,
          translations: translations,
          cachedCount: cachedCount,
          apiCalls: apiCalls,
          cacheHitRate: cacheHitRate,
          language: targetLang,
        );
      } else {
        throw Exception(
          'Batch translation failed: ${response.statusCode} → ${response.body}',
        );
      }
    } catch (e) {
      print('❌ Batch translation error: $e');
      // Return original texts as fallback
      return BatchTranslationResult(
        originals: texts,
        translations: texts,
        cachedCount: 0,
        apiCalls: 0,
        cacheHitRate: 0.0,
        language: targetLang,
        error: e.toString(),
      );
    }
  }

  /// Translate multiple texts in one go (LEGACY - Use translateBatchOptimized instead)
  ///
  /// This method is kept for backward compatibility but makes sequential API calls.
  /// For better performance, use translateBatchOptimized() which uses /batch endpoint.
  static Future<Map<String, String>> translateBatch({
    required Map<String, String> texts,
    required String targetLang,
  }) async {
    // Convert to list for batch API
    List<String> textList = texts.values.toList();

    // Use optimized batch endpoint
    final result = await translateBatchOptimized(
      texts: textList,
      targetLang: targetLang,
    );

    // Convert back to map format
    Map<String, String> translations = {};
    int i = 0;
    for (var key in texts.keys) {
      translations[key] = result.translations[i];
      i++;
    }

    return translations;
  }

  /// Get cache statistics from backend
  static Future<CacheStats?> getCacheStats() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/cache/stats'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return CacheStats.fromJson(data);
      }
    } catch (e) {
      print('❌ Failed to get cache stats: $e');
    }
    return null;
  }

  /// Clear translation cache (admin/debug utility)
  static Future<bool> clearCache({String? language}) async {
    try {
      final uri = language != null
          ? Uri.parse('$baseUrl/cache/clear?lang=$language')
          : Uri.parse('$baseUrl/cache/clear');

      final response = await http.delete(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('🗑️ Cleared ${data['deleted']} cached translations');
        return true;
      }
    } catch (e) {
      print('❌ Failed to clear cache: $e');
    }
    return false;
  }

  /// Check if language is supported
  static bool isLanguageSupported(String langCode) {
    return supportedLanguages.containsKey(langCode);
  }

  /// Get language name from code
  static String getLanguageName(String langCode) {
    return supportedLanguages[langCode] ?? 'Unknown';
  }
}

/// Result of a single translation with cache status
class TranslationResult {
  final String original;
  final String translated;
  final bool cached;
  final String language;
  final String? error;

  TranslationResult({
    required this.original,
    required this.translated,
    required this.cached,
    required this.language,
    this.error,
  });

  bool get hasError => error != null;
}

/// Result of batch translation with cache statistics
class BatchTranslationResult {
  final List<String> originals;
  final List<String> translations;
  final int cachedCount;
  final int apiCalls;
  final double cacheHitRate;
  final String language;
  final String? error;

  BatchTranslationResult({
    required this.originals,
    required this.translations,
    required this.cachedCount,
    required this.apiCalls,
    required this.cacheHitRate,
    required this.language,
    this.error,
  });

  bool get hasError => error != null;

  /// Get translation by index
  String getTranslation(int index) {
    return translations[index];
  }

  /// Convert to map format (for backward compatibility)
  Map<String, String> toMap(List<String> keys) {
    if (keys.length != translations.length) {
      throw Exception(
        'Keys length (${keys.length}) does not match translations length (${translations.length})',
      );
    }

    Map<String, String> result = {};
    for (int i = 0; i < keys.length; i++) {
      result[keys[i]] = translations[i];
    }
    return result;
  }
}

/// Cache statistics from backend
class CacheStats {
  final int totalCachedTranslations;
  final String memoryUsed;
  final double cacheTtlHours;
  final String estimatedCostSaved;

  CacheStats({
    required this.totalCachedTranslations,
    required this.memoryUsed,
    required this.cacheTtlHours,
    required this.estimatedCostSaved,
  });

  factory CacheStats.fromJson(Map<String, dynamic> json) {
    return CacheStats(
      totalCachedTranslations: json['total_cached_translations'] ?? 0,
      memoryUsed: json['memory_used'] ?? 'unknown',
      cacheTtlHours: (json['cache_ttl_hours'] ?? 0).toDouble(),
      estimatedCostSaved: json['estimated_cost_saved'] ?? '₹0.00',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_cached_translations': totalCachedTranslations,
      'memory_used': memoryUsed,
      'cache_ttl_hours': cacheTtlHours,
      'estimated_cost_saved': estimatedCostSaved,
    };
  }
}
