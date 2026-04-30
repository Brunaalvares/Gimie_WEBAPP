import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../providers/auth_provider.dart';
import '../services/share_service.dart';
import '../services/api_service.dart';
import '../services/scraping_service.dart';
import '../utils/debug_helper.dart';
import 'package:url_launcher/url_launcher.dart';

class AddProductScreen extends StatefulWidget {
  final String? initialCategory;

  const AddProductScreen({
    super.key,
    this.initialCategory,
  });

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _urlController = TextEditingController();
  final _newCategoryController = TextEditingController();

  bool _isScrapingUrl = false;
  bool _showScrapingPreview = false;
  bool _awaitingShareFolderSelection = false;
  bool _isAutoSavingFromShare = false;
  String? _selectedCategory;
  ScrapedProductData? _scrapedData;

  final List<String> _categories = [];
  static const String _fallbackImageUrl =
      'https://via.placeholder.com/600x600.png?text=Gimie';

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null && widget.initialCategory!.trim().isNotEmpty) {
      _selectedCategory = widget.initialCategory!.trim();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadExistingUserCategories();
      }
    });
    _checkForSharedContent();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _urlController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }

  void _addCategory() {
    final category = _newCategoryController.text.trim();
    if (category.isEmpty) return;

    final exists = _categories.any(
      (existing) => existing.toLowerCase() == category.toLowerCase(),
    );
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Essa categoria já existe'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _categories.insert(0, category);
      _selectedCategory = category;
      _newCategoryController.clear();
    });

    _tryAutoSaveAfterFolderSelection();
  }

  Future<void> _loadExistingUserCategories() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final userId = authProvider.resolvedUserId;
    if (userId == null || userId.isEmpty) return;

    await productProvider.loadUserProducts(userId);
    if (!mounted) return;

    final categories = productProvider.userProducts
        .map((p) => (p.category ?? '').trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    setState(() {
      _categories
        ..clear()
        ..addAll(categories);

      if (_selectedCategory == null || _selectedCategory!.trim().isEmpty) {
        if (widget.initialCategory != null && widget.initialCategory!.trim().isNotEmpty) {
          _selectedCategory = widget.initialCategory!.trim();
        } else if (_categories.isNotEmpty) {
          _selectedCategory = _categories.first;
        }
      } else if (!_categories.any(
        (c) => c.toLowerCase() == _selectedCategory!.toLowerCase(),
      )) {
        _categories.insert(0, _selectedCategory!);
      }
    });
  }

  void _applyNewCategoryFromInput() {
    final typedCategory = _newCategoryController.text.trim();
    if (typedCategory.isEmpty) return;

    final existingIndex = _categories.indexWhere(
      (category) => category.toLowerCase() == typedCategory.toLowerCase(),
    );

    setState(() {
      if (existingIndex >= 0) {
        _selectedCategory = _categories[existingIndex];
      } else {
        _categories.insert(0, typedCategory);
        _selectedCategory = typedCategory;
      }
      _newCategoryController.clear();
    });
  }

  Future<void> _checkForSharedContent() async {
    try {
      final sharedContent = await ShareService.instance.getSharedContent();
      
      if (sharedContent != null && mounted) {
        String? sharedUrl;
        setState(() {
          if (sharedContent['text'] != null) {
            final text = sharedContent['text'] as String;
            if (text.trim().isNotEmpty) {
              _descriptionController.text = text;
            }
          }
          
          if (sharedContent['url'] != null) {
            final url = sharedContent['url'] as String;
            if (url.trim().isNotEmpty) {
              _urlController.text = url;
              sharedUrl = url;
            }
          }
          
        });
        
        // Limpa o conteúdo compartilhado após usar
        await ShareService.instance.clearSharedContent();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Conteúdo compartilhado carregado! Selecione a pasta para salvar.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }

        if (sharedUrl != null && sharedUrl!.isNotEmpty && mounted) {
          setState(() {
            _awaitingShareFolderSelection = true;
          });
          await _scrapeUrlData();
        }
      }
    } catch (e) {
      DebugHelper.logError('Erro ao verificar conteúdo compartilhado', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao carregar conteúdo compartilhado'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!mounted) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.resolvedUserId;
      
      if (userId == null || userId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuário não está logado'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Validação adicional dos campos
      final url = _normalizeProductUrl(_urlController.text);

      if (url.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preencha a URL do produto'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      _applyNewCategoryFromInput();

      if (_selectedCategory == null || _selectedCategory!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Crie ou selecione uma pasta/categoria'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final shouldRescrape = _scrapedData == null ||
          (_scrapedData?.sourceUrl.isNotEmpty == true && _scrapedData!.sourceUrl != url);
      if (shouldRescrape) {
        await _scrapeUrlData();
      }
      if (!mounted) return;

      final scraped = _scrapedData;
      final finalName = (scraped?.title?.trim().isNotEmpty ?? false)
          ? scraped!.title!.trim()
          : _buildFallbackNameFromUrl(url);
      final finalPrice = scraped?.price ?? 0.0;
      var finalPriceDisplay = scraped?.priceDisplay?.trim();
      final finalImage = (scraped?.imageUrl?.trim().isNotEmpty ?? false)
          ? scraped!.imageUrl!.trim()
          : _fallbackImageUrl;
      final safeDescription = (scraped?.description?.trim().isNotEmpty == true)
          ? scraped!.description!.trim()
          : 'Produto adicionado via link.';

      if (finalPrice <= 0 && (finalPriceDisplay == null || finalPriceDisplay.isEmpty)) {
        finalPriceDisplay = 'Preço indisponível';
      }

      if (!mounted) return;
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      final success = await productProvider.addProduct(
        name: finalName,
        description: safeDescription,
        price: finalPrice,
        priceDisplay: finalPriceDisplay,
        imageUrl: finalImage,
        url: url,
        userId: userId,
        category: _selectedCategory,
      );

      if (!mounted) return;

      if (success) {
        await productProvider.loadUserProducts(userId);
        if (!mounted) return;
        await _loadExistingUserCategories();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (scraped?.title?.trim().isEmpty ?? true) ||
                      (scraped?.price == null || scraped!.price! <= 0) ||
                      (scraped.imageUrl?.trim().isEmpty ?? true)
                  ? 'Produto adicionado com dados parciais da URL'
                  : 'Produto adicionado com sucesso!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              productProvider.errorMessage ?? 'Erro ao adicionar produto',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      DebugHelper.logError('Erro ao adicionar produto', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao adicionar produto: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _tryAutoSaveAfterFolderSelection() async {
    if (!_awaitingShareFolderSelection || _isAutoSavingFromShare) return;
    if (_selectedCategory == null || _selectedCategory!.trim().isEmpty) return;

    final provider = Provider.of<ProductProvider>(context, listen: false);
    if (provider.isLoading) return;

    _awaitingShareFolderSelection = false;
    _isAutoSavingFromShare = true;
    try {
      await _handleSubmit();
    } finally {
      _isAutoSavingFromShare = false;
    }
  }

  /// Faz scraping de dados da URL inserida
  Future<void> _scrapeUrlData() async {
    final url = _normalizeProductUrl(_urlController.text);
    
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, insira uma URL primeiro'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      _isScrapingUrl = true;
      _scrapedData = null;
      _showScrapingPreview = false;
    });

    try {
      _urlController.text = url;
      DebugHelper.log('Starting URL scraping for: $url', 'ADD_PRODUCT');
      
      final apiService = ApiService();
      final scrapedData = await apiService.previewProductFromUrl(url);

      if (!mounted) return;

      if (scrapedData != null) {
        final safeScrapedData = _sanitizeScrapedData(scrapedData, url);
        setState(() {
          _scrapedData = safeScrapedData;
          _showScrapingPreview = true;

          if (safeScrapedData.title != null) {
            _nameController.text = safeScrapedData.title!;
          }
          if (safeScrapedData.description != null &&
              safeScrapedData.description!.trim().isNotEmpty) {
            _descriptionController.text = safeScrapedData.description!;
          }
          if (safeScrapedData.price != null) {
            _priceController.text = safeScrapedData.price!.toStringAsFixed(2);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (safeScrapedData.title != null ||
                      safeScrapedData.price != null ||
                      (safeScrapedData.imageUrl?.isNotEmpty ?? false))
                  ? 'Dados extraídos com sucesso!'
                  : 'Link recebido, mas sem dados confiáveis; usando fallback',
            ),
            backgroundColor:
                (safeScrapedData.title != null ||
                        safeScrapedData.price != null ||
                        (safeScrapedData.imageUrl?.isNotEmpty ?? false))
                    ? Colors.green
                    : Colors.orange,
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não foi possível extrair dados desta URL'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      DebugHelper.logError('URL scraping failed', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao extrair dados: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScrapingUrl = false;
        });
      }
    }
  }

  /// Descarta dados scraped
  void _discardScrapedData() {
    setState(() {
      _scrapedData = null;
      _showScrapingPreview = false;
    });
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

  String _normalizeProductUrl(String rawUrl) {
    var normalized = rawUrl.trim();
    if (normalized.isEmpty) return normalized;

    if (!normalized.startsWith(RegExp(r'https?://', caseSensitive: false))) {
      normalized = 'https://$normalized';
    }

    normalized = normalized.replaceAll('+', '%20');

    try {
      // Avoid %20 becoming %2520 on repeated normalization.
      final decoded = Uri.decodeFull(normalized);
      return Uri.encodeFull(decoded).replaceAll('+', '%20');
    } catch (_) {
      return normalized.replaceAll(' ', '%20');
    }
  }

  ScrapedProductData _sanitizeScrapedData(
    ScrapedProductData data,
    String normalizedUrl,
  ) {
    final cleanedTitle =
        _isLikelyGenericTitle(data.title) ? null : data.title?.trim();
    final cleanedImage = _isValidHttpUrl(data.imageUrl) ? data.imageUrl?.trim() : null;
    final cleanedPrice = (data.price != null && data.price! > 0) ? data.price : null;
    final cleanedPriceDisplay =
        (data.priceDisplay != null && data.priceDisplay!.trim().isNotEmpty)
            ? data.priceDisplay!.trim()
            : null;

    return ScrapedProductData(
      title: cleanedTitle,
      description: data.description?.trim(),
      price: cleanedPrice,
      priceDisplay: cleanedPriceDisplay,
      imageUrl: cleanedImage,
      sourceUrl: normalizedUrl,
      additionalImages: data.additionalImages,
      metadata: data.metadata,
      scrapedAt: data.scrapedAt,
    );
  }

  bool _isLikelyGenericTitle(String? title) {
    final value = title?.trim().toLowerCase() ?? '';
    if (value.isEmpty) return true;

    const genericMarkers = [
      'resultado da busca',
      'resultados da busca',
      'search result',
      'search results',
      'buscar',
      'pesquisa',
      'catálogo',
      'catalogo',
      'coleção',
      'colecao',
      'home',
      'início',
      'inicio',
    ];

    if (value.contains('%20') || value.contains('%2520')) return true;
    return genericMarkers.any(value.contains);
  }

  bool _isValidHttpUrl(String? value) {
    var raw = value?.trim();
    if (raw == null || raw.isEmpty) return false;
    if (raw.startsWith('//')) raw = 'https:$raw';
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  String _buildFallbackNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final slug = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      final cleaned = slug
          .replaceAll(RegExp(r'\.html?$'), '')
          .replaceAll(RegExp(r'[-_]+'), ' ')
          .replaceAll(RegExp(r'%20'), ' ')
          .trim();
      if (cleaned.isNotEmpty) {
        final words = cleaned
            .split(' ')
            .where((word) => word.trim().isNotEmpty)
            .map(
              (word) => word.length > 1
                  ? '${word[0].toUpperCase()}${word.substring(1)}'
                  : word.toUpperCase(),
            )
            .toList();
        if (words.isNotEmpty) return words.join(' ');
      }
      return uri.host.replaceFirst('www.', '').trim();
    } catch (_) {
      return 'Produto sem nome';
    }
  }

  Future<void> _openProductLink() async {
    final targetUrl =
        _scrapedData?.sourceUrl.trim().isNotEmpty == true
            ? _scrapedData!.sourceUrl
            : _urlController.text.trim();

    final uri = _buildProductUri(targetUrl);
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

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir este link')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Adicionar Produto',
          style: TextStyle(color: Color(0xFF6B2C5C)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF6B2C5C)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Cole o link da página do produto (o endereço completo na barra do '
                'navegador, com o item já aberto). O app tenta preencher imagem, nome e preço.',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        labelText: 'URL do Produto',
                        prefixIcon: Icon(Icons.link),
                        hintText: 'https://… (página do item na loja)',
                        helperText:
                            'Funciona com o URL da PDP em lojas como SHEIN, Dafiti, Shopee, '
                            'Mercado Livre, Zattini, Renner, C&A, Riachuelo, Amaro, Posthaus, '
                            'Arezzo ou H&M. '
                            'Não use só o nome do produto (ex.: “Vestido Amaro”) nem a home '
                            '(ex.: dafiti.com.br sem o caminho do produto).',
                        helperMaxLines: 4,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, insira a URL';
                        }
                        if (!value.startsWith('http')) {
                          return 'Por favor, insira uma URL válida';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        // Limpa preview quando URL muda
                        if (_showScrapingPreview) {
                          setState(() {
                            _showScrapingPreview = false;
                            _scrapedData = null;
                          });
                        }
                      },
                      onFieldSubmitted: (_) => _scrapeUrlData(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isScrapingUrl ? null : _scrapeUrlData,
                    icon: _isScrapingUrl
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    tooltip: 'Extrair dados automaticamente',
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      foregroundColor: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Preview dos dados scraped
              if (_showScrapingPreview && _scrapedData != null) ...[
                Container(
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
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        child: _scrapedData?.imageUrl != null && _scrapedData!.imageUrl!.isNotEmpty
                            ? Image.network(
                                _scrapedData!.imageUrl!,
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 180,
                                    color: Colors.grey[200],
                                    child: const Center(child: Icon(Icons.image_not_supported)),
                                  );
                                },
                              )
                            : Container(
                                height: 180,
                                color: Colors.grey[200],
                                child: const Center(child: Icon(Icons.image_not_supported)),
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _scrapedData?.title ?? 'Produto sem nome',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Raleway',
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: Color(0xFF191919),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              (_scrapedData?.priceDisplay?.trim().isNotEmpty ?? false)
                                  ? _scrapedData!.priceDisplay!.trim()
                                  : (_scrapedData?.price != null
                                      ? 'R\$ ${_scrapedData!.price!.toStringAsFixed(2)}'
                                      : 'Preço indisponível'),
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                color: Color(0xFF8B7FB8),
                                fontWeight: FontWeight.w500,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _openProductLink,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF8B7FB8),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    child: const Text('Shop Now'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: _discardScrapedData,
                                  icon: const Icon(Icons.close),
                                  tooltip: 'Descartar',
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newCategoryController,
                      decoration: const InputDecoration(
                        labelText: 'Nova pasta/categoria',
                        prefixIcon: Icon(Icons.create_new_folder_outlined),
                        hintText: 'Ex: Computers',
                      ),
                      onSubmitted: (_) => _addCategory(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Pasta/Categoria',
                  prefixIcon: Icon(Icons.folder_outlined),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                hint: const Text('Crie sua primeira pasta'),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                  _tryAutoSaveAfterFolderSelection();
                },
              ),
              const SizedBox(height: 16),

              const SizedBox(height: 32),
              Consumer<ProductProvider>(
                builder: (context, provider, _) {
                  return ElevatedButton(
                    onPressed: provider.isLoading ? null : _handleSubmit,
                    child: provider.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _newCategoryController.text.trim().isNotEmpty
                                ? 'Criar Pasta e Salvar Produto'
                                : 'Salvar Produto na Pasta',
                          ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
