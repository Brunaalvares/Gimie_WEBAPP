import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/product_provider.dart';
import '../models/product_model.dart';
import '../services/shared_link_service.dart';
import '../widgets/app_download_modal.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _loadedFeedForUserId;
  String _loadedFollowingKey = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadFollowingFeedIfNeeded();
      }
    });
  }

  Future<void> _loadFollowingFeedIfNeeded() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (user == null) return;

    final followingKey = (user.followingIds.toList()..sort()).join('|');
    final alreadyLoadedForSameState =
        _loadedFeedForUserId == user.id && _loadedFollowingKey == followingKey;
    if (alreadyLoadedForSameState) return;

    _loadedFeedForUserId = user.id;
    _loadedFollowingKey = followingKey;
    await productProvider.loadFollowingFeed(
      currentUserId: user.id,
      followingIds: user.followingIds,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gimie',
          style: TextStyle(
            fontFamily: 'Raleway',
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B2C5C),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Consumer2<AuthProvider, ProductProvider>(
        builder: (context, authProvider, productProvider, _) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _loadFollowingFeedIfNeeded();
            }
          });

          if (productProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = authProvider.currentUser;
          if (user == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final feedProducts = productProvider.products
              .where((product) => product.userId != user.id)
              .toList();

          if (user.followingIds.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  'Seu feed aparece aqui com os últimos produtos de quem você segue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ),
            );
          }

          if (feedProducts.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.card_giftcard_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Sem novidades por enquanto',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.66,
            ),
            itemCount: feedProducts.length,
            itemBuilder: (context, index) {
              final product = feedProducts[index];
              return _ProductCard(product: product);
            },
          );
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;

  const _ProductCard({required this.product});

  Uri? _buildProductUri() {
    final raw = product.url.trim();
    if (raw.isEmpty) return null;

    final normalized = raw.replaceAll(' ', '%20');
    final parsed = Uri.tryParse(normalized);
    if (parsed != null && parsed.hasScheme) {
      return parsed;
    }

    return Uri.tryParse('https://$normalized');
  }

  Future<void> _openProductLink(BuildContext context) async {
    final uri = _buildProductUri();
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link do produto indisponível')),
      );
      return;
    }

    // Verifica se o acesso é via link compartilhado
    final sharedLinkService = SharedLinkService.instance;
    if (sharedLinkService.isSharedAccess) {
      // Mostra o modal de download do app
      if (context.mounted) {
        await AppDownloadModal.show(
          context,
          productUrl: product.url,
        );
      }
      return;
    }

    // Se não for acesso compartilhado, abre normalmente
    try {
      final externalOpened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (externalOpened) return;

      final inAppOpened = await launchUrl(
        uri,
        mode: LaunchMode.inAppBrowserView,
      );
      if (inAppOpened) return;
    } catch (_) {
      // handled below with user feedback
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir este link')),
      );
    }
  }

  Future<void> _saveToMyFolder(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final currentUserId = authProvider.resolvedUserId;
    if (currentUserId == null || currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Faça login para salvar produtos'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await productProvider.loadUserProducts(currentUserId);
      if (!context.mounted) return;

      final existingCategories = productProvider.userProducts
          .map((p) => (p.category ?? '').trim())
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      String? selectedCategory =
          existingCategories.isNotEmpty ? existingCategories.first : null;
      final newCategoryController = TextEditingController();

      final targetCategory = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Salvar na minha pasta'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (existingCategories.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        decoration: const InputDecoration(labelText: 'Escolha uma pasta'),
                        items: existingCategories
                            .map(
                              (category) => DropdownMenuItem<String>(
                                value: category,
                                child: Text(category),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedCategory = value;
                          });
                        },
                      ),
                    if (existingCategories.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('ou'),
                      ),
                    TextField(
                      controller: newCategoryController,
                      decoration: const InputDecoration(
                        labelText: 'Nova pasta',
                        hintText: 'Ex: Favoritos',
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () {
                      final typed = newCategoryController.text.trim();
                      final finalCategory =
                          typed.isNotEmpty ? typed : (selectedCategory ?? '');
                      Navigator.of(dialogContext).pop(
                        finalCategory.isEmpty ? null : finalCategory,
                      );
                    },
                    child: const Text('Salvar'),
                  ),
                ],
              );
            },
          );
        },
      );

      newCategoryController.dispose();
      if (targetCategory == null || targetCategory.trim().isEmpty) return;

      final success = await productProvider.saveProductFromOtherUser(
        sourceProduct: product,
        currentUserId: currentUserId,
        targetCategory: targetCategory,
      );
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Produto salvo em "$targetCategory"'
                : (productProvider.errorMessage ?? 'Não foi possível salvar o produto'),
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Houve uma falha ao concluir esta ação. Tente novamente.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                image: DecorationImage(
                  image: NetworkImage(product.imageUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Raleway',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF191919),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => _saveToMyFolder(context),
                      child: const Icon(
                        Icons.favorite_border,
                        size: 18,
                        color: Color(0xFF8B7FB8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  product.formattedPrice,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    color: Color(0xFF8B7FB8),
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _openProductLink(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B7FB8),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Shop Now',
                      style: TextStyle(
                        fontFamily: 'Raleway',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
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
