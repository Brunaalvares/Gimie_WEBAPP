import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/product_model.dart';
import '../models/user_model.dart';
import '../utils/debug_helper.dart';
import 'scraping_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();
  static const String _productsCachePrefix = 'products_cache_v1';
  static const String _productsCacheCleanupLastRunKey = 'products_cache_v1_cleanup_last_run';
  static const int _maxGetProductsAttempts = 3;
  static const List<int> _getProductsBackoffMs = [800, 1600];
  static const Duration _productsCacheTtl = Duration(minutes: 10);
  static const Duration _cacheCleanupInterval = Duration(minutes: 5);

  String? _authToken;

  void setAuthToken(String token) {
    _authToken = token;
  }

  void clearAuthToken() {
    _authToken = null;
  }

  Map<String, String> get _headers {
    if (_authToken != null) {
      return ApiConfig.getAuthHeaders(_authToken!);
    }
    return ApiConfig.headers;
  }

  bool _isEndpointUnavailableInApi2(String endpoint) {
    final normalized = endpoint.toLowerCase();
    if (normalized.startsWith('/api/auth/')) return true;
    if (normalized.startsWith('/api/users')) return true;
    if (normalized.startsWith('/api/products/search')) return true;
    if (RegExp(r'^/api/products/[^/]+/like$').hasMatch(normalized)) return true;
    return !ApiConfig.isEndpointAvailableInApi2(endpoint);
  }

  List<dynamic> _extractProductsList(dynamic data) {
    if (data is List) return data;
    if (data is Map<String, dynamic>) {
      final nestedData = data['data'];
      if (nestedData is Map<String, dynamic> && nestedData['products'] is List) {
        return nestedData['products'] as List<dynamic>;
      }
      if (nestedData is List) return nestedData;
      if (data['products'] is List) return data['products'] as List<dynamic>;
      if (data['results'] is List) return data['results'] as List<dynamic>;
    }
    return <dynamic>[];
  }

  String _buildProductsCacheKey(Map<String, String> queryParams) {
    if (queryParams.isEmpty) return _productsCachePrefix;
    final sortedKeys = queryParams.keys.toList()..sort();
    final normalized = sortedKeys
        .map((key) => '$key=${queryParams[key]}')
        .join('&');
    return '$_productsCachePrefix:$normalized';
  }

  Future<void> _saveProductsCache({
    required String cacheKey,
    required String rawBody,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _maybeCleanupExpiredProductsCache(prefs);
      await prefs.setString(cacheKey, rawBody);
      await prefs.setInt('${cacheKey}_ts', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      DebugHelper.logError('Failed to save products cache', e);
    }
  }

  Future<List<Product>?> _readProductsCache(String cacheKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _maybeCleanupExpiredProductsCache(prefs);

      final cacheTimestamp = prefs.getInt('${cacheKey}_ts');
      if (_isCacheExpired(cacheTimestamp)) {
        await prefs.remove(cacheKey);
        await prefs.remove('${cacheKey}_ts');
        return null;
      }

      final cachedBody = prefs.getString(cacheKey);
      if (cachedBody == null || cachedBody.isEmpty) return null;

      final data = jsonDecode(cachedBody);
      final productsList = _extractProductsList(data);
      final products = productsList
          .whereType<Map<String, dynamic>>()
          .map(Product.fromJson)
          .toList();

      if (products.isEmpty) return null;
      return products;
    } catch (e) {
      DebugHelper.logError('Failed to read products cache', e);
      return null;
    }
  }

  bool _isCacheExpired(int? timestampMs) {
    if (timestampMs == null) return true;
    final cachedAt = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    return DateTime.now().difference(cachedAt) > _productsCacheTtl;
  }

  Future<void> _maybeCleanupExpiredProductsCache(SharedPreferences prefs) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastRunMs = prefs.getInt(_productsCacheCleanupLastRunKey) ?? 0;
    if (nowMs - lastRunMs < _cacheCleanupInterval.inMilliseconds) return;

    await _cleanupExpiredProductsCache(prefs);
    await prefs.setInt(_productsCacheCleanupLastRunKey, nowMs);
  }

  Future<void> _cleanupExpiredProductsCache(SharedPreferences prefs) async {
    try {
      final allKeys = prefs.getKeys();
      final cacheDataKeys = allKeys.where((key) {
        return key.startsWith(_productsCachePrefix) && !key.endsWith('_ts');
      });

      for (final cacheKey in cacheDataKeys) {
        final timestampKey = '${cacheKey}_ts';
        final timestampMs = prefs.getInt(timestampKey);
        if (_isCacheExpired(timestampMs)) {
          await prefs.remove(cacheKey);
          await prefs.remove(timestampKey);
        }
      }
    } catch (e) {
      DebugHelper.logError('Failed to cleanup products cache', e);
    }
  }

  bool _shouldRetryGetProducts({
    required int statusCode,
    required int attempt,
  }) {
    if (attempt >= _maxGetProductsAttempts - 1) return false;
    return statusCode == 408 || statusCode == 429 || statusCode >= 500;
  }

  bool _isTransientGetProductsError(Object error) {
    if (error is TimeoutException) return true;
    final text = error.toString().toLowerCase();
    return text.contains('timed out') ||
        text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('connection closed');
  }

  // Auth Methods
  Future<Map<String, dynamic>> login(String email, String password) async {
    // Auth nao existe na API 2.0 atual. Mantemos compatibilidade sem bloquear login Firebase.
    if (_isEndpointUnavailableInApi2(ApiConfig.loginEndpoint)) {
      return {
        'success': false,
        'message': 'Endpoint indisponivel na API 2.0: ${ApiConfig.loginEndpoint}',
      };
    }

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.loginEndpoint}'),
        headers: ApiConfig.headers,
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(ApiConfig.connectTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to login: ${response.body}');
      }
    } catch (e) {
      throw Exception('Login error: $e');
    }
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String name,
    required String username,
  }) async {
    // Register nao existe na API 2.0 atual. Mantemos compatibilidade sem bloquear cadastro Firebase.
    if (_isEndpointUnavailableInApi2(ApiConfig.registerEndpoint)) {
      return {
        'success': false,
        'message': 'Endpoint indisponivel na API 2.0: ${ApiConfig.registerEndpoint}',
      };
    }

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.registerEndpoint}'),
        headers: ApiConfig.headers,
        body: jsonEncode({
          'email': email,
          'password': password,
          'name': name,
          'username': username,
        }),
      ).timeout(ApiConfig.connectTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to register: ${response.body}');
      }
    } catch (e) {
      throw Exception('Register error: $e');
    }
  }

  // Product Methods
  Future<List<Product>> getProducts({int? limit, String? category}) async {
    String url = '${ApiConfig.baseUrl}${ApiConfig.productsEndpoint}';
    final queryParams = <String, String>{};
    if (limit != null) queryParams['limit'] = limit.toString();
    if (category != null) queryParams['category'] = category;
    if (queryParams.isNotEmpty) {
      url += '?${Uri(queryParameters: queryParams).query}';
    }
    final cacheKey = _buildProductsCacheKey(queryParams);

    Object? lastError;

    for (int attempt = 0; attempt < _maxGetProductsAttempts; attempt++) {
      try {
        final response = await http.get(
          Uri.parse(url),
          headers: _headers,
        ).timeout(ApiConfig.receiveTimeout);

        if (response.statusCode == 200) {
          await _saveProductsCache(cacheKey: cacheKey, rawBody: response.body);
          final data = jsonDecode(response.body);
          final List<dynamic> productsList = _extractProductsList(data);
          return productsList
              .whereType<Map<String, dynamic>>()
              .map(Product.fromJson)
              .toList();
        }

        lastError = Exception('Failed to load products: ${response.statusCode}');
        if (_shouldRetryGetProducts(statusCode: response.statusCode, attempt: attempt)) {
          await Future.delayed(Duration(milliseconds: _getProductsBackoffMs[attempt]));
          continue;
        }
        break;
      } catch (e) {
        lastError = e;
        if (_isTransientGetProductsError(e) && attempt < _maxGetProductsAttempts - 1) {
          await Future.delayed(Duration(milliseconds: _getProductsBackoffMs[attempt]));
          continue;
        }
        break;
      }
    }

    final cachedProducts = await _readProductsCache(cacheKey);
    if (cachedProducts != null) {
      DebugHelper.log(
        'Returning ${cachedProducts.length} cached products after API failure',
        'API',
      );
      return cachedProducts;
    }

    throw Exception('Get products error: $lastError');
  }

  Future<Product> getProductById(String id) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.productsEndpoint}/$id'),
        headers: _headers,
      ).timeout(ApiConfig.receiveTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final productData = (data is Map<String, dynamic>)
            ? (data['product'] ?? data['data'] ?? data)
            : data;
        if (productData is! Map<String, dynamic>) {
          throw Exception('Invalid product payload');
        }
        return Product.fromJson(productData);
      } else {
        throw Exception('Failed to load product: ${response.body}');
      }
    } catch (e) {
      throw Exception('Get product error: $e');
    }
  }

  Future<Product> createProduct({
    required String name,
    required String description,
    required double price,
    required String imageUrl,
    required String url,
    String? category,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.productsEndpoint}'),
        headers: _headers,
        body: jsonEncode({
          'name': name,
          'description': description,
          'price': price,
          'imageUrl': imageUrl,
          'url': url,
          'category': category,
        }),
      ).timeout(ApiConfig.connectTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final productData = (data is Map<String, dynamic>)
            ? (data['product'] ?? data['data'] ?? data)
            : data;
        if (productData is! Map<String, dynamic>) {
          throw Exception('Invalid product payload');
        }
        return Product.fromJson(productData);
      } else {
        throw Exception('Failed to create product: ${response.body}');
      }
    } catch (e) {
      throw Exception('Create product error: $e');
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.productsEndpoint}/$id'),
        headers: _headers,
      ).timeout(ApiConfig.connectTimeout);

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete product: ${response.body}');
      }
    } catch (e) {
      throw Exception('Delete product error: $e');
    }
  }

  Future<Product> likeProduct(String id) async {
    if (_isEndpointUnavailableInApi2('${ApiConfig.productsEndpoint}/$id/like')) {
      throw Exception('Endpoint indisponivel na API 2.0: ${ApiConfig.productsEndpoint}/:id/like');
    }

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.productsEndpoint}/$id/like'),
        headers: _headers,
      ).timeout(ApiConfig.connectTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Product.fromJson(data['product'] ?? data);
      } else {
        throw Exception('Failed to like product: ${response.body}');
      }
    } catch (e) {
      throw Exception('Like product error: $e');
    }
  }

  // User Methods
  Future<UserModel> getUserProfile(String userId) async {
    if (_isEndpointUnavailableInApi2(ApiConfig.usersEndpoint)) {
      throw Exception('Endpoint indisponivel na API 2.0: ${ApiConfig.usersEndpoint}/$userId');
    }

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.usersEndpoint}/$userId'),
        headers: _headers,
      ).timeout(ApiConfig.receiveTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UserModel.fromJson(data['user'] ?? data);
      } else {
        throw Exception('Failed to load user: ${response.body}');
      }
    } catch (e) {
      throw Exception('Get user error: $e');
    }
  }

  Future<UserModel> updateUserProfile({
    required String userId,
    String? name,
    String? username,
    String? photoUrl,
    String? bio,
  }) async {
    if (_isEndpointUnavailableInApi2(ApiConfig.usersEndpoint)) {
      throw Exception('Endpoint indisponivel na API 2.0: ${ApiConfig.usersEndpoint}/$userId');
    }

    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (username != null) body['username'] = username;
      if (photoUrl != null) body['photoUrl'] = photoUrl;
      if (bio != null) body['bio'] = bio;

      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.usersEndpoint}/$userId'),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(ApiConfig.connectTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UserModel.fromJson(data['user'] ?? data);
      } else {
        throw Exception('Failed to update user: ${response.body}');
      }
    } catch (e) {
      throw Exception('Update user error: $e');
    }
  }

  // Search
  Future<List<Product>> searchProducts(String query) async {
    if (_isEndpointUnavailableInApi2('${ApiConfig.productsEndpoint}/search')) {
      final products = await getProducts();
      final normalizedQuery = query.trim().toLowerCase();
      if (normalizedQuery.isEmpty) return products;
      return products.where((product) {
        final name = product.name.toLowerCase();
        final description = product.description.toLowerCase();
        final category = (product.category ?? '').toLowerCase();
        return name.contains(normalizedQuery) ||
            description.contains(normalizedQuery) ||
            category.contains(normalizedQuery);
      }).toList();
    }

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.productsEndpoint}/search?q=${Uri.encodeComponent(query)}'),
        headers: _headers,
      ).timeout(ApiConfig.receiveTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> productsList = _extractProductsList(data);
        return productsList.map((json) => Product.fromJson(json)).toList();
      } else {
        throw Exception('Failed to search products: ${response.body}');
      }
    } catch (e) {
      throw Exception('Search error: $e');
    }
  }

  // Scraping Methods
  
  /// Cria produto a partir de URL usando scraping
  Future<Product?> createProductFromUrl({
    required String url,
    required String userId,
    String? category,
  }) async {
    try {
      DebugHelper.log('Creating product from URL: $url', 'API');
      
      // Usa a nova API Gimie 2.0 que faz scraping automaticamente
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.productsEndpoint}'),
        headers: _headers,
        body: jsonEncode({
          'url': url,
          'userId': userId,
          'category': category,
        }),
      ).timeout(ApiConfig.connectTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          final productData = data['data'];
          
          final product = Product(
            id: productData['id']?.toString() ?? '',
            name: productData['name'] ?? 'Produto sem nome',
            description: productData['description'] ?? 'Sem descrição',
            price: (productData['price'] ?? productData['originalPrice'] ?? 0.0).toDouble(),
            imageUrl: productData['image'] ?? productData['imageUrl'] ?? '',
            url: productData['url'] ?? url,
            userId: userId,
            category: category ?? productData['category'] ?? 'Outros',
            likes: 0,
            likedBy: [],
            createdAt: DateTime.tryParse(productData['createdAt'] ?? '') ?? DateTime.now(),
          );
          
          DebugHelper.log('Successfully created product from URL via API', 'API');
          return product;
        }
      }
      
      // Fallback para método anterior se a API não funcionar
      final scrapingService = ScrapingService();
      final scrapedData = await scrapingService.scrapeProductFromUrl(url);
      
      if (scrapedData == null || !scrapedData.hasValidData) {
        throw Exception('Não foi possível extrair dados válidos da URL');
      }
      
      final product = scrapingService.convertScrapedDataToProduct(
        scrapedData: scrapedData,
        userId: userId,
        category: category,
      );
      
      final createdProduct = await createProduct(
        name: product.name,
        description: product.description,
        price: product.price,
        imageUrl: product.imageUrl,
        url: product.url,
        category: product.category,
      );
      
      DebugHelper.log('Successfully created product from URL via fallback', 'API');
      return createdProduct;
    } catch (e) {
      DebugHelper.logError('Failed to create product from URL', e);
      rethrow;
    }
  }
  
  /// Obtém produtos sugeridos baseado em categoria
  Future<List<Product>> getSuggestedProducts(String category) async {
    try {
      DebugHelper.log('Getting suggested products for category: $category', 'API');
      
      // Busca produtos existentes na API que correspondem à categoria
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.productsEndpoint}?category=$category&limit=10'),
        headers: _headers,
      ).timeout(ApiConfig.receiveTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> productsList = data['data']['products'] ?? data['data'];
          
          final products = productsList.map((json) {
            return Product(
              id: json['id']?.toString() ?? '',
              name: json['name'] ?? 'Produto sem nome',
              description: json['description'] ?? 'Sem descrição',
              price: (json['price'] ?? json['originalPrice'] ?? 0.0).toDouble(),
              imageUrl: json['image'] ?? json['imageUrl'] ?? '',
              url: json['url'] ?? '',
              userId: 'suggested',
              category: category,
              likes: 0,
              likedBy: [],
              createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
            );
          }).toList();
          
          DebugHelper.log('Found ${products.length} suggested products', 'API');
          return products;
        }
      }
      
      // Fallback para scraping se não houver produtos na API
      final scrapingService = ScrapingService();
      final suggestions = await scrapingService.getProductSuggestions(category);
      
      final products = suggestions.map((scraped) {
        return scrapingService.convertScrapedDataToProduct(
          scrapedData: scraped,
          userId: 'suggested',
          category: category,
        );
      }).toList();
      
      DebugHelper.log('Found ${products.length} suggested products via scraping', 'API');
      return products;
    } catch (e) {
      DebugHelper.logError('Failed to get suggested products', e);
      return [];
    }
  }
  
  /// Verifica saúde da API de scraping
  Future<bool> checkScrapingApiHealth() async {
    try {
      final scrapingService = ScrapingService();
      return await scrapingService.checkHealth();
    } catch (e) {
      DebugHelper.logError('Failed to check scraping API health', e);
      return false;
    }
  }
  
  /// Extrai dados de produto de uma URL sem criar
  Future<ScrapedProductData?> previewProductFromUrl(String url) async {
    try {
      DebugHelper.log('Previewing product from URL: $url', 'API');
      
      final scrapingService = ScrapingService();
      final scrapedData = await scrapingService.scrapeProductFromUrl(url);
      
      if (scrapedData != null) {
        DebugHelper.log(
          'Preview received. title=${scrapedData.title}, price=${scrapedData.price}, image=${scrapedData.imageUrl}',
          'API',
        );
      }

      return scrapedData;
    } catch (e) {
      DebugHelper.logError('Failed to preview product from URL', e);
      rethrow;
    }
  }
}
