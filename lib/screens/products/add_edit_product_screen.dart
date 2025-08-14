import 'package:flutter/material.dart';

class AddEditProductScreen extends StatelessWidget {
  final String? productId;
  
  const AddEditProductScreen({super.key, this.productId});

  @override
  Widget build(BuildContext context) {
    final isEdit = productId != null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Product' : 'Add Product'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Add/Edit Product Screen'),
            Text('(To be implemented)'),
          ],
        ),
      ),
    );
  }
}