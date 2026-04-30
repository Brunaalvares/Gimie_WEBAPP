import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../utils/debug_helper.dart';

class CurrencyService {
  static final CurrencyService _instance = CurrencyService._internal();
  factory CurrencyService() => _instance;
  CurrencyService._internal();

  // Timeout para requisições
  static const Duration _timeout = Duration(seconds: 30);
  
  /// Headers padrão para requisições
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'User-Agent': 'Gimie-App/1.0',
  };

  /// Obtém taxas de câmbio atuais
  Future<Map<String, double>?> getExchangeRates() async {
    try {
      DebugHelper.log('Getting exchange rates', 'CURRENCY');
      
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.currencyEndpoint}'),
        headers: _headers,
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          final rawRates = Map<String, dynamic>.from(data['data']['rates'] ?? {});
          final rates = rawRates.map<String, double>(
            (key, value) => MapEntry(key, (value as num?)?.toDouble() ?? 0.0),
          );
          
          DebugHelper.log('Successfully got exchange rates', 'CURRENCY');
          return rates;
        }
      }
      
      return null;
    } catch (e) {
      DebugHelper.logError('Failed to get exchange rates', e);
      return null;
    }
  }

  /// Converte preço de uma moeda para outra
  Future<double?> convertPrice({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
  }) async {
    try {
      if (fromCurrency == toCurrency) return amount;
      
      DebugHelper.log('Converting $amount from $fromCurrency to $toCurrency', 'CURRENCY');
      
      final rates = await getExchangeRates();
      if (rates == null) return null;
      
      // Converte para USD primeiro, depois para a moeda de destino
      final usdAmount = fromCurrency == 'USD' ? amount : amount / (rates[fromCurrency] ?? 1.0);
      final convertedAmount = toCurrency == 'USD' ? usdAmount : usdAmount * (rates[toCurrency] ?? 1.0);
      
      DebugHelper.log('Converted to $convertedAmount $toCurrency', 'CURRENCY');
      return convertedAmount;
    } catch (e) {
      DebugHelper.logError('Failed to convert price', e);
      return null;
    }
  }

  /// Obtém produtos com preços convertidos para uma moeda específica
  Future<List<Map<String, dynamic>>?> getProductsWithConvertedPrices(String currency) async {
    try {
      DebugHelper.log('Getting products with prices in $currency', 'CURRENCY');
      
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.convertEndpoint}/$currency'),
        headers: _headers,
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          final products = List<Map<String, dynamic>>.from(data['data']);
          
          DebugHelper.log('Got ${products.length} products with converted prices', 'CURRENCY');
          return products;
        }
      }
      
      return null;
    } catch (e) {
      DebugHelper.logError('Failed to get products with converted prices', e);
      return null;
    }
  }

  /// Converte preço de um produto específico
  Future<Map<String, dynamic>?> convertProductPrice(int productId, String currency) async {
    try {
      DebugHelper.log('Converting product $productId price to $currency', 'CURRENCY');
      
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.productsEndpoint}/$productId/convert/$currency'),
        headers: _headers,
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          DebugHelper.log('Successfully converted product price', 'CURRENCY');
          return data['data'];
        }
      }
      
      return null;
    } catch (e) {
      DebugHelper.logError('Failed to convert product price', e);
      return null;
    }
  }

  /// Lista de moedas suportadas
  static const List<Map<String, String>> supportedCurrencies = [
    {'code': 'BRL', 'name': 'Real Brasileiro', 'symbol': 'R\$'},
    {'code': 'USD', 'name': 'Dólar Americano', 'symbol': '\$'},
    {'code': 'EUR', 'name': 'Euro', 'symbol': '€'},
    {'code': 'GBP', 'name': 'Libra Esterlina', 'symbol': '£'},
    {'code': 'JPY', 'name': 'Iene Japonês', 'symbol': '¥'},
    {'code': 'CAD', 'name': 'Dólar Canadense', 'symbol': 'C\$'},
    {'code': 'AUD', 'name': 'Dólar Australiano', 'symbol': 'A\$'},
    {'code': 'MXN', 'name': 'Peso Mexicano', 'symbol': 'MX\$'},
  ];

  /// Obtém símbolo da moeda
  static String getCurrencySymbol(String currencyCode) {
    final currency = supportedCurrencies.firstWhere(
      (c) => c['code'] == currencyCode,
      orElse: () => {'symbol': currencyCode},
    );
    return currency['symbol'] ?? currencyCode;
  }

  /// Obtém nome da moeda
  static String getCurrencyName(String currencyCode) {
    final currency = supportedCurrencies.firstWhere(
      (c) => c['code'] == currencyCode,
      orElse: () => {'name': currencyCode},
    );
    return currency['name'] ?? currencyCode;
  }

  /// Formata preço com símbolo da moeda
  static String formatPrice(double price, String currencyCode) {
    final symbol = getCurrencySymbol(currencyCode);
    
    if (currencyCode == 'BRL') {
      return '$symbol ${price.toStringAsFixed(2).replaceAll('.', ',')}';
    } else {
      return '$symbol${price.toStringAsFixed(2)}';
    }
  }
}