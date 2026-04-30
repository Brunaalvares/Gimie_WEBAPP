import 'package:flutter/material.dart';
import '../services/currency_service.dart';
import '../utils/debug_helper.dart';

class PriceConverterWidget extends StatefulWidget {
  final double price;
  final String originalCurrency;
  final Function(double, String)? onCurrencyChanged;

  const PriceConverterWidget({
    super.key,
    required this.price,
    required this.originalCurrency,
    this.onCurrencyChanged,
  });

  @override
  State<PriceConverterWidget> createState() => _PriceConverterWidgetState();
}

class _PriceConverterWidgetState extends State<PriceConverterWidget> {
  String _selectedCurrency = 'BRL';
  double? _convertedPrice;
  bool _isLoading = false;
  final CurrencyService _currencyService = CurrencyService();

  @override
  void initState() {
    super.initState();
    _selectedCurrency = widget.originalCurrency;
    _convertedPrice = widget.price;
  }

  @override
  void didUpdateWidget(PriceConverterWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.price != widget.price ||
        oldWidget.originalCurrency != widget.originalCurrency) {
      if (oldWidget.originalCurrency != widget.originalCurrency) {
        _selectedCurrency = widget.originalCurrency;
      }
      if (_selectedCurrency == widget.originalCurrency) {
        setState(() => _convertedPrice = widget.price);
      } else {
        _convertPrice(_selectedCurrency);
      }
    }
  }

  Future<void> _convertPrice(String toCurrency) async {
    if (toCurrency == widget.originalCurrency) {
      setState(() {
        _convertedPrice = widget.price;
        _selectedCurrency = toCurrency;
      });
      widget.onCurrencyChanged?.call(widget.price, toCurrency);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final converted = await _currencyService.convertPrice(
        amount: widget.price,
        fromCurrency: widget.originalCurrency,
        toCurrency: toCurrency,
      );

      if (mounted) {
        setState(() {
          _convertedPrice = converted;
          _selectedCurrency = toCurrency;
          _isLoading = false;
        });

        if (converted != null) {
          widget.onCurrencyChanged?.call(converted, toCurrency);
        }
      }
    } catch (e) {
      DebugHelper.logError('Failed to convert price', e);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao converter moeda: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.currency_exchange,
                size: 16,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 4),
              Text(
                'Converter Moeda',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedCurrency,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: CurrencyService.supportedCurrencies.map((currency) {
                    return DropdownMenuItem<String>(
                      value: currency['code'],
                      child: Row(
                        children: [
                          Text(
                            currency['symbol']!,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            currency['code']!,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _convertPrice(value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _convertedPrice != null
                              ? CurrencyService.formatPrice(_convertedPrice!, _selectedCurrency)
                              : 'Erro na conversão',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _convertedPrice != null ? Colors.green[700] : Colors.red,
                          ),
                        ),
                ),
              ),
            ],
          ),
          if (widget.originalCurrency != _selectedCurrency) ...[
            const SizedBox(height: 4),
            Text(
              'Original: ${CurrencyService.formatPrice(widget.price, widget.originalCurrency)}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }
}