import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_model.dart';
import '../models/product_model.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Auth Methods
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Firebase sign out error: $e');
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception('Firebase reset password error: $e');
    }
  }

  // Firestore - User Methods
  static const String _usernamesCollection = 'usernames';

  DocumentReference<Map<String, dynamic>> _usernameClaimRef(String normalized) {
    return _firestore.collection(_usernamesCollection).doc(normalized);
  }

  /// Registers [user] and atomically claims `usernames/{normalized}` for [user.id].
  Future<void> createUserDocument(UserModel user) async {
    final normalized = _normalizeUsername(user.username);
    if (normalized.isEmpty) {
      throw Exception('username_taken');
    }

    final userRef = _firestore.collection('users').doc(user.id);
    final claimRef = _usernameClaimRef(normalized);

    try {
      await _firestore.runTransaction((tx) async {
        final claim = await tx.get(claimRef);
        if (claim.exists) {
          final owner = claim.data()?['uid'] as String?;
          if (owner != user.id) {
            throw Exception('username_taken');
          }
        }
        tx.set(userRef, user.toFirestore());
        tx.set(claimRef, {'uid': user.id});
      });
    } catch (e) {
      if (e.toString().contains('username_taken')) rethrow;
      throw Exception('Create user document error: $e');
    }
  }

  Future<UserModel?> getUserDocument(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        final updates = <String, dynamic>{};

        // Backfill for older user documents that were created
        // before the following feature existed.
        if (!data.containsKey('followingIds') && !data.containsKey('following')) {
          updates['followingIds'] = <String>[];
          data['followingIds'] = <String>[];
        }

        // Backfill social identity fields for existing users:
        // - name: visible display name
        // - username: public @ handle (normalized)
        final currentName = (data['name'] as String?)?.trim() ?? '';
        final currentUsername = (data['username'] as String?)?.trim() ?? '';
        final currentEmail = (data['email'] as String?)?.trim() ?? '';

        String normalizedUsername = _normalizeUsername(currentUsername);
        if (normalizedUsername.isEmpty && currentEmail.contains('@')) {
          normalizedUsername = _normalizeUsername(currentEmail.split('@').first);
        }
        if (normalizedUsername.isEmpty) {
          normalizedUsername = 'user${userId.substring(0, 6).toLowerCase()}';
        }

        String normalizedName = currentName;
        if (normalizedName.isEmpty) {
          normalizedName = _humanizeUsername(normalizedUsername);
        }

        if (currentUsername != normalizedUsername) {
          updates['username'] = normalizedUsername;
          data['username'] = normalizedUsername;
        }
        if (currentName != normalizedName) {
          updates['name'] = normalizedName;
          data['name'] = normalizedName;
        }

        if (updates.isNotEmpty) {
          await _firestore.collection('users').doc(userId).set(
            updates,
            SetOptions(merge: true),
          );
        }

        final model = UserModel.fromFirestore(data, doc.id);
        if (_auth.currentUser?.uid == userId) {
          final handle = _normalizeUsername(model.username);
          if (handle.isNotEmpty) {
            unawaited(
              _claimUsernameDocIfPossible(userId, handle).catchError((Object _) {}),
            );
          }
        }
        return model;
      }
      return null;
    } catch (e) {
      throw Exception('Get user document error: $e');
    }
  }

  String _normalizeUsername(String username) {
    return username
        .trim()
        .replaceAll('@', '')
        .replaceAll(RegExp(r'\s+'), '')
        .toLowerCase();
  }

  String _humanizeUsername(String username) {
    if (username.isEmpty) return 'Usuário';
    final base = username.replaceAll(RegExp(r'[_\.]+'), ' ').trim();
    if (base.isEmpty) return 'Usuário';
    return base
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  Future<bool> isUsernameAvailable(
    String username, {
    String? excludeUserId,
  }) async {
    try {
      final normalized = _normalizeUsername(username);
      if (normalized.isEmpty) return false;

      // Single-doc read on `usernames/{handle}` works without auth when rules
      // allow `get` on that path (see firestore.rules in repo).
      final claim = await _usernameClaimRef(normalized).get();
      if (!claim.exists) return true;

      final owner = claim.data()?['uid'] as String?;
      if (owner == null) return false;
      if (excludeUserId != null && owner == excludeUserId) return true;
      return false;
    } catch (e) {
      throw Exception('Check username availability error: $e');
    }
  }

  /// Claims [normalized] for [userId] if the document is missing.
  /// Does not steal an existing claim owned by another uid.
  Future<void> _claimUsernameDocIfPossible(String userId, String normalized) async {
    final ref = _usernameClaimRef(normalized);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        tx.set(ref, {'uid': userId});
        return;
      }
      final owner = snap.data()?['uid'] as String?;
      if (owner == userId) return;
    });
  }

  Future<void> updateUserDocument(
    String userId,
    Map<String, dynamic> data, {
    String? previousNormalizedUsername,
  }) async {
    try {
      final rawNew = data['username'];
      if (rawNew is String && previousNormalizedUsername != null) {
        final prev = _normalizeUsername(previousNormalizedUsername);
        final next = _normalizeUsername(rawNew);
        if (prev.isNotEmpty && next.isNotEmpty && prev != next) {
          final userRef = _firestore.collection('users').doc(userId);
          final nextRef = _usernameClaimRef(next);
          final prevRef = _usernameClaimRef(prev);

          await _firestore.runTransaction((tx) async {
            final nextClaim = await tx.get(nextRef);
            if (nextClaim.exists) {
              final owner = nextClaim.data()?['uid'] as String?;
              if (owner != userId) {
                throw Exception('username_taken');
              }
            }

            final prevSnap = await tx.get(prevRef);
            if (prevSnap.exists && (prevSnap.data()?['uid'] as String?) == userId) {
              tx.delete(prevRef);
            }

            tx.set(userRef, data, SetOptions(merge: true));
            tx.set(nextRef, {'uid': userId});
          });
          return;
        }
      }

      await _firestore.collection('users').doc(userId).set(
        data,
        SetOptions(merge: true),
      );
    } catch (e) {
      if (e.toString().contains('username_taken')) rethrow;
      throw Exception('Update user document error: $e');
    }
  }

  Stream<UserModel?> getUserStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
          if (doc.exists) {
            return UserModel.fromFirestore(doc.data()!, doc.id);
          }
          return null;
        });
  }

  Future<List<UserModel>> searchUsers({
    String query = '',
    String? excludeUserId,
    int limit = 40,
  }) async {
    try {
      final snapshot = await _firestore.collection('users').limit(limit).get();
      final normalizedQuery = query.trim().toLowerCase();

      final users = snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc.data(), doc.id))
          .where((user) => excludeUserId == null || user.id != excludeUserId)
          .where((user) {
            if (normalizedQuery.isEmpty) return true;
            final name = user.name.toLowerCase();
            final username = user.username.toLowerCase();
            return name.contains(normalizedQuery) ||
                username.contains(normalizedQuery);
          })
          .toList();

      if (normalizedQuery.isNotEmpty) {
        int relevance(UserModel user) {
          final username = user.username.toLowerCase();
          final name = user.name.toLowerCase();

          if (username == normalizedQuery) return 0;
          if (username.startsWith(normalizedQuery)) return 1;
          if (name.startsWith(normalizedQuery)) return 2;
          if (username.contains(normalizedQuery)) return 3;
          if (name.contains(normalizedQuery)) return 4;
          return 5;
        }

        users.sort((a, b) {
          final byRelevance = relevance(a).compareTo(relevance(b));
          if (byRelevance != 0) return byRelevance;
          return a.username.toLowerCase().compareTo(b.username.toLowerCase());
        });
      } else {
        users.sort((a, b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()));
      }
      return users;
    } catch (e) {
      throw Exception('Search users error: $e');
    }
  }

  Future<int> getFollowersCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('followingIds', arrayContains: userId)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      throw Exception('Get followers count error: $e');
    }
  }

  Stream<int> getFollowersCountStream(String userId) {
    return _firestore
        .collection('users')
        .where('followingIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<int> getFollowingCount(String userId) async {
    try {
      final user = await getUserDocument(userId);
      return user?.followingIds.length ?? 0;
    } catch (e) {
      throw Exception('Get following count error: $e');
    }
  }

  Stream<int> getFollowingCountStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return 0;
          final data = doc.data();
          if (data == null) return 0;
          final following = data['followingIds'];
          if (following is List) return following.length;
          return 0;
        });
  }

  Future<List<UserModel>> getFollowingUsers(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return <UserModel>[];

      final data = userDoc.data();
      if (data == null) return <UserModel>[];

      final followingRaw = data['followingIds'];
      final followingIds = (followingRaw is List ? followingRaw : const [])
          .map((item) => item.toString().trim())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      if (followingIds.isEmpty) return <UserModel>[];
      return _getUsersByIds(followingIds);
    } catch (e) {
      throw Exception('Get following users error: $e');
    }
  }

  Future<List<UserModel>> getFollowersUsers(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('followingIds', arrayContains: userId)
          .get();

      final users = snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc.data(), doc.id))
          .toList()
        ..sort((a, b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()));
      return users;
    } catch (e) {
      throw Exception('Get followers users error: $e');
    }
  }

  Future<List<UserModel>> _getUsersByIds(List<String> userIds) async {
    if (userIds.isEmpty) return <UserModel>[];

    const maxWhereInItems = 10;
    final users = <UserModel>[];

    for (int i = 0; i < userIds.length; i += maxWhereInItems) {
      final chunk = userIds.skip(i).take(maxWhereInItems).toList();
      final snapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      users.addAll(
        snapshot.docs.map((doc) => UserModel.fromFirestore(doc.data(), doc.id)),
      );
    }

    final byId = <String, UserModel>{for (final user in users) user.id: user};
    final ordered = userIds
        .where(byId.containsKey)
        .map((id) => byId[id]!)
        .toList();
    return ordered;
  }

  Future<void> followUser({
    required String currentUserId,
    required String targetUserId,
  }) async {
    try {
      await _firestore.collection('users').doc(currentUserId).update({
        'followingIds': FieldValue.arrayUnion([targetUserId]),
      });
    } catch (e) {
      throw Exception('Follow user error: $e');
    }
  }

  Future<void> unfollowUser({
    required String currentUserId,
    required String targetUserId,
  }) async {
    try {
      await _firestore.collection('users').doc(currentUserId).update({
        'followingIds': FieldValue.arrayRemove([targetUserId]),
      });
    } catch (e) {
      throw Exception('Unfollow user error: $e');
    }
  }

  // Firestore - Product Methods
  Future<String> createProduct(Product product) async {
    try {
      final payload = product.toFirestore();
      final docRef = await _firestore.collection('products').add(payload);
      return docRef.id;
    } catch (e) {
      final errorText = e.toString();
      if ((errorText.contains('permission-denied') ||
              errorText.contains('PERMISSION_DENIED')) &&
          product.priceDisplay != null &&
          product.priceDisplay!.trim().isNotEmpty) {
        // Backward-compatible fallback for stricter rules that still
        // don't allow new fields such as priceDisplay.
        final legacyPayload = Map<String, dynamic>.from(product.toFirestore())
          ..remove('priceDisplay');
        final docRef = await _firestore.collection('products').add(legacyPayload);
        return docRef.id;
      }
      throw Exception('Create product error: $e');
    }
  }

  Future<List<Product>> getProducts({int? limit, String? category}) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('products')
          .orderBy('createdAt', descending: true);

      if (category != null) {
        query = query.where('category', isEqualTo: category);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => Product.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Get products error: $e');
    }
  }

  Stream<List<Product>> getProductsStream({int? limit, String? category}) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('products')
        .orderBy('createdAt', descending: true);

    if (category != null) {
      query = query.where('category', isEqualTo: category);
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Product.fromFirestore(doc.data(), doc.id))
          .toList();
    });
  }

  Future<Product?> getProduct(String productId) async {
    try {
      final doc = await _firestore.collection('products').doc(productId).get();
      if (doc.exists) {
        return Product.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Get product error: $e');
    }
  }

  Future<void> updateProduct(String productId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('products').doc(productId).update(data);
    } catch (e) {
      throw Exception('Update product error: $e');
    }
  }

  Future<void> deleteProduct(String productId) async {
    try {
      await _firestore.collection('products').doc(productId).delete();
    } catch (e) {
      throw Exception('Delete product error: $e');
    }
  }

  Future<void> likeProduct(String productId, String userId) async {
    try {
      final productRef = _firestore.collection('products').doc(productId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(productRef);
        if (!snapshot.exists) {
          throw Exception('Product does not exist');
        }

        final product = Product.fromFirestore(snapshot.data()!, snapshot.id);
        final newLikedBy = List<String>.from(product.likedBy);
        
        if (newLikedBy.contains(userId)) {
          newLikedBy.remove(userId);
        } else {
          newLikedBy.add(userId);
        }

        transaction.update(productRef, {
          'likedBy': newLikedBy,
          'likes': newLikedBy.length,
        });
      });
    } catch (e) {
      throw Exception('Like product error: $e');
    }
  }

  Future<List<Product>> getUserProducts(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('products')
          .where('userId', isEqualTo: userId)
          .get();

      final products = snapshot.docs
          .map((doc) => Product.fromFirestore(doc.data(), doc.id))
          .toList();

      products.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return products;
    } catch (e) {
      throw Exception('Get user products error: $e');
    }
  }

  Future<List<Product>> getProductsFromFollowedUsers(List<String> followedUserIds) async {
    try {
      if (followedUserIds.isEmpty) return [];

      const maxWhereInItems = 10;
      final allProducts = <Product>[];

      for (int i = 0; i < followedUserIds.length; i += maxWhereInItems) {
        final chunk = followedUserIds.skip(i).take(maxWhereInItems).toList();

        final snapshot = await _firestore
            .collection('products')
            .where('userId', whereIn: chunk)
            .orderBy('createdAt', descending: true)
            .limit(40)
            .get();

        allProducts.addAll(
          snapshot.docs.map((doc) => Product.fromFirestore(doc.data(), doc.id)),
        );
      }

      allProducts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return allProducts;
    } catch (e) {
      throw Exception('Get followed users products error: $e');
    }
  }

  // Firebase Storage Methods
  Future<String> uploadImageFromBytes(Uint8List bytes, String path) async {
    try {
      if (bytes.isEmpty) {
        throw Exception('Dados da imagem estão vazios');
      }
      
      final ref = _storage.ref().child(path);
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploaded': DateTime.now().toIso8601String(),
        },
      );
      
      final uploadTask = await ref.putData(bytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      if (downloadUrl.isEmpty) {
        throw Exception('URL de download está vazia');
      }
      
      return downloadUrl;
    } catch (e) {
      debugPrint('Erro no upload de imagem via bytes: $e');
      throw Exception('Erro ao fazer upload da imagem: $e');
    }
  }

  Future<void> deleteImage(String path) async {
    try {
      final ref = _storage.ref().child(path);
      await ref.delete();
    } catch (e) {
      throw Exception('Delete image error: $e');
    }
  }

  // Search
  Future<List<Product>> searchProducts(String query) async {
    try {
      final snapshot = await _firestore
          .collection('products')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: '$query\uf8ff')
          .get();
      
      return snapshot.docs
          .map((doc) => Product.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Search products error: $e');
    }
  }
}
