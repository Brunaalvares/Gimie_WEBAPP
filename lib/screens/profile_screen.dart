import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../providers/auth_provider.dart';
import '../providers/product_provider.dart';
import '../services/firebase_service.dart';
import '../services/shared_link_service.dart';
import 'follow_users_screen.dart';
import 'follow_list_screen.dart';
import 'folder_products_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _bioController = TextEditingController();
  final FocusNode _bioFocusNode = FocusNode();
  int _followersCount = 0;
  int _followingCount = 0;
  bool _isLoadingFollowStats = true;
  bool _isUploadingPhoto = false;
  bool _isSavingBio = false;
  bool _isEditingBio = false;
  String? _loadedProductsForUserId;
  String? _loadedFollowStatsForUserId;
  String _lastSyncedBio = '';
  StreamSubscription<int>? _followersSub;
  StreamSubscription<int>? _followingSub;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadUserProductsIfNeeded();
      _loadFollowStatsIfNeeded();
    });
  }

  @override
  void dispose() {
    _followersSub?.cancel();
    _followingSub?.cancel();
    _bioController.dispose();
    _bioFocusNode.dispose();
    super.dispose();
  }

  void _loadUserProductsIfNeeded() {
    final userId = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).resolvedUserId;
    if (userId != null) {
      if (_loadedProductsForUserId == userId) return;
      _loadedProductsForUserId = userId;
      Provider.of<ProductProvider>(context, listen: false).loadUserProducts(userId);
    }
  }

  void _loadFollowStatsIfNeeded() {
    final userId = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).resolvedUserId;
    if (userId == null || _loadedFollowStatsForUserId == userId) return;
    _loadedFollowStatsForUserId = userId;
    _listenFollowStats(userId);
    _loadFollowStats();
  }

  void _listenFollowStats(String userId) {
    _followersSub?.cancel();
    _followingSub?.cancel();

    _followersSub = _firebaseService.getFollowersCountStream(userId).listen((value) {
      if (!mounted) return;
      setState(() {
        _followersCount = value;
        _isLoadingFollowStats = false;
      });
    });

    _followingSub = _firebaseService.getFollowingCountStream(userId).listen((value) {
      if (!mounted) return;
      setState(() {
        _followingCount = value;
        _isLoadingFollowStats = false;
      });
    });
  }

  Future<void> _loadFollowStats() async {
    final userId = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).resolvedUserId;
    if (userId == null) return;

    setState(() {
      _isLoadingFollowStats = true;
    });

    try {
      final followers = await _firebaseService.getFollowersCount(userId);
      final following = await _firebaseService.getFollowingCount(userId);

      if (!mounted) return;
      setState(() {
        _followersCount = followers;
        _followingCount = following;
        _isLoadingFollowStats = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingFollowStats = false;
      });
    }
  }

  Future<void> _pickAndUploadProfilePhoto() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() {
      _isUploadingPhoto = true;
    });

    try {
      final path = 'profiles/${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await picked.readAsBytes();
      final photoUrl = await _firebaseService.uploadImageFromBytes(bytes, path);
      await authProvider.updateProfile(photoUrl: photoUrl);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto de perfil atualizada!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível atualizar a foto'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  }

  Future<void> _saveBio() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bio = _bioController.text.trim();
    if (_isSavingBio) return;
    if (bio == (authProvider.currentUser?.bio?.trim() ?? '')) {
      setState(() {
        _isEditingBio = false;
      });
      return;
    }

    setState(() {
      _isSavingBio = true;
    });

    try {
      final success = await authProvider.updateProfile(bio: bio);
      if (!success) {
        throw Exception(authProvider.errorMessage ?? 'Não foi possível salvar a biografia');
      }
      _lastSyncedBio = bio;
      if (!mounted) return;
      setState(() {
        _isEditingBio = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biografia atualizada!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar a biografia'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingBio = false;
        });
      }
    }
  }

  void _startEditingBio(String currentBio) {
    setState(() {
      _bioController.text = currentBio;
      _isEditingBio = true;
    });
    _bioFocusNode.requestFocus();
  }

  void _cancelEditingBio(String currentBio) {
    setState(() {
      _bioController.text = currentBio;
      _isEditingBio = false;
    });
    _bioFocusNode.unfocus();
  }

  Future<void> _openFollowList({required bool showFollowers}) async {
    final userId = Provider.of<AuthProvider>(context, listen: false).resolvedUserId;
    if (userId == null || userId.isEmpty) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FollowListScreen(
          userId: userId,
          showFollowers: showFollowers,
        ),
      ),
    );
    if (!mounted) return;
    _loadFollowStats();
  }

  Future<void> _editProfileIdentity({
    required String currentName,
    required String currentUsername,
  }) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EditProfileDialog(
        authProvider: authProvider,
        currentName: currentName,
        currentUsername: currentUsername,
      ),
    );

    if (saved != true || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Perfil atualizado com sucesso!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _renameFolder({
    required String currentName,
    required List<Product> categoryProducts,
  }) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Renomear pasta'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Novo nome da pasta',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (newName == null || newName.isEmpty || newName == currentName) return;

    final provider = Provider.of<ProductProvider>(context, listen: false);
    final success = await provider.renameFolder(
      productsInFolder: categoryProducts,
      newCategory: newName,
    );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Pasta renomeada com sucesso!' : 'Não foi possível renomear a pasta',
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _shareFolder(String categoryName) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.resolvedUserId;

    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você precisa estar logado para compartilhar pastas'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Gera a URL de compartilhamento
      final shareUrl = SharedLinkService.instance.generateShareUrl(
        userId: userId,
        folderName: categoryName,
      );

      // Copia para a área de transferência
      await Clipboard.setData(ClipboardData(text: shareUrl));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Link copiado! Compartilhe com seus amigos',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar link: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteFolder({
    required String categoryName,
    required List<Product> categoryProducts,
  }) async {
    final provider = Provider.of<ProductProvider>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar pasta'),
        content: Text(
          'Deseja apagar a pasta "$categoryName" e ${categoryProducts.length} produto(s) dentro dela?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    final success = await provider.deleteFolder(productsInFolder: categoryProducts);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Pasta apagada com sucesso' : 'Não foi possível apagar a pasta',
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  void _handleLogout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.signOut();
    
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Perfil',
          style: TextStyle(
            fontFamily: 'Raleway',
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B2C5C),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF6B2C5C)),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: Consumer2<AuthProvider, ProductProvider>(
        builder: (context, authProvider, productProvider, _) {
          final user = authProvider.currentUser;
          final resolvedUserId = authProvider.resolvedUserId;

          if (user == null || resolvedUserId == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_loadedProductsForUserId != resolvedUserId) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _loadedProductsForUserId = null;
              _loadUserProductsIfNeeded();
            });
          }
          if (_loadedFollowStatsForUserId != resolvedUserId) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _loadedFollowStatsForUserId = null;
              _loadFollowStatsIfNeeded();
            });
          }

          final currentBio = user.bio?.trim() ?? '';
          if (!_bioFocusNode.hasFocus && _lastSyncedBio != currentBio) {
            _bioController.text = currentBio;
            _lastSyncedBio = currentBio;
          }

          final mergedUserProductsById = <String, Product>{};
          for (final product in productProvider.products) {
            if (product.userId == resolvedUserId) {
              mergedUserProductsById[product.id] = product;
            }
          }
          for (final product in productProvider.userProducts) {
            mergedUserProductsById[product.id] = product;
          }
          final visibleUserProducts = mergedUserProductsById.values.toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          final productsByCategory = <String, List<Product>>{};
          for (final product in visibleUserProducts) {
            final category = (product.category == null || product.category!.trim().isEmpty)
                ? 'Outros'
                : product.category!.trim();
            productsByCategory.putIfAbsent(category, () => <Product>[]).add(product);
          }
          final orderedCategories = productsByCategory.keys.toList()
            ..sort((a, b) {
              final aProducts = productsByCategory[a]!;
              final bProducts = productsByCategory[b]!;
              final aLatest = aProducts
                  .map((p) => p.createdAt)
                  .reduce((x, y) => x.isAfter(y) ? x : y);
              final bLatest = bProducts
                  .map((p) => p.createdAt)
                  .reduce((x, y) => x.isAfter(y) ? x : y);
              return bLatest.compareTo(aLatest);
            });

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              children: [
                const SizedBox(height: 22),
                Stack(
                  children: [
                    GestureDetector(
                      onTap: _isUploadingPhoto ? null : _pickAndUploadProfilePhoto,
                      child: CircleAvatar(
                        radius: 54,
                        backgroundColor: const Color(0xFF8B7FB8),
                        backgroundImage:
                            user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                        child: user.photoUrl == null
                            ? Text(
                                user.name[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 32,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFF6B2C5C),
                          shape: BoxShape.circle,
                        ),
                        child: _isUploadingPhoto
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt_outlined,
                                color: Colors.white,
                                size: 16,
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Toque para atualizar foto',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  user.name,
                  style: const TextStyle(
                    fontFamily: 'Raleway',
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '@${user.username}',
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Biografia',
                              style: TextStyle(
                                fontFamily: 'Raleway',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF6B2C5C),
                              ),
                            ),
                          ),
                          if (!_isEditingBio)
                            TextButton.icon(
                              onPressed: () => _startEditingBio(currentBio),
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('Editar'),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF6B2C5C),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_isEditingBio) ...[
                        TextField(
                          controller: _bioController,
                          focusNode: _bioFocusNode,
                          minLines: 2,
                          maxLines: 4,
                          maxLength: 180,
                          decoration: const InputDecoration(
                            hintText: 'Escreva sua biografia...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _isSavingBio
                                  ? null
                                  : () => _cancelEditingBio(currentBio),
                              child: const Text('Cancelar'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _isSavingBio ? null : _saveBio,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6B2C5C),
                                foregroundColor: Colors.white,
                              ),
                              child: _isSavingBio
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Salvar'),
                            ),
                          ],
                        ),
                      ] else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.grey.withValues(alpha: 0.12),
                          ),
                          child: Text(
                            currentBio.isEmpty
                                ? 'Adicione uma bio para as pessoas te conhecerem melhor.'
                                : currentBio,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 14,
                              color: currentBio.isEmpty
                                  ? Colors.grey.shade700
                                  : const Color(0xFF191919),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ProfileStatItem(
                        label: 'Seguidores',
                        value: _isLoadingFollowStats ? '-' : _followersCount.toString(),
                        onTap: _isLoadingFollowStats
                            ? null
                            : () => _openFollowList(showFollowers: true),
                      ),
                      _ProfileStatItem(
                        label: 'Seguindo',
                        value: _isLoadingFollowStats ? '-' : _followingCount.toString(),
                        onTap: _isLoadingFollowStats
                            ? null
                            : () => _openFollowList(showFollowers: false),
                      ),
                      _ProfileStatItem(
                        label: 'Pastas',
                        value: productsByCategory.length.toString(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _editProfileIdentity(
                        currentName: user.name,
                        currentUsername: user.username,
                      ),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Editar perfil'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6B2C5C),
                        side: const BorderSide(color: Color(0xFF6B2C5C)),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const FollowUsersScreen()),
                        );
                        if (!mounted) return;
                        _loadFollowStats();
                      },
                      icon: const Icon(Icons.group_add_outlined),
                      label: const Text('Gerenciar seguidores'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6B2C5C),
                        side: const BorderSide(color: Color(0xFF6B2C5C)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Pastas',
                      style: TextStyle(
                        fontFamily: 'Raleway',
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B2C5C),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (productProvider.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  )
                else if (orderedCategories.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Você ainda não possui pastas',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: orderedCategories.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final category = orderedCategories[index];
                      final categoryProducts = productsByCategory[category]!;
                      final coverImage = categoryProducts.first.imageUrl;

                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            final provider = Provider.of<ProductProvider>(
                              context,
                              listen: false,
                            );
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => FolderProductsScreen(
                                  categoryName: category,
                                  products: categoryProducts,
                                  allowDelete: true,
                                  onDeleteProduct: (product) async {
                                    return provider.deleteProduct(product.id);
                                  },
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                  width: 46,
                                  height: 46,
                                  color: const Color(0xFF8B7FB8).withValues(alpha: 0.15),
                                  child: coverImage.isEmpty
                                      ? const Icon(
                                          Icons.folder_outlined,
                                          color: Color(0xFF6B2C5C),
                                        )
                                      : Image.network(
                                          coverImage,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return const Icon(
                                              Icons.folder_outlined,
                                              color: Color(0xFF6B2C5C),
                                            );
                                          },
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        category,
                                        style: const TextStyle(
                                          fontFamily: 'Raleway',
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${categoryProducts.length} produtos salvos',
                                        style: const TextStyle(
                                          fontFamily: 'Roboto',
                                          color: Colors.grey,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'rename') {
                                      _renameFolder(
                                        currentName: category,
                                        categoryProducts: categoryProducts,
                                      );
                                    } else if (value == 'delete') {
                                      _deleteFolder(
                                        categoryName: category,
                                        categoryProducts: categoryProducts,
                                      );
                                    } else if (value == 'share') {
                                      _shareFolder(category);
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem<String>(
                                      value: 'share',
                                      child: Row(
                                        children: [
                                          Icon(Icons.share, size: 20, color: Color(0xFF8B7FB8)),
                                          SizedBox(width: 8),
                                          Text('Compartilhar pasta'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'rename',
                                      child: Text('Renomear pasta'),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Text('Apagar pasta'),
                                    ),
                                  ],
                                  icon: const Icon(Icons.more_vert),
                                ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  final AuthProvider authProvider;
  final String currentName;
  final String currentUsername;

  const _EditProfileDialog({
    required this.authProvider,
    required this.currentName,
    required this.currentUsername,
  });

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  bool _isSaving = false;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _usernameController = TextEditingController(text: widget.currentUsername);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  String _normalizeUsername(String value) {
    return value.trim().replaceAll('@', '').replaceAll(RegExp(r'\s+'), '').toLowerCase();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final newName = _nameController.text.trim();
    final newUsername = _normalizeUsername(_usernameController.text);
    if (newName == widget.currentName && newUsername == widget.currentUsername) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() {
      _isSaving = true;
      _inlineError = null;
    });

    final success = await widget.authProvider.updateProfile(
      name: newName,
      username: newUsername,
    );
    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isSaving = false;
      _inlineError = widget.authProvider.errorMessage ??
          'Não foi possível atualizar o perfil';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar perfil'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              enabled: !_isSaving,
              decoration: const InputDecoration(
                labelText: 'Nome no perfil',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Informe seu nome';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _usernameController,
              enabled: !_isSaving,
              decoration: const InputDecoration(
                labelText: '@ no app',
                prefixIcon: Icon(Icons.alternate_email),
              ),
              validator: (value) {
                final normalized = _normalizeUsername(value ?? '');
                if (normalized.isEmpty) {
                  return 'Informe seu @';
                }
                if (normalized.length < 3) {
                  return 'Seu @ deve ter pelo menos 3 caracteres';
                }
                if (!RegExp(r'^[a-z0-9._]+$').hasMatch(normalized)) {
                  return 'Use apenas letras, números, ponto ou underscore';
                }
                return null;
              },
            ),
            if (_inlineError != null) ...[
              const SizedBox(height: 12),
              Text(
                _inlineError!,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }
}

class _ProfileStatItem extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _ProfileStatItem({
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Raleway',
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Color(0xFF6B2C5C),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 13,
            color: Colors.grey,
          ),
        ),
      ],
    );

    if (onTap == null) return content;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: content,
      ),
    );
  }
}
