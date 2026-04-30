import 'package:flutter/foundation.dart';
import '../services/scraping_service.dart';
import '../services/api_service.dart';
import '../services/currency_service.dart';
import '../models/product_model.dart';
import '../utils/debug_helper.dart';

class ScrapingProvider with ChangeNotifier {
  final ScrapingService _scrapingService = ScrapingService();
  final ApiService _apiService = ApiService();
  final CurrencyService _currencyService = CurrencyService();

  bool _isScrapingUrl = false;
  bool _isLoadingSuggestions = false;
  bool _isApiHealthy = false;
  
  ScrapedProductData? _lastScrapedData;
  List<Product> _suggestions = [];
  String? _error;

  // Getters
  bool get isScrapingUrl => _isScrapingUrl;
  bool get isLoadingSuggestions => _isLoadingSuggestions;
  bool get isApiHealthy => _isApiHealthy;
  ScrapedProductData? get lastScrapedData => _lastScrapedData;
  List<Product> get suggestions => _suggestions;
  String? get error => _error;

  /// Inicializa o provider verificando a saúde da API
  Future<void> initialize() async {
    try {
      DebugHelper.log('Initializing ScrapingProvider', 'SCRAPING_PROVIDER');
      await checkApiHealth();
    } catch (e) {
      DebugHelper.logError('Failed to initialize ScrapingProvider', e);
    }
  }

  /// Verifica se a API de scraping está funcionando
  Future<void> checkApiHealth() async {
    try {
      _isApiHealthy = await _scrapingService.checkHealth();
      DebugHelper.log('API health check: $_isApiHealthy', 'SCRAPING_PROVIDER');
      notifyListeners();
    } catch (e) {
      DebugHelper.logError('Health check failed', e);
      _isApiHealthy = false;
      notifyListeners();
    }
  }

  /// Faz scraping de uma URL
  Future<ScrapedProductData?> scrapeUrl(String url) async {
    if (_isScrapingUrl) return null;

    _isScrapingUrl = true;
    _error = null;
    notifyListeners();

    try {
      DebugHelper.log('Scraping URL: $url', 'SCRAPING_PROVIDER');
      
      final scrapedData = await _scrapingService.scrapeProductFromUrl(url);
      
      if (scrapedData != null && scrapedData.hasValidData) {
        _lastScrapedData = scrapedData;
        DebugHelper.log('Successfully scraped: ${scrapedData.title}', 'SCRAPING_PROVIDER');
      } else {
        _error = 'Não foi possível extrair dados válidos da URL';
      }
      
      return scrapedData;
    } catch (e) {
      DebugHelper.logError('Scraping failed', e);
      _error = e.toString();
      return null;
    } finally {
      _isScrapingUrl = false;
      notifyListeners();
    }
  }

  /// Carrega sugestões de produtos para uma categoria
  Future<void> loadSuggestions(String category) async {
    if (_isLoadingSuggestions) return;

    _isLoadingSuggestions = true;
    _error = null;
    notifyListeners();

    try {
      DebugHelper.log('Loading suggestions for: $category', 'SCRAPING_PROVIDER');
      
      final suggestions = await _apiService.getSuggestedProducts(category);
      _suggestions = suggestions;
      
      DebugHelper.log('Loaded ${suggestions.length} suggestions', 'SCRAPING_PROVIDER');
    } catch (e) {
      DebugHelper.logError('Failed to load suggestions', e);
      _error = e.toString();
      _suggestions = [];
    } finally {
      _isLoadingSuggestions = false;
      notifyListeners();
    }
  }

  /// Cria produto a partir de URL usando scraping
  Future<Product?> createProductFromUrl({
    required String url,
    required String userId,
    String? category,
  }) async {
    try {
      DebugHelper.log('Creating product from URL: $url', 'SCRAPING_PROVIDER');
      
      final product = await _apiService.createProductFromUrl(
        url: url,
        userId: userId,
        category: category,
      );
      
      if (product != null) {
        DebugHelper.log('Successfully created product: ${product.name}', 'SCRAPING_PROVIDER');
      }
      
      return product;
    } catch (e) {
      DebugHelper.logError('Failed to create product from URL', e);
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Faz scraping em lote de múltiplas URLs
  Future<List<ScrapedProductData>> scrapeBatchUrls(List<String> urls) async {
    try {
      DebugHelper.log('Batch scraping ${urls.length} URLs', 'SCRAPING_PROVIDER');
      
      final results = await _scrapingService.scrapeBatchUrls(urls);
      
      DebugHelper.log('Batch scraping completed: ${results.length} successful', 'SCRAPING_PROVIDER');
      return results;
    } catch (e) {
      DebugHelper.logError('Batch scraping failed', e);
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  /// Limpa dados scraped
  void clearScrapedData() {
    _lastScrapedData = null;
    notifyListeners();
  }

  /// Limpa sugestões
  void clearSuggestions() {
    _suggestions = [];
    notifyListeners();
  }

  /// Limpa erro
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Limpa cache do serviço de scraping
  Future<bool> clearCache() async {
    try {
      final success = await _scrapingService.clearCache();
      DebugHelper.log('Cache cleared: $success', 'SCRAPING_PROVIDER');
      return success;
    } catch (e) {
      DebugHelper.logError('Failed to clear cache', e);
      return false;
    }
  }

  /// Obtém taxas de câmbio atuais
  Future<Map<String, double>?> getExchangeRates() async {
    try {
      return await _currencyService.getExchangeRates();
    } catch (e) {
      DebugHelper.logError('Failed to get exchange rates', e);
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Converte preço entre moedas
  Future<double?> convertPrice({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
  }) async {
    try {
      return await _currencyService.convertPrice(
        amount: amount,
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
      );
    } catch (e) {
      DebugHelper.logError('Failed to convert price', e);
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  @override
  void dispose() {
    DebugHelper.log('Disposing ScrapingProvider', 'SCRAPING_PROVIDER');
    super.dispose();
  }
}