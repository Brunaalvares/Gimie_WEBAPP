import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import '../widgets/app_download_modal.dart';
import 'login_screen.dart';

/// Página pública de uma pasta compartilhada.
///
/// É o destino de quem abre um link de compartilhamento. Mostra os produtos da
/// pasta sem exigir login, mas qualquer tentativa de abrir um produto passa
/// pela barreira de download do app.
class SharedFolderScreen extends StatefulWidget {
  final String ownerId;
  final String folderName;

  const SharedFolderScreen({
    super.key,
    required this.ownerId,
    required this.folderName,
  });

  @override
  State<SharedFolderScreen> createState() => _SharedFolderScreenState();
}

class _SharedFolderScreenState extends State<SharedFolderScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  List<Product> _products = [];
  UserModel? _owner;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFolder();
  }

  Future<void> _loadFolder() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final allProducts = await _firebaseService.getUserProducts(widget.ownerId);

      final normalizedTarget = widget.folderName.trim().toLowerCase();
      final folderProducts = allProducts.where((product) {
        final category = (product.category ?? '').trim().toLowerCase();
        return category == normalizedTarget;
      }).toList();

      // O dono é complementar: se falhar, a pasta ainda é exibida.
      UserModel? owner;
      try {
        owner = await _firebaseService.getUserDocument(widget.ownerId);
      } catch (e) {
        debugPrint('Could not load folder owner: $e');
      }

      if (!mounted) return;
      setState(() {
        _products = folderProducts;
        _owner = owner;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading shared folder: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Não foi possível carregar esta pasta';
      });
    }
  }

  Future<void> _handleShopNow(Product product) async {
    await AppDownloadModal.show(context, productUrl: product.url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.white,
            elevation: 2,
            automaticallyImplyLeading: false,
            expandedHeight: 160,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeaderContent(),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderContent() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: const Color(0xFF8B7FB8),
                backgroundImage: _owner?.photoUrl != null && _owner!.photoUrl!.isNotEmpty
                    ? NetworkImage(_owner!.photoUrl!)
                    : null,
                child: _owner?.photoUrl == null || _owner!.photoUrl!.isEmpty
                    ? Text(
                        _getInitials(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 20,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.folderName,
                      style: const TextStyle(
                        fontFamily: 'Raleway',
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        color: Color(0xFF6B2C5C),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getUsernameDisplay(),
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 14,
                        color: Color(0xFF8B7FB8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => AppDownloadModal.show(context, productUrl: ''),
                  icon: const Icon(Icons.download, size: 20),
                  label: const Text('Baixar Gimie'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B7FB8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _goToLogin,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  side: const BorderSide(color: Color(0xFF8B7FB8)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Entrar',
                  style: TextStyle(
                    color: Color(0xFF8B7FB8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getInitials() {
    final owner = _owner;
    if (owner == null) return '?';
    
    final name = owner.name.trim();
    if (name.isNotEmpty) {
      final parts = name.split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return name[0].toUpperCase();
    }
    
    final username = owner.username.trim();
    if (username.isNotEmpty) {
      return username[0].toUpperCase();
    }
    
    return '?';
  }

  String _getUsernameDisplay() {
    final owner = _owner;
    if (owner == null) return 'Pasta compartilhada';
    
    final username = owner.username.trim();
    if (username.isNotEmpty) {
      return '@$username';
    }
    
    final name = owner.name.trim();
    if (name.isNotEmpty) {
      return name;
    }
    
    return 'Pasta compartilhada';
  }

  /// Quem já tem conta entra direto. Como a pasta ficou salva como pendente,
  /// o app reabre ela automaticamente depois do login.
  void _goToLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const SizedBox(
        height: 300,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF8B7FB8)),
        ),
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Roboto', color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFolder,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    if (_products.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                'Esta pasta ainda não tem produtos',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Roboto', color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.72,
      ),
      itemCount: _products.length,
      itemBuilder: (context, index) => _buildProductCard(_products[index]),
    );
  }

  Widget _buildProductCard(Product product) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFEFEFEF),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                image: product.imageUrl.isEmpty
                    ? null
                    : DecorationImage(
                        image: NetworkImage(product.imageUrl),
                        fit: BoxFit.cover,
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Raleway',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  product.formattedPrice,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    color: Color(0xFF8B7FB8),
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _handleShopNow(product),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B7FB8),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text('Shop Now'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
