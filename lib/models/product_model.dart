class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String? priceDisplay;
  final String imageUrl;
  final String url;
  final String userId;
  final String? category;
  final DateTime createdAt;
  final int likes;
  final List<String> likedBy;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.priceDisplay,
    required this.imageUrl,
    required this.url,
    required this.userId,
    this.category,
    required this.createdAt,
    this.likes = 0,
    this.likedBy = const [],
  });

  // Parsing seguro de valores numéricos vindos da API (podem ser String ou num)
  static double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  static int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  // From JSON (API)
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: _safeDouble(json['price']),
      priceDisplay: json['priceDisplay'] ?? json['price_display'],
      imageUrl: json['imageUrl'] ?? json['image_url'] ?? '',
      url: json['url'] ?? json['product_url'] ?? '',
      userId: json['userId'] ?? json['user_id'] ?? '',
      category: json['category'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      likes: _safeInt(json['likes']),
      likedBy: json['likedBy'] != null
          ? List<String>.from(json['likedBy'])
          : [],
    );
  }

  // To JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'priceDisplay': priceDisplay,
      'imageUrl': imageUrl,
      'url': url,
      'userId': userId,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
      'likes': likes,
      'likedBy': likedBy,
    };
  }

  // From Firestore
  factory Product.fromFirestore(Map<String, dynamic> data, String documentId) {
    return Product(
      id: documentId,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: _safeDouble(data['price']),
      priceDisplay: data['priceDisplay'] ?? data['price_display'],
      imageUrl: data['imageUrl'] ?? '',
      url: data['url'] ?? '',
      userId: data['userId'] ?? '',
      category: data['category'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as dynamic).toDate()
          : DateTime.now(),
      likes: _safeInt(data['likes']),
      likedBy: data['likedBy'] != null
          ? List<String>.from(data['likedBy'])
          : [],
    );
  }

  // To Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'priceDisplay': priceDisplay,
      'imageUrl': imageUrl,
      'url': url,
      'userId': userId,
      'category': category,
      'createdAt': createdAt,
      'likes': likes,
      'likedBy': likedBy,
    };
  }

  // Formatted price
  String get formattedPrice {
    if (priceDisplay != null && priceDisplay!.trim().isNotEmpty) {
      final raw = priceDisplay!.trim();
      final hasCurrency = RegExp(r'(R\$|US\$|\$|€|£)', caseSensitive: false)
          .hasMatch(raw);
      return hasCurrency ? raw : 'R\$ $raw';
    }
    return 'R\$ ${price.toStringAsFixed(2)}';
  }

  // Copy with
  Product copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? priceDisplay,
    String? imageUrl,
    String? url,
    String? userId,
    String? category,
    DateTime? createdAt,
    int? likes,
    List<String>? likedBy,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      priceDisplay: priceDisplay ?? this.priceDisplay,
      imageUrl: imageUrl ?? this.imageUrl,
      url: url ?? this.url,
      userId: userId ?? this.userId,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      likes: likes ?? this.likes,
      likedBy: likedBy ?? this.likedBy,
    );
  }
}
