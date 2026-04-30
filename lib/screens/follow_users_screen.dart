import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import 'user_profile_screen.dart';

class FollowUsersScreen extends StatefulWidget {
  const FollowUsersScreen({super.key});

  @override
  State<FollowUsersScreen> createState() => _FollowUsersScreenState();
}

class _FollowUsersScreenState extends State<FollowUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _processingUserIds = <String>{};
  List<UserModel> _users = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    setState(() {
      _isLoading = true;
    });

    final users = await authProvider.searchUsersToFollow(_searchController.text);
    if (!mounted) return;

    setState(() {
      _users = users;
      _isLoading = false;
    });
  }

  Future<void> _toggleFollow(UserModel targetUser) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      _processingUserIds.add(targetUser.id);
    });

    final success = await authProvider.toggleFollowUser(targetUser);
    if (!mounted) return;

    setState(() {
      _processingUserIds.remove(targetUser.id);
    });

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível atualizar esse usuário'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Seguir usuários',
          style: TextStyle(
            fontFamily: 'Raleway',
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B2C5C),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final currentUser = authProvider.currentUser;
          final followingIds = currentUser?.followingIds.toSet() ?? <String>{};

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nome ou @username',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _loadUsers();
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _loadUsers(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      'Seguindo: ${followingIds.length}',
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _loadUsers,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Atualizar'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Dica: deslize para a esquerda para deixar de seguir.',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _users.isEmpty
                        ? const Center(
                            child: Text(
                              'Nenhum usuário encontrado',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: _users.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final user = _users[index];
                              final isFollowing = followingIds.contains(user.id);
                              final isProcessing = _processingUserIds.contains(user.id);

                              final card = Material(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => UserProfileScreen(user: user),
                                      ),
                                    );
                                    if (!mounted) return;
                                    _loadUsers();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.06),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 24,
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
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                user.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontFamily: 'Raleway',
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '@${user.username}',
                                                style: const TextStyle(
                                                  fontFamily: 'Roboto',
                                                  color: Colors.grey,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        ElevatedButton(
                                          onPressed: isProcessing ? null : () => _toggleFollow(user),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isFollowing
                                                ? Colors.grey.shade200
                                                : const Color(0xFF6B2C5C),
                                            foregroundColor: isFollowing
                                                ? const Color(0xFF6B2C5C)
                                                : Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 10,
                                            ),
                                          ),
                                          child: isProcessing
                                              ? const SizedBox(
                                                  height: 14,
                                                  width: 14,
                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                )
                                              : Text(isFollowing ? 'Seguindo' : 'Seguir'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );

                              if (!isFollowing) {
                                return card;
                              }

                              return Dismissible(
                                key: ValueKey('followed-${user.id}'),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade400,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.person_remove, color: Colors.white),
                                ),
                                confirmDismiss: (_) async {
                                  if (isProcessing) return false;
                                  await _toggleFollow(user);
                                  return false;
                                },
                                child: card,
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}
