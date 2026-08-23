import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Dialog para compartilhar link com fallback manual
class ShareLinkDialog extends StatelessWidget {
  final String shareUrl;

  const ShareLinkDialog({
    super.key,
    required this.shareUrl,
  });

  Future<void> _copyToClipboard(BuildContext context) async {
    try {
      await Clipboard.setData(ClipboardData(text: shareUrl));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Link copiado!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível copiar automaticamente. Copie manualmente.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Compartilhar Pasta',
        style: TextStyle(
          fontFamily: 'Raleway',
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Compartilhe este link com seus amigos:',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: SelectableText(
              shareUrl,
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 12,
                color: Colors.blue,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Toque no link acima para selecionar e copiar manualmente',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 11,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            await _copyToClipboard(context);
          },
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('Copiar Link'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8B7FB8),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  /// Mostra o dialog de compartilhamento
  static Future<void> show(BuildContext context, String shareUrl) {
    return showDialog(
      context: context,
      builder: (context) => ShareLinkDialog(shareUrl: shareUrl),
    );
  }
}
