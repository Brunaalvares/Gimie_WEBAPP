import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home_screen.dart';
import 'add_product_screen.dart';
import 'folder_products_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';
import '../models/product_model.dart';
import '../services/firebase_service.dart';
import '../services/share_service.dart';
import '../services/shared_link_service.dart';
import '../providers/auth_provider.dart';
import '../providers/product_provider.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  bool _checkedPendingShare = false;
  bool _checkedPendingFolder = false;

  final List<Widget> _screens = [
    const HomeScreen(),
    const SearchScreen(),
    const SizedBox(), // Placeholder for FAB
    const SizedBox(), // Placeholder
    const ProfileScreen(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_checkedPendingFolder) {
      _checkedPendingFolder = true;
      _openPendingSharedFolder();
    }

    if (_checkedPendingShare) return;
    _checkedPendingShare = true;
    _openAddScreenIfSharedContentExists();
  }

  /// Reabre a pasta que trouxe o usuário para o app.
  ///
  /// Fecha o ciclo do link compartilhado: o visitante viu a pasta no navegador,
  /// baixou o app por causa dela e, ao entrar, volta exatamente para ela.
  Future<void> _openPendingSharedFolder() async {
    final sharedLink = SharedLinkService.instance;
    final pending = await sharedLink.getPendingFolder();
    if (pending == null || !mounted) return;

    // Consome antes de abrir para não repetir em logins futuros.
    await sharedLink.clearPendingFolder();

    List<Product> folderProducts;
    try {
      final ownerProducts =
          await FirebaseService().getUserProducts(pending.userId);

      final normalizedTarget = pending.folderName.trim().toLowerCase();
      folderProducts = ownerProducts.where((product) {
        final category = (product.category ?? '').trim().toLowerCase();
        return category == normalizedTarget;
      }).toList();
    } catch (e) {
      debugPrint('Could not load pending shared folder: $e');
      return;
    }

    if (folderProducts.isEmpty || !mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FolderProductsScreen(
            categoryName: pending.folderName,
            products: folderProducts,
          ),
        ),
      );
    });
  }

  Future<void> _openAddScreenIfSharedContentExists() async {
    final sharedContent = await ShareService.instance.getSharedContent();
    if (!mounted || sharedContent == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AddProductScreen()),
      );
    });
  }

  void _onTabTapped(int index) {
    if (index == 2) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AddProductScreen()),
      );
    } else if (index == 3) {
      // Trends ainda não implementado
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trends — em breve!'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      if (index == 4) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final userId = authProvider.resolvedUserId;
        if (userId != null && userId.isNotEmpty) {
          Provider.of<ProductProvider>(context, listen: false).loadUserProducts(userId);
        }
      }
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex == 2 ? 0 : _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.home_outlined, Icons.home, 0),
                _buildNavItem(Icons.search, Icons.search, 1),
                const SizedBox(width: 60), // Space for FAB
                _buildNavItem(Icons.favorite_border, Icons.favorite, 3),
                _buildNavItem(Icons.person_outline, Icons.person, 4),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onTabTapped(2),
        backgroundColor: const Color(0xFF6B2C5C),
        child: const Icon(Icons.add, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildNavItem(IconData outlinedIcon, IconData filledIcon, int index) {
    final isSelected = _currentIndex == index;
    return IconButton(
      icon: Icon(
        isSelected ? filledIcon : outlinedIcon,
        color: isSelected ? const Color(0xFF8B7FB8) : Colors.grey,
      ),
      onPressed: () => _onTabTapped(index),
    );
  }
}
