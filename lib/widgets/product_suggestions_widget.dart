import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../services/api_service.dart';
import '../utils/debug_helper.dart';

class ProductSuggestionsWidget extends StatefulWidget {
  final String category;
  final Function(Product) onProductSelected;

  const ProductSuggestionsWidget({
    super.key,
    required this.category,
    required this.onProductSelected,
  });

  @override
  State<ProductSuggestionsWidget> createState() => _ProductSuggestionsWidgetState();
}

class _ProductSuggestionsWidgetState extends State<ProductSuggestionsWidget> {
  List<Product> _suggestions = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  @override
  void didUpdateWidget(ProductSuggestionsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category) {
      _loadSuggestions();
    }
  }

  Future<void> _loadSuggestions() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      DebugHelper.log('Loading suggestions for category: ${widget.category}', 'SUGGESTIONS');
      
      final apiService = ApiService();
      final suggestions = await apiService.getSuggestedProducts(widget.category);

      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _isLoading = false;
        });
        
        DebugHelper.log('Loaded ${suggestions.length} suggestions', 'SUGGESTIONS');
      }
    } catch (e) {
      DebugHelper.logError('Failed to load suggestions', e);
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 8),
              Text('Carregando sugestões...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.error_outline, color: Colors.orange),
              const SizedBox(height: 8),
              const Text('Erro ao carregar sugestões'),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loadSuggestions,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (_suggestions.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.grey),
              SizedBox(height: 8),
              Text(
                'Nenhuma sugestão disponível para esta categoria',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Sugestões para ${widget.category}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final product = _suggestions[index];
                  return _SuggestionCard(
                    product: product,
                    onTap: () => widget.onProductSelected(product),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _SuggestionCard({
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                child: product.imageUrl.isNotEmpty
                    ? Image.network(
                        product.imageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.image_not_supported),
                          );
                        },
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.shopping_bag),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'R\$ ${product.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 9,
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}