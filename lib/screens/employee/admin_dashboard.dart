import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../constants/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/branch_provider.dart';
import '../../providers/catalogue_provider.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Management Console'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authStateProvider.notifier).logout();
              context.go('/welcome');
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppColors.brandOrange,
          tabs: const [
            Tab(icon: Icon(Icons.store), text: 'Branches'),
            Tab(icon: Icon(Icons.inventory), text: 'Products'),
            Tab(icon: Icon(Icons.upload_file), text: 'CSV Import'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const _BranchManagementTab(),
          const _ProductManagementTab(),
          const _CsvImportTab(),
        ],
      ),
    );
  }
}

// 1. Branch Management
class _BranchManagementTab extends ConsumerStatefulWidget {
  const _BranchManagementTab();

  @override
  ConsumerState<_BranchManagementTab> createState() => _BranchManagementTabState();
}

class _BranchManagementTabState extends ConsumerState<_BranchManagementTab> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _hoursController = TextEditingController();
  bool _collectionEnabled = true;
  bool _active = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  Future<void> _createBranch() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final api = ref.read(apiClientProvider);
      final response = await api.dio.post(
        '/branches',
        data: {
          'code': _codeController.text.trim().toUpperCase(),
          'name': _nameController.text.trim(),
          'address': _addressController.text.trim(),
          'phoneNumber': _phoneController.text.trim(),
          'whatsappNumber': _whatsappController.text.trim().isEmpty ? null : _whatsappController.text.trim(),
          'openingHours': _hoursController.text.trim().isEmpty ? null : _hoursController.text.trim(),
          'collectionEnabled': _collectionEnabled,
          'active': _active,
        },
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (response.statusCode == 201 || response.statusCode == 200) {
          // Clear inputs
          _codeController.clear();
          _nameController.clear();
          _addressController.clear();
          _phoneController.clear();
          _whatsappController.clear();
          _hoursController.clear();
          ref.read(branchStateProvider.notifier).fetchBranches();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Branch created successfully!'), backgroundColor: AppColors.success),
          );
        }
      }
    } on DioException catch (e) {
      setState(() => _isSubmitting = false);
      final msg = e.errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Add New Branch Office',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
            ),
            const SizedBox(height: 16.0),
            TextFormField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: 'Branch Code (e.g. HRE-01)'),
              validator: (val) => val == null || val.trim().isEmpty ? 'Enter code' : null,
            ),
            const SizedBox(height: 12.0),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Branch Name (e.g. Harare Main)'),
              validator: (val) => val == null || val.trim().isEmpty ? 'Enter name' : null,
            ),
            const SizedBox(height: 12.0),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Physical Address'),
              validator: (val) => val == null || val.trim().isEmpty ? 'Enter address' : null,
            ),
            const SizedBox(height: 12.0),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Telephone number'),
              validator: (val) => val == null || val.trim().isEmpty ? 'Enter phone number' : null,
            ),
            const SizedBox(height: 12.0),
            TextFormField(
              controller: _whatsappController,
              decoration: const InputDecoration(labelText: 'WhatsApp Number (Optional)'),
            ),
            const SizedBox(height: 12.0),
            TextFormField(
              controller: _hoursController,
              decoration: const InputDecoration(labelText: 'Opening Hours (e.g. 08:00 - 17:00)'),
            ),
            const SizedBox(height: 16.0),
            SwitchListTile(
              title: const Text('Collection Allowed'),
              value: _collectionEnabled,
              onChanged: (val) => setState(() => _collectionEnabled = val),
            ),
            SwitchListTile(
              title: const Text('Active Status'),
              value: _active,
              onChanged: (val) => setState(() => _active = val),
            ),
            const SizedBox(height: 24.0),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _createBranch,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Add Branch'),
            ),
          ],
        ),
      ),
    );
  }
}

// 2. Product and Category Management
class _ProductManagementTab extends ConsumerStatefulWidget {
  const _ProductManagementTab();

  @override
  ConsumerState<_ProductManagementTab> createState() => _ProductManagementTabState();
}

class _ProductManagementTabState extends ConsumerState<_ProductManagementTab> {
  final _catFormKey = GlobalKey<FormState>();
  final _prodFormKey = GlobalKey<FormState>();

  final _catNameController = TextEditingController();
  final _catDescController = TextEditingController();

  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _prodNameController = TextEditingController();
  final _prodDescController = TextEditingController();
  final _packSizeController = TextEditingController();
  final _imageController = TextEditingController();

  String? _selectedCategoryId;
  bool _prodPublished = true;
  bool _prodActive = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _catNameController.dispose();
    _catDescController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _prodNameController.dispose();
    _prodDescController.dispose();
    _packSizeController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _createCategory() async {
    if (!_catFormKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final api = ref.read(apiClientProvider);
      final response = await api.dio.post(
        '/catalogue/categories',
        data: {
          'name': _catNameController.text.trim(),
          'description': _catDescController.text.trim().isEmpty ? null : _catDescController.text.trim(),
          'active': true,
        },
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (response.statusCode == 201 || response.statusCode == 200) {
          _catNameController.clear();
          _catDescController.clear();
          // Reload categories (indirectly via catalogueStateProvider refresh)
          ref.read(catalogueStateProvider.notifier).refreshCatalogue();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Category created successfully!'), backgroundColor: AppColors.success),
          );
        }
      }
    } on DioException catch (e) {
      setState(() => _isSubmitting = false);
      final msg = e.errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _createProduct() async {
    if (!_prodFormKey.currentState!.validate() || _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Category'), backgroundColor: AppColors.error),
      );
      return;
    }
    setState(() => _isSubmitting = true);

    try {
      final api = ref.read(apiClientProvider);
      final response = await api.dio.post(
        '/catalogue/products',
        data: {
          'sku': _skuController.text.trim().toUpperCase(),
          'barcode': _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
          'categoryId': _selectedCategoryId,
          'name': _prodNameController.text.trim(),
          'description': _prodDescController.text.trim().isEmpty ? null : _prodDescController.text.trim(),
          'packSize': _packSizeController.text.trim(),
          'imageUrl': _imageController.text.trim().isEmpty ? null : _imageController.text.trim(),
          'published': _prodPublished,
          'active': _prodActive,
        },
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (response.statusCode == 201 || response.statusCode == 200) {
          _skuController.clear();
          _barcodeController.clear();
          _prodNameController.clear();
          _prodDescController.clear();
          _packSizeController.clear();
          _imageController.clear();
          ref.read(catalogueStateProvider.notifier).refreshCatalogue();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product added successfully!'), backgroundColor: AppColors.success),
          );
        }
      }
    } on DioException catch (e) {
      setState(() => _isSubmitting = false);
      final msg = e.errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogue = ref.watch(catalogueStateProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 2a. Add Category Form
          Form(
            key: _catFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Add New Feed Category',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                ),
                const SizedBox(height: 12.0),
                TextFormField(
                  controller: _catNameController,
                  decoration: const InputDecoration(labelText: 'Category Name (e.g. Broiler Feeds)'),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Enter name' : null,
                ),
                const SizedBox(height: 8.0),
                TextFormField(
                  controller: _catDescController,
                  decoration: const InputDecoration(labelText: 'Description (Optional)'),
                ),
                const SizedBox(height: 12.0),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _createCategory,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryNavy),
                  child: const Text('Add Category'),
                ),
              ],
            ),
          ),
          const Divider(height: 48.0),

          // 2b. Add Product Form
          Form(
            key: _prodFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Add New Feed Product',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
                ),
                const SizedBox(height: 12.0),
                DropdownButtonFormField<String>(
                  value: _selectedCategoryId,
                  hint: const Text('Select Feed Category'),
                  items: catalogue.categories.map((c) {
                    return DropdownMenuItem<String>(
                      value: c.id,
                      child: Text(c.name),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedCategoryId = val),
                  validator: (val) => val == null ? 'Select category' : null,
                ),
                const SizedBox(height: 12.0),
                TextFormField(
                  controller: _skuController,
                  decoration: const InputDecoration(labelText: 'SKU (e.g. FEED-BRO-STARTER-50KG)'),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Enter SKU' : null,
                ),
                const SizedBox(height: 12.0),
                TextFormField(
                  controller: _barcodeController,
                  decoration: const InputDecoration(labelText: 'Barcode (Optional)'),
                ),
                const SizedBox(height: 12.0),
                TextFormField(
                  controller: _prodNameController,
                  decoration: const InputDecoration(labelText: 'Product Title'),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Enter title' : null,
                ),
                const SizedBox(height: 12.0),
                TextFormField(
                  controller: _prodDescController,
                  decoration: const InputDecoration(labelText: 'Product description'),
                ),
                const SizedBox(height: 12.0),
                TextFormField(
                  controller: _packSizeController,
                  decoration: const InputDecoration(labelText: 'Pack Size (e.g. 50 kg)'),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Enter pack size' : null,
                ),
                const SizedBox(height: 12.0),
                TextFormField(
                  controller: _imageController,
                  decoration: const InputDecoration(labelText: 'Image URL (Optional)'),
                ),
                const SizedBox(height: 16.0),
                SwitchListTile(
                  title: const Text('Publish Immediately'),
                  value: _prodPublished,
                  onChanged: (val) => setState(() => _prodPublished = val),
                ),
                SwitchListTile(
                  title: const Text('Active status'),
                  value: _prodActive,
                  onChanged: (val) => setState(() => _prodActive = val),
                ),
                const SizedBox(height: 24.0),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _createProduct,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Add Product'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24.0),
        ],
      ),
    );
  }
}

// 3. CSV Import Tab
class _CsvImportTab extends ConsumerStatefulWidget {
  const _CsvImportTab();

  @override
  ConsumerState<_CsvImportTab> createState() => _CsvImportTabState();
}

class _CsvImportTabState extends ConsumerState<_CsvImportTab> {
  final _csvController = TextEditingController();
  bool _isUploading = false;
  String? _resultMessage;

  @override
  void dispose() {
    _csvController.dispose();
    super.dispose();
  }

  Future<void> _uploadCsv() async {
    final csv = _csvController.text.trim();
    if (csv.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please paste some CSV data'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _resultMessage = null;
    });

    try {
      final api = ref.read(apiClientProvider);

      // Upload as multipart/form-data with Part "file" containing CSV text bytes
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          csv.codeUnits,
          filename: 'import.csv',
          contentType: DioMediaType('text', 'csv'),
        ),
      });

      final response = await api.dio.post(
        '/catalogue/import',
        data: formData,
      );

      if (mounted) {
        setState(() {
          _isUploading = false;
          if (response.statusCode == 200) {
            final created = response.data['created'];
            final updated = response.data['updated'];
            final total = response.data['total'];
            _resultMessage = 'Import Success!\nCreated: $created, Updated: $updated, Total processed: $total';
            _csvController.clear();
            ref.read(catalogueStateProvider.notifier).refreshCatalogue();
          } else {
            _resultMessage = 'Failed. Status: ${response.statusCode}';
          }
        });
      }
    } on DioException catch (e) {
      setState(() {
        _isUploading = false;
        _resultMessage = 'Upload Error: ${e.errorMessage}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'CSV Bulk Product Import',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
          ),
          const SizedBox(height: 8.0),
          const Text(
            'Paste your CSV contents below. Required columns: "sku", "name", "category", "pack_size". Optional columns: "barcode", "description", "image_url", "published", "active".',
            style: TextStyle(color: AppColors.textLight, fontSize: 13.0, height: 1.4),
          ),
          const SizedBox(height: 16.0),
          TextField(
            controller: _csvController,
            maxLines: 10,
            decoration: const InputDecoration(
              hintText: 'sku,name,category,pack_size,description\nFEED-BRO-S,Broiler Starter,Poultry,50kg,Premium chick crumbs',
              alignLabelWithHint: true,
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12.0),
          ),
          const SizedBox(height: 16.0),
          ElevatedButton.icon(
            onPressed: _isUploading ? null : _uploadCsv,
            icon: const Icon(Icons.cloud_upload),
            label: _isUploading
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Execute CSV Bulk Import'),
          ),
          if (_resultMessage != null) ...[
            const SizedBox(height: 24.0),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _resultMessage!.startsWith('Import Success')
                    ? AppColors.success.withOpacity(0.1)
                    : AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _resultMessage!.startsWith('Import Success') ? AppColors.success : AppColors.error,
                ),
              ),
              child: Text(
                _resultMessage!,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _resultMessage!.startsWith('Import Success') ? AppColors.success : AppColors.error,
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }
}
