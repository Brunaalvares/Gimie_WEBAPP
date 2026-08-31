import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
// Conditional import for web
import 'dart:html' as html if (dart.library.io) 'dart:io';

/// Serviço para detectar e gerenciar acesso via links compartilhados
class SharedLinkService {
  static final SharedLinkService _instance = SharedLinkService._internal();
  static SharedLinkService get instance => _instance;

  SharedLinkService._internal();

  bool _isSharedAccess = false;
  String? _sharedFolderId;
  String? _sharedUserId;

  /// Verifica se o acesso atual é através de um link compartilhado
  bool get isSharedAccess => _isSharedAccess;

  /// ID da pasta compartilhada (se aplicável)
  String? get sharedFolderId => _sharedFolderId;

  /// ID do usuário que compartilhou (se aplicável)
  String? get sharedUserId => _sharedUserId;

  /// Inicializa o serviço verificando query parameters na URL
  void initialize() {
    if (!kIsWeb) {
      _isSharedAccess = false;
      return;
    }

    try {
      final uri = Uri.parse(html.window.location.href);
      
      // Verifica se existe o parâmetro 'shared' ou 'from'
      final isShared = uri.queryParameters.containsKey('shared') || 
                       uri.queryParameters.containsKey('from');
      
      if (isShared) {
        _isSharedAccess = true;
        _sharedFolderId = uri.queryParameters['folder'];
        _sharedUserId = uri.queryParameters['user'] ?? uri.queryParameters['from'];
        
        _debugPrint('Shared link detected - Folder: $_sharedFolderId, User: $_sharedUserId');
      } else {
        _isSharedAccess = false;
      }
    } catch (e) {
      _debugPrint('Error initializing SharedLinkService: $e');
      _isSharedAccess = false;
    }
  }

  /// Marca manualmente como acesso compartilhado (útil para testes ou deep links)
  void setSharedAccess({
    required bool isShared,
    String? folderId,
    String? userId,
  }) {
    _isSharedAccess = isShared;
    _sharedFolderId = folderId;
    _sharedUserId = userId;
  }

  /// Limpa o estado de acesso compartilhado
  void clear() {
    _isSharedAccess = false;
    _sharedFolderId = null;
    _sharedUserId = null;
  }

  /// Retorna a URL atual com os parâmetros de compartilhamento
  String getCurrentShareUrl() {
    if (!kIsWeb) return '';
    return html.window.location.href;
  }

  /// Gera uma URL de compartilhamento para uma pasta
  String generateShareUrl({
    required String userId,
    required String folderName,
    String? baseUrl,
  }) {
    try {
      debugPrint('=== generateShareUrl START ===');
      debugPrint('userId: "$userId"');
      debugPrint('folderName: "$folderName"');
      
      // SEMPRE usar URL fixa para garantir que funciona
      String base = 'https://gimie-launch.web.app';
      
      // Tentar pegar origin apenas se estiver em produção
      if (kIsWeb && baseUrl == null) {
        try {
          final origin = html.window.location.origin;
          if (origin.isNotEmpty && 
              !origin.contains('localhost') && 
              !origin.contains('127.0.0.1')) {
            base = origin;
            debugPrint('Using window origin: $origin');
          } else {
            debugPrint('Localhost detected, using fixed URL');
          }
        } catch (e) {
          debugPrint('Could not get window origin: $e, using fixed URL');
        }
      } else if (baseUrl != null && baseUrl.isNotEmpty) {
        base = baseUrl;
        debugPrint('Using provided baseUrl: $baseUrl');
      }
      
      debugPrint('Final base URL: $base');
      
      // Encode com segurança
      String encodedFolder = folderName;
      String encodedUser = userId;
      
      try {
        encodedFolder = Uri.encodeComponent(folderName);
      } catch (e) {
        debugPrint('Error encoding folder, using fallback: $e');
        encodedFolder = folderName.replaceAll(' ', '%20')
                                  .replaceAll('#', '%23')
                                  .replaceAll('&', '%26');
      }
      
      try {
        encodedUser = Uri.encodeComponent(userId);
      } catch (e) {
        debugPrint('Error encoding user, using fallback: $e');
        encodedUser = userId.replaceAll(' ', '%20')
                           .replaceAll('#', '%23')
                           .replaceAll('&', '%26');
      }
      
      final url = '$base/?shared=true&folder=$encodedFolder&user=$encodedUser';
      debugPrint('=== FINAL URL: $url ===');
      
      return url;
    } catch (e, stack) {
      debugPrint('=== CRITICAL ERROR ===');
      debugPrint('Error: $e');
      debugPrint('Stack: $stack');
      
      // FALLBACK: retornar URL básica válida
      final safeUrl = 'https://gimie-launch.web.app/?shared=true&folder=${folderName.replaceAll(' ', '_')}&user=error';
      debugPrint('Returning fallback URL: $safeUrl');
      return safeUrl;
    }
  }
}

// Custom debug print for web
void _debugPrint(String message) {
  if (kIsWeb) {
    // ignore: avoid_print
    print('[SharedLinkService] $message');
  }
}
