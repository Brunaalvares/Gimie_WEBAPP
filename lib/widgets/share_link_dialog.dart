import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Dialog para compartilhar link com fallback manual
class ShareLinkDialog extends StatefulWidget {
  final String shareUrl;

  const ShareLinkDialog({
    super.key,
    required this.shareUrl,
  });

  @override
  State<ShareLinkDialog> createState() => _ShareLinkDialogState();
}

class _ShareLinkDialogState extends State<ShareLinkDialog> {
  bool _copied = false;

  Future<void> _copyToClipboard() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.shareUrl));
      setState(() => _copied = true);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Link copiado!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
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
      content: SingleChildScrollView(
        child: Column(
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
                widget.shareUrl,
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
            if (_copied) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[700], size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Link copiado!',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
        ElevatedButton.icon(
          onPressed: _copyToClipboard,
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
