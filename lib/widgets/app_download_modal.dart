import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Modal que exige download do app antes de acessar links de produtos
class AppDownloadModal extends StatelessWidget {
  final String productUrl;
  final VoidCallback? onDismiss;

  const AppDownloadModal({
    super.key,
    required this.productUrl,
    this.onDismiss,
  });

  // URLs das lojas (substitua com as URLs reais quando publicar o app)
  static const String _appStoreUrl = 'https://apps.apple.com/app/gimie/id123456789';
  static const String _playStoreUrl = 'https://play.google.com/store/apps/details?id=com.gimie.app';
  static const String _appName = 'Gimie';

  Future<void> _openStore(BuildContext context, bool isIOS) async {
    final url = isIOS ? _appStoreUrl : _playStoreUrl;
    final uri = Uri.parse(url);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir a loja de aplicativos'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir loja: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ícone do app
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.shopping_bag_outlined,
                size: 40,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 20),

            // Título
            Text(
              'Baixe o App $_appName',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.primaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Descrição
            Text(
              'Para acessar os links dos produtos e fazer suas compras, você precisa baixar o aplicativo $_appName.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Botão iOS
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openStore(context, true),
                icon: const Icon(Icons.apple, size: 24),
                label: const Text('Download na App Store'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Botão Android
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openStore(context, false),
                icon: const Icon(Icons.android, size: 24),
                label: const Text('Download na Play Store'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3DDC84),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Botão cancelar
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onDismiss?.call();
              },
              child: Text(
                'Agora não',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Mostra o modal de download do app
  static Future<void> show(
    BuildContext context, {
    required String productUrl,
    VoidCallback? onDismiss,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AppDownloadModal(
        productUrl: productUrl,
        onDismiss: onDismiss,
      ),
    );
  }
}
