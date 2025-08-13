import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/product.dart';
import '../../../providers/providers.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final Product? existing;
  final String? initialBarcode;
  const ProductFormScreen({super.key, this.existing, this.initialBarcode});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _priceController;
  late final TextEditingController _costController;
  late final TextEditingController _categoryController;
  late final TextEditingController _stockController;
  String? _imageBase64;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _nameController = TextEditingController(text: p?.name ?? '');
    _descController = TextEditingController(text: p?.description ?? '');
    _barcodeController = TextEditingController(text: p?.barcode ?? widget.initialBarcode ?? '');
    _priceController = TextEditingController(text: p?.price.toString() ?? '0');
    _costController = TextEditingController(text: p?.cost?.toString() ?? '');
    _categoryController = TextEditingController(text: p?.category ?? '');
    _stockController = TextEditingController(text: (p?.stockQuantity ?? 0).toString());
    _imageBase64 = p?.imageBase64;
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Product' : 'Add Product')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Description (optional)'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _barcodeController,
                decoration: const InputDecoration(labelText: 'Barcode/QR (optional)'),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(labelText: 'Price'),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => (double.tryParse(v ?? '') == null) ? 'Enter number' : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _costController,
                    decoration: const InputDecoration(labelText: 'Cost (optional)'),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _categoryController,
                    decoration: const InputDecoration(labelText: 'Category (optional)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _stockController,
                    decoration: const InputDecoration(labelText: 'Stock qty'),
                    keyboardType: TextInputType.number,
                    validator: (v) => (int.tryParse(v ?? '') == null) ? 'Enter integer' : null,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: () async {
                      final picker = ImagePicker();
                      final img = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024);
                      if (img != null) {
                        final bytes = await img.readAsBytes();
                        setState(() => _imageBase64 = base64Encode(bytes));
                      }
                    },
                    icon: const Icon(Icons.image),
                    label: const Text('Pick Image'),
                  ),
                  const SizedBox(width: 12),
                  if (_imageBase64 != null) const Icon(Icons.check_circle, color: Colors.green)
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  final repo = ref.read(productRepositoryProvider);
                  final price = double.parse(_priceController.text.trim());
                  final cost = double.tryParse(_costController.text.trim());
                  final stock = int.parse(_stockController.text.trim());
                  if (widget.existing == null) {
                    await repo.create(
                      name: _nameController.text.trim(),
                      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
                      barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
                      price: price,
                      cost: cost,
                      category: _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
                      stockQuantity: stock,
                      imageBase64: _imageBase64,
                    );
                  } else {
                    await repo.update(widget.existing!.copyWith(
                      name: _nameController.text.trim(),
                      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
                      barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
                      price: price,
                      cost: cost,
                      category: _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
                      stockQuantity: stock,
                      imageBase64: _imageBase64,
                    ));
                  }
                  if (mounted) Navigator.pop(context);
                },
                child: Text(isEditing ? 'Save Changes' : 'Create'),
              )
            ],
          ),
        ),
      ),
    );
  }
}