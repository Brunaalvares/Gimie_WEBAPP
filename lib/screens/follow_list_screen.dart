import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/firebase_service.dart';
import 'user_profile_screen.dart';

class FollowListScreen extends StatefulWidget {
  final String userId;
  final bool showFollowers;

  const FollowListScreen({
    super.key,
    required this.userId,
    required this.showFollowers,
  });

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  List<UserModel> _users = const [];
  final Set<String> _processingUserIds = <String>{};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final users = widget.showFollowers
          ? await _firebaseService.getFollowersUsers(widget.userId)
          : await _firebaseService.getFollowingUsers(widget.userId);
      if (!mounted) return;
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _users = const [];
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível carregar a lista agora'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleFollow(UserModel targetUser) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (_processingUserIds.contains(targetUser.id)) return;

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
      return;
    }

    _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final currentUserId = authProvider.resolvedUserId;
        final followingIds = authProvider.currentUser?.followingIds.toSet() ?? <String>{};
        final title = widget.showFollowers ? 'Seguidores' : 'Seguindo';

        return Scaffold(
          appBar: AppBar(
            title: Text(
              title,
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
              : _users.isEmpty
                  ? Center(
                      child: Text(
                        widget.showFollowers
                            ? 'Ainda não há seguidores'
                            : 'Ainda não está seguindo ninguém',
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadUsers,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        itemCount: _users.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final user = _users[index];
                          final isCurrentUser = currentUserId != null && currentUserId == user.id;
                          final isFollowing = followingIds.contains(user.id);
                          final isProcessing = _processingUserIds.contains(user.id);
                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () async {
                                if (currentUserId == null || currentUserId != user.id) {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => UserProfileScreen(user: user),
                                    ),
                                  );
                                  if (!mounted) return;
                                }
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
                                    const SizedBox(width: 8),
                                    if (isCurrentUser)
                                      const Text(
                                        'Você',
                                        style: TextStyle(
                                          fontFamily: 'Roboto',
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      )
                                    else
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
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : Text(isFollowing ? 'Seguindo' : 'Seguir'),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        );
      },
    );
  }
}
