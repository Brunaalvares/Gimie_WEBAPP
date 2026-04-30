import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../services/firebase_service.dart';
import '../services/api_service.dart';

class ProductProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final ApiService _apiService = ApiService();
  static const bool _syncCrudWithExternalApi = false;

  List<Product> _products = [];
  List<Product> _userProducts = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _selectedCategory;

  List<Product> get products => _products;
  List<Product> get userProducts => _userProducts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get selectedCategory => _selectedCategory;

  String _mapDataWriteError(Object error, String fallbackMessage) {
    final text = error.toString();
    if (text.contains('permission-denied') || text.contains('PERMISSION_DENIED')) {
      return 'Sem permissão no Firestore para criar/excluir produto. Verifique as regras da coleção products.';
    }
    if (text.contains('not-found')) {
      return 'Produto não encontrado para esta operação.';
    }
    return fallbackMessage;
  }

  // Load products from both API and Firebase
  Future<void> loadProducts({String? category}) async {
    _isLoading = true;
    _selectedCategory = category;
    notifyListeners();

    try {
      List<Product> allProducts = [];

      // Try to load from API first
      try {
        final apiProducts = await _apiService.getProducts(category: category);
        allProducts.addAll(apiProducts);
      } catch (e) {
        debugPrint('API load products error: $e');
      }

      // Load from Firebase
      try {
        final firebaseProducts = await _firebaseService.getProducts(category: category);
        
        // Merge products, avoiding duplicates
        for (var fbProduct in firebaseProducts) {
          if (!allProducts.any((p) => p.id == fbProduct.id)) {
            allProducts.add(fbProduct);
          }
        }
      } catch (e) {
        debugPrint('Firebase load products error: $e');
      }

      // Sort by creation date
      allProducts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _products = allProducts;
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Erro ao carregar produtos';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load user's products
  Future<void> loadUserProducts(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _userProducts = await _firebaseService.getUserProducts(userId);
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Firebase load user products error: $e');

      // Fallback: tenta carregar produtos gerais e filtrar localmente.
      try {
        final allProducts = await _firebaseService.getProducts();
        _userProducts = allProducts.where((product) => product.userId == userId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _errorMessage = null;
      } catch (fallbackError) {
        debugPrint('Fallback load user products error: $fallbackError');
        _errorMessage = 'Erro ao carregar seus produtos';
      }

      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadFollowingFeed({
    required String currentUserId,
    required List<String> followingIds,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final sanitizedIds = followingIds
          .where((id) => id.trim().isNotEmpty && id != currentUserId)
          .map((id) => id.trim())
          .toSet()
          .toList();

      if (sanitizedIds.isEmpty) {
        _products = [];
        _errorMessage = null;
        _isLoading = false;
        notifyListeners();
        return;
      }

      _products = await _firebaseService.getProductsFromFollowedUsers(sanitizedIds);
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Erro ao carregar feed de quem você segue';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> renameFolder({
    required List<Product> productsInFolder,
    required String newCategory,
  }) async {
    final normalizedCategory = newCategory.trim();
    if (productsInFolder.isEmpty || normalizedCategory.isEmpty) {
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      for (final product in productsInFolder) {
        await _firebaseService.updateProduct(product.id, {
          'category': normalizedCategory,
        });
      }

      void updateCategory(List<Product> list) {
        for (int i = 0; i < list.length; i++) {
          final product = list[i];
          if (productsInFolder.any((p) => p.id == product.id)) {
            list[i] = product.copyWith(category: normalizedCategory);
          }
        }
      }

      updateCategory(_userProducts);
      updateCategory(_products);

      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erro ao renomear pasta';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteFolder({
    required List<Product> productsInFolder,
  }) async {
    if (productsInFolder.isEmpty) return false;

    _isLoading = true;
    notifyListeners();

    try {
      for (final product in productsInFolder) {
        await _firebaseService.deleteProduct(product.id);
        try {
          await _apiService.deleteProduct(product.id);
        } catch (e) {
          debugPrint('API delete product in folder error: $e');
        }
      }

      final ids = productsInFolder.map((p) => p.id).toSet();
      _userProducts.removeWhere((p) => ids.contains(p.id));
      _products.removeWhere((p) => ids.contains(p.id));

      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _mapDataWriteError(e, 'Erro ao apagar pasta');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> saveProductFromOtherUser({
    required Product sourceProduct,
    required String currentUserId,
    required String targetCategory,
  }) async {
    final normalizedCategory = targetCategory.trim();
    if (normalizedCategory.isEmpty) return false;

    final alreadyExists = _userProducts.any(
      (product) =>
          product.userId == currentUserId &&
          product.url.trim() == sourceProduct.url.trim() &&
          (product.category ?? '').trim().toLowerCase() ==
              normalizedCategory.toLowerCase(),
    );
    if (alreadyExists) {
      _errorMessage = 'Esse produto já está salvo nesta pasta';
      notifyListeners();
      return false;
    }

    try {
      final copiedProduct = Product(
        id: '',
        name: sourceProduct.name,
        description: sourceProduct.description,
        price: sourceProduct.price,
        priceDisplay: sourceProduct.priceDisplay,
        imageUrl: sourceProduct.imageUrl,
        url: sourceProduct.url,
        userId: currentUserId,
        category: normalizedCategory,
        createdAt: DateTime.now(),
      );

      final productId = await _firebaseService.createProduct(copiedProduct);
      final created = copiedProduct.copyWith(id: productId);
      _userProducts.insert(0, created);
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erro ao salvar produto na sua pasta';
      notifyListeners();
      return false;
    }
  }

  // Add product
  Future<bool> addProduct({
    required String name,
    required String description,
    required double price,
    String? priceDisplay,
    required String imageUrl,
    required String url,
    required String userId,
    String? category,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final product = Product(
        id: '',
        name: name,
        description: description,
        price: price,
        priceDisplay: priceDisplay,
        imageUrl: imageUrl,
        url: url,
        userId: userId,
        category: category,
        createdAt: DateTime.now(),
      );

      // Add to Firebase
      final productId = await _firebaseService.createProduct(product);

      // Optional sync with external API (disabled by default).
      if (_syncCrudWithExternalApi) {
        try {
          await _apiService.createProduct(
            name: name,
            description: description,
            price: price,
            imageUrl: imageUrl,
            url: url,
            category: category,
          );
        } catch (e) {
          debugPrint('API create product error: $e');
        }
      }

      // Add to local list
      final createdProduct = product.copyWith(id: productId);
      _products.insert(0, createdProduct);
      _userProducts.insert(0, createdProduct);

      // Tenta sincronizar lista do usuário com o estado do servidor
      // para evitar divergência de cache local.
      try {
        _userProducts = await _firebaseService.getUserProducts(userId);
      } catch (e) {
        debugPrint('Firebase refresh user products error: $e');
      }
      
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _mapDataWriteError(e, 'Erro ao adicionar produto');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Delete product
  Future<bool> deleteProduct(String productId) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Delete from Firebase
      await _firebaseService.deleteProduct(productId);

      // Optional sync with external API (disabled by default).
      if (_syncCrudWithExternalApi) {
        try {
          await _apiService.deleteProduct(productId);
        } catch (e) {
          debugPrint('API delete product error: $e');
        }
      }

      // Remove from local lists
      _products.removeWhere((p) => p.id == productId);
      _userProducts.removeWhere((p) => p.id == productId);
      
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _mapDataWriteError(e, 'Erro ao deletar produto');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Like/Unlike product
  Future<void> toggleLike(String productId, String userId) async {
    try {
      // Update Firebase
      await _firebaseService.likeProduct(productId, userId);

      // Try to update API as well
      try {
        await _apiService.likeProduct(productId);
      } catch (e) {
        debugPrint('API like product error: $e');
      }

      // Update local list
      final index = _products.indexWhere((p) => p.id == productId);
      if (index != -1) {
        final product = _products[index];
        final newLikedBy = List<String>.from(product.likedBy);
        
        if (newLikedBy.contains(userId)) {
          newLikedBy.remove(userId);
        } else {
          newLikedBy.add(userId);
        }

        _products[index] = product.copyWith(
          likedBy: newLikedBy,
          likes: newLikedBy.length,
        );
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Erro ao curtir produto';
      notifyListeners();
    }
  }

  // Search products
  Future<void> searchProducts(String query) async {
    if (query.isEmpty) {
      await loadProducts();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      List<Product> results = [];

      // Search in API
      try {
        final apiResults = await _apiService.searchProducts(query);
        results.addAll(apiResults);
      } catch (e) {
        debugPrint('API search error: $e');
      }

      // Search in Firebase
      try {
        final firebaseResults = await _firebaseService.searchProducts(query);
        
        // Merge results, avoiding duplicates
        for (var fbProduct in firebaseResults) {
          if (!results.any((p) => p.id == fbProduct.id)) {
            results.add(fbProduct);
          }
        }
      } catch (e) {
        debugPrint('Firebase search error: $e');
      }

      _products = results;
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Erro ao buscar produtos';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get product by ID
  Product? getProductById(String id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  // Filter by category
  void filterByCategory(String? category) {
    _selectedCategory = category;
    loadProducts(category: category);
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
