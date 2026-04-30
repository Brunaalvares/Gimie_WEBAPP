import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/firebase_service.dart';
import 'follow_list_screen.dart';
import 'folder_products_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final UserModel user;

  const UserProfileScreen({
    super.key,
    required this.user,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  late UserModel _viewedUser;
  List<Product> _products = const [];
  bool _isLoading = true;
  bool _isProcessingFollow = false;
  int _followersCount = 0;
  int _followingCount = 0;
  StreamSubscription<int>? _followersSub;
  StreamSubscription<int>? _followingSub;

  @override
  void initState() {
    super.initState();
    _viewedUser = widget.user;
    _loadData();
  }

  @override
  void dispose() {
    _followersSub?.cancel();
    _followingSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final fetchedUser = await _firebaseService.getUserDocument(_viewedUser.id);
      final products = await _firebaseService.getUserProducts(_viewedUser.id);
      final followers = await _firebaseService.getFollowersCount(_viewedUser.id);
      final following = await _firebaseService.getFollowingCount(_viewedUser.id);

      if (!mounted) return;
      setState(() {
        _viewedUser = fetchedUser ?? _viewedUser;
        _products = products;
        _followersCount = followers;
        _followingCount = following;
        _isLoading = false;
      });
      _listenFollowStats(_viewedUser.id);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _listenFollowStats(String userId) {
    _followersSub?.cancel();
    _followingSub?.cancel();

    _followersSub = _firebaseService.getFollowersCountStream(userId).listen((value) {
      if (!mounted) return;
      setState(() {
        _followersCount = value;
      });
    });

    _followingSub = _firebaseService.getFollowingCountStream(userId).listen((value) {
      if (!mounted) return;
      setState(() {
        _followingCount = value;
      });
    });
  }

  Future<void> _toggleFollow() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      _isProcessingFollow = true;
    });

    final success = await authProvider.toggleFollowUser(_viewedUser);
    if (!mounted) return;

    setState(() {
      _isProcessingFollow = false;
    });

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível atualizar este usuário'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await _loadData();
  }

  Future<void> _openFollowList({required bool showFollowers}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FollowListScreen(
          userId: _viewedUser.id,
          showFollowers: showFollowers,
        ),
      ),
    );
    if (!mounted) return;
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final currentUserId = authProvider.resolvedUserId;
        final isOwnProfile = currentUserId == _viewedUser.id;
        final isFollowing = authProvider.currentUser?.followingIds.contains(_viewedUser.id) ?? false;

        final productsByCategory = <String, List<Product>>{};
        for (final product in _products) {
          final category = (product.category == null || product.category!.trim().isEmpty)
              ? 'Outros'
              : product.category!.trim();
          productsByCategory.putIfAbsent(category, () => <Product>[]).add(product);
        }
        final orderedCategories = productsByCategory.keys.toList()
          ..sort((a, b) {
            final aLatest = productsByCategory[a]!
                .map((p) => p.createdAt)
                .reduce((x, y) => x.isAfter(y) ? x : y);
            final bLatest = productsByCategory[b]!
                .map((p) => p.createdAt)
                .reduce((x, y) => x.isAfter(y) ? x : y);
            return bLatest.compareTo(aLatest);
          });

        return Scaffold(
          appBar: AppBar(
            title: Text(
              _viewedUser.name,
              style: const TextStyle(
                fontFamily: 'Raleway',
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B2C5C),
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      const SizedBox(height: 18),
                      CircleAvatar(
                        radius: 52,
                        backgroundColor: const Color(0xFF8B7FB8),
                        backgroundImage:
                            _viewedUser.photoUrl != null ? NetworkImage(_viewedUser.photoUrl!) : null,
                        child: _viewedUser.photoUrl == null
                            ? Text(
                                _viewedUser.name.isNotEmpty
                                    ? _viewedUser.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 30,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          _viewedUser.name,
                          style: const TextStyle(
                            fontFamily: 'Raleway',
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          '@${_viewedUser.username}',
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 15,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      if ((_viewedUser.bio ?? '').trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          child: Text(
                            _viewedUser.bio!.trim(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 14,
                              color: Color(0xFF191919),
                            ),
                          ),
                        ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _ProfileStatItem(
                            label: 'Seguidores',
                            value: _followersCount.toString(),
                            onTap: () => _openFollowList(showFollowers: true),
                          ),
                          _ProfileStatItem(
                            label: 'Seguindo',
                            value: _followingCount.toString(),
                            onTap: () => _openFollowList(showFollowers: false),
                          ),
                          _ProfileStatItem(label: 'Pastas', value: orderedCategories.length.toString()),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (!isOwnProfile)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: ElevatedButton(
                            onPressed: _isProcessingFollow ? null : _toggleFollow,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isFollowing
                                  ? Colors.grey.shade200
                                  : const Color(0xFF6B2C5C),
                              foregroundColor:
                                  isFollowing ? const Color(0xFF6B2C5C) : Colors.white,
                              elevation: 0,
                            ),
                            child: _isProcessingFollow
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(isFollowing ? 'Deixar de seguir' : 'Seguir'),
                          ),
                        ),
                      const SizedBox(height: 22),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
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
                      const SizedBox(height: 12),
                      if (orderedCategories.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'Este usuário ainda não possui pastas',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 15,
                                color: Colors.grey,
                              ),
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
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => FolderProductsScreen(
                                        categoryName: category,
                                        products: categoryProducts,
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
                ),
        );
      },
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
