import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/utils/platform_utils.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _barcodeController = TextEditingController();

  @override
  void dispose() {
    _barcodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scanner - ${PlatformUtils.getPlatformName()}'),
      ),
      body: PlatformUtils.supportsBarcodeScanning
          ? _buildMobileScanner()
          : _buildWebDesktopScanner(),
    );
  }

  Widget _buildMobileScanner() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_scanner, size: 64),
          SizedBox(height: 16),
          Text('Mobile Camera Scanner'),
          Text('(Camera integration to be implemented)'),
        ],
      ),
    );
  }

  Widget _buildWebDesktopScanner() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, 
                           color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Barcode Scanner',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Camera scanning is not available on ${PlatformUtils.getPlatformName()}. '
                    'Please enter barcode manually or use an external scanner.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Manual Barcode Entry',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _barcodeController,
                    decoration: const InputDecoration(
                      labelText: 'Enter Barcode',
                      hintText: 'Type or paste barcode here',
                      prefixIcon: Icon(Icons.qr_code),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: _processBarcode,
                    textInputAction: TextInputAction.search,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _processBarcode(_barcodeController.text),
                          icon: const Icon(Icons.search),
                          label: const Text('Search Product'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _pasteFromClipboard,
                        icon: const Icon(Icons.paste),
                        tooltip: 'Paste from clipboard',
                      ),
                      IconButton(
                        onPressed: () => _barcodeController.clear(),
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Sample barcodes for testing
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sample Barcodes for Testing',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Click any barcode below to test:',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildSampleBarcodeChip('1234567890123', 'EAN-13'),
                      _buildSampleBarcodeChip('12345678', 'EAN-8'),
                      _buildSampleBarcodeChip('123456789012', 'UPC-A'),
                      _buildSampleBarcodeChip('SAMPLE123', 'Code 39'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSampleBarcodeChip(String barcode, String type) {
    return ActionChip(
      label: Text('$barcode ($type)'),
      onPressed: () {
        _barcodeController.text = barcode;
        _processBarcode(barcode);
      },
    );
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData('text/plain');
      if (clipboardData?.text != null) {
        _barcodeController.text = clipboardData!.text!;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not paste from clipboard')),
        );
      }
    }
  }

  void _processBarcode(String barcode) {
    if (barcode.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a barcode')),
      );
      return;
    }

    // TODO: Search for product with this barcode
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Searching for product with barcode: $barcode'),
        action: SnackBarAction(
          label: 'View Details',
          onPressed: () {
            // TODO: Navigate to product details or add to cart
          },
        ),
      ),
    );
    
    // Clear the input after processing
    _barcodeController.clear();
  }
}