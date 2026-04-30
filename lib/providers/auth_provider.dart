import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  static const String _rememberMeKey = 'auth_remember_me';

  final FirebaseService _firebaseService = FirebaseService();
  final ApiService _apiService = ApiService();

  UserModel? _currentUser;
  bool _isLoading = false;
  bool _isSessionInitialized = false;
  bool _rememberMe = true;
  String? _errorMessage;
  StreamSubscription? _authSubscription;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isSessionInitialized => _isSessionInitialized;
  bool get rememberMe => _rememberMe;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;
  bool get hasActiveFirebaseSession => _firebaseService.currentUser != null;
  String? get resolvedUserId => _currentUser?.id ?? _firebaseService.currentUser?.uid;

  AuthProvider() {
    _initAuth();
  }

  Future<void> _initAuth() async {
    final prefs = await SharedPreferences.getInstance();
    _rememberMe = prefs.getBool(_rememberMeKey) ?? true;

    if (!_rememberMe && _firebaseService.currentUser != null) {
      await _firebaseService.signOut();
    }

    _authSubscription = _firebaseService.authStateChanges.listen((user) {
      if (user != null) {
        _loadUserData(user.uid);
      } else {
        _currentUser = null;
        notifyListeners();
      }
    });

    _isSessionInitialized = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData(String userId) async {
    final firebaseUser = _firebaseService.currentUser;
    try {
      final user = await _firebaseService.getUserDocument(userId);
      _currentUser = user ?? _buildFallbackUser(firebaseUser);
      notifyListeners();
    } catch (e) {
      _currentUser = _buildFallbackUser(firebaseUser);
      _errorMessage = 'Erro ao carregar dados do usuário';
      notifyListeners();
    }
  }

  UserModel? _buildFallbackUser(User? firebaseUser) {
    if (firebaseUser == null) return null;

    final email = firebaseUser.email ?? '';
    final displayName = firebaseUser.displayName?.trim();
    final name = (displayName != null && displayName.isNotEmpty) ? displayName : 'Usuário';
    final usernameFromEmail = email.contains('@') ? email.split('@').first : '';
    final username = usernameFromEmail.isNotEmpty ? usernameFromEmail : 'user_${firebaseUser.uid.substring(0, 6)}';

    return UserModel(
      id: firebaseUser.uid,
      email: email,
      name: name,
      username: username,
      photoUrl: firebaseUser.photoURL,
      createdAt: DateTime.now(),
      followingIds: const [],
    );
  }

  Future<bool> signIn(
    String email,
    String password, {
    required bool rememberMe,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _saveRememberMePreference(rememberMe);

      // Firebase login is the source of truth for app authentication.
      final credential = await _firebaseService.signInWithEmail(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        await _loadUserData(credential.user!.uid);
        // Keep API auth in background so backend instability does not block login.
        unawaited(_syncApiLogin(email: email, password: password));
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _errorMessage = 'Erro ao fazer login';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = _getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _saveRememberMePreference(bool value) async {
    _rememberMe = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, value);
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required String username,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final normalizedUsername = username
          .trim()
          .replaceAll('@', '')
          .replaceAll(RegExp(r'\s+'), '')
          .toLowerCase();

      final isAvailable = await _firebaseService.isUsernameAvailable(normalizedUsername);
      if (!isAvailable) {
        _errorMessage = 'Esse @ já está em uso. Escolha outro username.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Firebase registration is the source of truth for account creation.
      final credential = await _firebaseService.signUpWithEmail(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Create user document
        final newUser = UserModel(
          id: credential.user!.uid,
          email: email,
          name: name.trim(),
          username: normalizedUsername,
          createdAt: DateTime.now(),
        );

        try {
          await _firebaseService.createUserDocument(newUser);
        } catch (e) {
          // Prevent partially-created accounts (Auth user without user profile document).
          await credential.user!.delete();
          _errorMessage = _getErrorMessage(e);
          _isLoading = false;
          notifyListeners();
          return false;
        }

        _currentUser = newUser;
        // Keep API registration in background so backend instability does not block signup.
        unawaited(
          _syncApiRegistration(
            email: email,
            password: password,
            name: name.trim(),
            username: normalizedUsername,
          ),
        );
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _errorMessage = 'Erro ao criar conta';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = _getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Explicit Firebase account creation flow used by the create account button.
  /// Internally this triggers FirebaseAuth.createUserWithEmailAndPassword.
  Future<bool> createAccountInFirebase({
    required String email,
    required String password,
    required String name,
    required String username,
  }) async {
    return signUp(
      email: email,
      password: password,
      name: name,
      username: username,
    );
  }

  Future<bool> isUsernameAvailable(
    String username, {
    String? excludeUserId,
  }) {
    return _firebaseService.isUsernameAvailable(
      username,
      excludeUserId: excludeUserId,
    );
  }

  Future<void> signOut() async {
    try {
      await _firebaseService.signOut();
      _apiService.clearAuthToken();
      _currentUser = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Erro ao fazer logout';
      notifyListeners();
    }
  }

  Future<bool> resetPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firebaseService.resetPassword(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfile({
    String? name,
    String? username,
    String? photoUrl,
    String? bio,
  }) async {
    if (_currentUser == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final currentUser = _currentUser!;
      final updates = <String, dynamic>{};
      final trimmedName = name?.trim();
      if (trimmedName != null && trimmedName != currentUser.name) {
        updates['name'] = trimmedName;
      }
      if (username != null) {
        final normalizedUsername = username
            .trim()
            .replaceAll('@', '')
            .replaceAll(RegExp(r'\s+'), '')
            .toLowerCase();

        if (normalizedUsername != currentUser.username) {
          final isAvailable = await _firebaseService.isUsernameAvailable(
            normalizedUsername,
            excludeUserId: currentUser.id,
          );
          if (!isAvailable) {
            _errorMessage = 'Esse @ já está em uso. Escolha outro username.';
            _isLoading = false;
            notifyListeners();
            return false;
          }
          updates['username'] = normalizedUsername;
        }
      }
      if (photoUrl != null) updates['photoUrl'] = photoUrl;
      if (bio != null && bio != currentUser.bio) updates['bio'] = bio;

      if (updates.isNotEmpty) {
        await _firebaseService.updateUserDocument(
          currentUser.id,
          updates,
          previousNormalizedUsername: currentUser.username,
        );
      }

      // Try to update in API as well
      try {
        await _apiService.updateUserProfile(
          userId: currentUser.id,
          name: updates['name'] as String?,
          username: updates['username'] as String?,
          photoUrl: photoUrl,
          bio: bio,
        );
      } catch (e) {
        debugPrint('API update profile error: $e');
      }

      _currentUser = currentUser.copyWith(
        name: updates['name'] as String?,
        username: updates['username'] as String?,
        photoUrl: photoUrl,
        bio: bio,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<List<UserModel>> searchUsersToFollow(String query) async {
    final currentUser = _currentUser;
    if (currentUser == null) return [];

    try {
      return await _firebaseService.searchUsers(
        query: query,
        excludeUserId: currentUser.id,
      );
    } catch (e) {
      _errorMessage = 'Erro ao buscar usuários';
      notifyListeners();
      return [];
    }
  }

  Future<bool> toggleFollowUser(UserModel targetUser) async {
    final currentUser = _currentUser;
    if (currentUser == null) return false;

    try {
      final followingSet = currentUser.followingIds.toSet();
      final isFollowing = followingSet.contains(targetUser.id);

      if (isFollowing) {
        await _firebaseService.unfollowUser(
          currentUserId: currentUser.id,
          targetUserId: targetUser.id,
        );
        followingSet.remove(targetUser.id);
      } else {
        await _firebaseService.followUser(
          currentUserId: currentUser.id,
          targetUserId: targetUser.id,
        );
        followingSet.add(targetUser.id);
      }

      _currentUser = currentUser.copyWith(
        followingIds: followingSet.toList(),
      );
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erro ao atualizar usuários seguidos';
      notifyListeners();
      return false;
    }
  }

  String _getErrorMessage(Object error) {
    if (error is FirebaseAuthException) {
      return _mapFirebaseAuthCode(error.code);
    }
    if (error is FirebaseException) {
      return _mapFirebaseCoreCode(error.code);
    }

    final errorText = error.toString();
    final firebaseAuthCodeMatch = RegExp(r'\[firebase_auth\/([^\]]+)\]').firstMatch(errorText);
    if (firebaseAuthCodeMatch != null) {
      return _mapFirebaseAuthCode(firebaseAuthCodeMatch.group(1)!);
    }
    final firestoreCodeMatch = RegExp(r'\[cloud_firestore\/([^\]]+)\]').firstMatch(errorText);
    if (firestoreCodeMatch != null) {
      return _mapFirebaseCoreCode(firestoreCodeMatch.group(1)!);
    }

    if (errorText.contains('username_taken')) {
      return 'Esse @ já está em uso. Escolha outro username.';
    }

    if (errorText.contains('user-not-found')) {
      return 'Usuário não encontrado';
    } else if (errorText.contains('wrong-password')) {
      return 'Senha incorreta';
    } else if (errorText.contains('email-already-in-use')) {
      return 'Email já está em uso';
    } else if (errorText.contains('invalid-email')) {
      return 'Email inválido';
    } else if (errorText.contains('weak-password')) {
      return 'Senha muito fraca';
    } else if (errorText.contains('network-request-failed')) {
      return 'Erro de conexão';
    } else if (errorText.contains('operation-not-allowed')) {
      return 'Cadastro por email/senha não está habilitado no Firebase';
    } else if (errorText.contains('permission-denied')) {
      return 'Sem permissão para salvar dados do usuário';
    } else if (errorText.contains('too-many-requests')) {
      return 'Muitas tentativas. Tente novamente em alguns minutos';
    } else if (errorText.contains('invalid-credential')) {
      return 'Credenciais inválidas';
    } else if (errorText.contains('channel-error')) {
      return 'Falha de configuração do Firebase no app';
    } else if (errorText.contains('invalid-api-key')) {
      return 'Chave do Firebase inválida';
    }
    final sanitized = errorText
        .replaceAll('Exception:', '')
        .trim();
    if (sanitized.isNotEmpty) {
      return sanitized;
    }
    return 'Não foi possível criar a conta. Verifique a configuração do Firebase.';
  }

  String _mapFirebaseAuthCode(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Usuário não encontrado';
      case 'wrong-password':
        return 'Senha incorreta';
      case 'email-already-in-use':
        return 'Email já está em uso';
      case 'invalid-email':
        return 'Email inválido';
      case 'weak-password':
        return 'Senha muito fraca';
      case 'network-request-failed':
        return 'Erro de conexão';
      case 'operation-not-allowed':
        return 'Cadastro por email/senha não está habilitado no Firebase';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente novamente em alguns minutos';
      case 'invalid-credential':
        return 'Credenciais inválidas';
      case 'invalid-api-key':
        return 'Chave do Firebase inválida';
      case 'channel-error':
        return 'Falha de configuração do Firebase no app';
      default:
        return 'Erro de autenticação: $code';
    }
  }

  String _mapFirebaseCoreCode(String code) {
    switch (code) {
      case 'permission-denied':
        return 'Sem permissão para salvar dados do usuário';
      case 'unavailable':
        return 'Serviço indisponível no momento';
      default:
        return 'Erro de banco de dados: $code';
    }
  }

  Future<void> _syncApiLogin({
    required String email,
    required String password,
  }) async {
    try {
      final apiResponse = await _apiService.login(email, password);
      if (apiResponse['token'] != null) {
        _apiService.setAuthToken(apiResponse['token']);
      }
    } catch (e) {
      debugPrint('API login error: $e');
    }
  }

  Future<void> _syncApiRegistration({
    required String email,
    required String password,
    required String name,
    required String username,
  }) async {
    try {
      final apiResponse = await _apiService.register(
        email: email,
        password: password,
        name: name,
        username: username,
      );
      if (apiResponse['token'] != null) {
        _apiService.setAuthToken(apiResponse['token']);
      }
    } catch (e) {
      debugPrint('API registration error: $e');
    }
  }
}
