import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/product_model.dart';
import '../providers/auth_provider.dart';
import '../providers/product_provider.dart';
import 'add_product_screen.dart';

class FolderProductsScreen extends StatefulWidget {
  final String categoryName;
  final List<Product> products;
  final bool allowDelete;
  final Future<bool> Function(Product product)? onDeleteProduct;

  const FolderProductsScreen({
    super.key,
    required this.categoryName,
    required this.products,
    this.allowDelete = false,
    this.onDeleteProduct,
  });

  @override
  State<FolderProductsScreen> createState() => _FolderProductsScreenState();
}

class _FolderProductsScreenState extends State<FolderProductsScreen> {
  late List<Product> _visibleProducts;

  @override
  void initState() {
    super.initState();
    _visibleProducts = List<Product>.from(widget.products);
  }

  Uri? _buildProductUri(String rawUrl) {
    final raw = rawUrl.trim();
    if (raw.isEmpty) return null;

    final normalized = raw.replaceAll(' ', '%20');
    final parsed = Uri.tryParse(normalized);
    if (parsed != null && parsed.hasScheme) {
      return parsed;
    }

    return Uri.tryParse('https://$normalized');
  }

  Future<void> _openProductLink(BuildContext context, String url) async {
    final uri = _buildProductUri(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link do produto indisponível')),
      );
      return;
    }

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

  Future<void> _saveToMyFolder(BuildContext context, Product product) async {
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
                        decoration: const InputDecoration(
                          labelText: 'Escolha uma pasta',
                        ),
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

  Future<void> _deleteProduct(BuildContext context, Product product) async {
    if (widget.onDeleteProduct == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir produto'),
        content: const Text('Deseja remover este produto desta pasta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    bool success = false;
    try {
      success = await widget.onDeleteProduct!(product);
    } catch (_) {
      success = false;
    }
    if (!context.mounted) return;

    if (success) {
      setState(() {
        _visibleProducts.removeWhere((p) => p.id == product.id);
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Produto excluído com sucesso'
              : (Provider.of<ProductProvider>(
                    context,
                    listen: false,
                  ).errorMessage ??
                  'Não foi possível excluir o produto'),
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _openAddProductForFolder() async {
    if (!widget.allowDelete) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddProductScreen(initialCategory: widget.categoryName),
      ),
    );
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final userId = authProvider.resolvedUserId;
    if (userId == null || userId.isEmpty) return;

    await productProvider.loadUserProducts(userId);
    if (!mounted) return;

    final refreshed = productProvider.userProducts
        .where(
          (product) =>
              (product.category ?? '').trim().toLowerCase() ==
              widget.categoryName.trim().toLowerCase(),
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    setState(() {
      _visibleProducts = refreshed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.categoryName,
          style: const TextStyle(
            fontFamily: 'Raleway',
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B2C5C),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: widget.allowDelete
          ? FloatingActionButton.extended(
              onPressed: _openAddProductForFolder,
              backgroundColor: const Color(0xFF8B7FB8),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar produto'),
            )
          : null,
      body: _visibleProducts.isEmpty
          ? const Center(
              child: Text(
                'Nenhum produto nesta pasta',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  color: Colors.grey,
                ),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.72,
              ),
              itemCount: _visibleProducts.length,
              itemBuilder: (context, index) {
                final product = _visibleProducts[index];
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
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            image: DecorationImage(
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
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                if (widget.allowDelete)
                                  InkWell(
                                    onTap: () => _deleteProduct(context, product),
                                    child: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: Colors.redAccent,
                                    ),
                                  )
                                else
                                  InkWell(
                                    onTap: () => _saveToMyFolder(context, product),
                                    child: const Icon(
                                      Icons.favorite_border,
                                      size: 18,
                                      color: Color(0xFF8B7FB8),
                                    ),
                                  ),
                              ],
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
                                onPressed: () => _openProductLink(context, product.url),
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
              },
            ),
    );
  }
}
