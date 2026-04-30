import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/product_provider.dart';
import '../providers/auth_provider.dart';
import 'user_profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<UserModel> _userResults = const [];
  bool _isSearchingUsers = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    Provider.of<ProductProvider>(context, listen: false).searchProducts(query);
    _searchUsers(query);
  }

  Future<void> _searchUsers(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.length < 2) {
      if (!mounted) return;
      setState(() {
        _isSearchingUsers = false;
        _userResults = const [];
      });
      return;
    }

    setState(() {
      _isSearchingUsers = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final users = await authProvider.searchUsersToFollow(trimmedQuery);
    if (!mounted) return;
    setState(() {
      _userResults = users;
      _isSearchingUsers = false;
    });
  }

  void _onQueryChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      if (value.length >= 2 || value.isEmpty) {
        _performSearch(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Buscar',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF6B2C5C),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar produtos e usuários...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
                          setState(() {});
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _onQueryChanged,
            ),
          ),
          Expanded(
            child: Consumer2<ProductProvider, AuthProvider>(
              builder: (context, productProvider, authProvider, _) {
                if (productProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final showEmptyState =
                    _searchController.text.trim().isNotEmpty &&
                    productProvider.products.isEmpty &&
                    !_isSearchingUsers &&
                    _userResults.isEmpty;

                if (showEmptyState) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Nenhum resultado encontrado',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                final itemCount = productProvider.products.length +
                    (_isSearchingUsers || _userResults.isNotEmpty ? 1 : 0);

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: itemCount,
                  itemBuilder: (context, index) {
                    if (_isSearchingUsers || _userResults.isNotEmpty) {
                      if (index == 0) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Text(
                                'Usuários',
                                style: TextStyle(
                                  fontFamily: 'Raleway',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                  color: Color(0xFF6B2C5C),
                                ),
                              ),
                            ),
                            if (_isSearchingUsers)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: LinearProgressIndicator(minHeight: 2),
                              )
                            else if (_userResults.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: Text(
                                  'Nenhum usuário encontrado',
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    color: Colors.grey,
                                  ),
                                ),
                              )
                            else
                              ..._userResults.map((user) {
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: const Color(0xFF8B7FB8),
                                      backgroundImage: user.photoUrl != null
                                          ? NetworkImage(user.photoUrl!)
                                          : null,
                                      child: user.photoUrl == null
                                          ? Text(
                                              user.name.isNotEmpty
                                                  ? user.name[0].toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            )
                                          : null,
                                    ),
                                    title: Text(user.name),
                                    subtitle: Text('@${user.username}'),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => UserProfileScreen(user: user),
                                        ),
                                      );
                                      if (!mounted) return;
                                      _searchUsers(_searchController.text);
                                    },
                                  ),
                                );
                              }),
                            if (productProvider.products.isNotEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 8, bottom: 8),
                                child: Text(
                                  'Produtos',
                                  style: TextStyle(
                                    fontFamily: 'Raleway',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                    color: Color(0xFF6B2C5C),
                                  ),
                                ),
                              ),
                          ],
                        );
                      }
                      index -= 1;
                    }

                    final product = productProvider.products[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            product.imageUrl,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                        title: Text(product.name),
                        subtitle: Text(product.formattedPrice),
                        trailing: IconButton(
                          icon: Icon(
                            product.likedBy.contains(
                              authProvider.currentUser?.id,
                            )
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: const Color(0xFF8B7FB8),
                          ),
                          onPressed: () {
                            final userId =
                                Provider.of<AuthProvider>(context, listen: false)
                                    .currentUser
                                    ?.id;
                            if (userId != null) {
                              productProvider.toggleLike(product.id, userId);
                            }
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
