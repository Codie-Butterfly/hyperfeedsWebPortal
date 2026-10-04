import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../constants/theme.dart';
import '../../models/models.dart';
import '../../providers/catalogue_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';

class ShopTab extends ConsumerStatefulWidget {
  const ShopTab({super.key});

  @override
  ConsumerState<ShopTab> createState() => _ShopTabState();
}

class _ShopTabState extends ConsumerState<ShopTab> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(catalogueStateProvider.notifier).setSearchQuery(query);
    });
  }

  void _showProductDetails(BuildContext context, Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (context) {
        return _ProductDetailsSheet(product: product);
      },
    );
  }

  void _showCart(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (context) {
        return const _CartBottomSheet();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalogue = ref.watch(catalogueStateProvider);
    final cart = ref.watch(cartStateProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        title: const Text('Hyperfeeds Shop'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(catalogueStateProvider.notifier).refreshCatalogue(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (catalogue.isOffline)
            Container(
              color: AppColors.warning,
              padding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 16.0,
              ),
              child: const Row(
                children: [
                  Icon(Icons.wifi_off, color: Colors.white),
                  SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      'Offline. Showing cached catalog products.',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Search Input
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(catalogueStateProvider.notifier)
                              .setSearchQuery('');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Categories horizontal scrolling chip bar
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              itemCount: catalogue.categories.length + 1,
              itemBuilder: (context, index) {
                final isAll = index == 0;
                final category = isAll ? null : catalogue.categories[index - 1];
                final isSelected = isAll
                    ? catalogue.selectedCategoryId == null
                    : catalogue.selectedCategoryId == category?.id;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text(isAll ? 'All Feeds' : category!.name),
                    onSelected: (selected) {
                      ref
                          .read(catalogueStateProvider.notifier)
                          .selectCategory(isAll ? null : category!.id);
                    },
                    selectedColor: AppColors.brandOrange.withOpacity(0.2),
                    checkmarkColor: AppColors.brandOrange,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? AppColors.brandOrange
                          : AppColors.textDark,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          ),

          // Catalog items list
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(catalogueStateProvider.notifier).refreshCatalogue(),
              child: catalogue.isLoading && catalogue.products.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : catalogue.products.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.2,
                        ),
                        const Center(
                          child: Text(
                            'No products found.',
                            style: TextStyle(
                              color: AppColors.textLight,
                              fontSize: 16.0,
                            ),
                          ),
                        ),
                      ],
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16.0),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12.0,
                            mainAxisSpacing: 12.0,
                            childAspectRatio: 0.75,
                          ),
                      itemCount: catalogue.products.length,
                      itemBuilder: (context, index) {
                        final product = catalogue.products[index];
                        return _ProductCard(
                          product: product,
                          onTap: () => _showProductDetails(context, product),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCart(context),
        backgroundColor: AppColors.brandOrange,
        icon: Stack(
          children: [
            const Icon(Icons.shopping_cart, color: Colors.white),
            if (cart.itemCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 12,
                    minHeight: 12,
                  ),
                  child: Text(
                    '${cart.itemCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        label: Text(
          'Cart (${cart.totalAmount > 0 ? "USD ${cart.totalAmount.toStringAsFixed(2)}" : "Empty"})',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasPrice = product.amount != null;
    final available = product.available ?? 0.0;
    final isOutOfStock = available <= 0;
    final isLowStock = !isOutOfStock && available < 10.0;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.0),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Product placeholder or image
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: product.imageUrl != null
                      ? Image.network(
                          product.imageUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              Image.asset(
                                'assets/images/hyperfeeds_logo.png',
                                fit: BoxFit.contain,
                              ),
                        )
                      : Image.asset(
                          'assets/images/hyperfeeds_logo.png',
                          fit: BoxFit.contain,
                        ),
                ),
              ),
              const SizedBox(height: 8.0),
              // Category tag
              if (product.categoryName != null)
                Text(
                  product.categoryName!.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandOrange,
                  ),
                ),
              const SizedBox(height: 4.0),
              // Product Name
              Text(
                product.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.0,
                  color: AppColors.primaryNavy,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4.0),
              // Pack Size
              Text(
                product.packSize,
                style: const TextStyle(
                  fontSize: 12.0,
                  color: AppColors.textLight,
                ),
              ),
              const Spacer(),
              // Availability & Price
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (hasPrice)
                    Text(
                      '${product.currency} ${product.amount!.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14.0,
                        color: AppColors.primaryNavy,
                      ),
                    )
                  else
                    const Text(
                      'Unpriced',
                      style: TextStyle(
                        fontSize: 12.0,
                        color: AppColors.textLight,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6.0,
                      vertical: 2.0,
                    ),
                    decoration: BoxDecoration(
                      color: isOutOfStock
                          ? AppColors.error.withOpacity(0.1)
                          : isLowStock
                          ? AppColors.warning.withOpacity(0.1)
                          : AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: Text(
                      isOutOfStock
                          ? 'Out of Stock'
                          : isLowStock
                          ? 'Low Stock'
                          : 'In Stock',
                      style: TextStyle(
                        fontSize: 10.0,
                        fontWeight: FontWeight.bold,
                        color: isOutOfStock
                            ? AppColors.error
                            : isLowStock
                            ? AppColors.warning
                            : AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductDetailsSheet extends ConsumerStatefulWidget {
  final Product product;
  const _ProductDetailsSheet({required this.product});

  @override
  ConsumerState<_ProductDetailsSheet> createState() =>
      _ProductDetailsSheetState();
}

class _ProductDetailsSheetState extends ConsumerState<_ProductDetailsSheet> {
  double _quantity = 1.0;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final hasPrice = product.amount != null;
    final available = product.available ?? 0.0;
    final isOutOfStock = available <= 0;
    final cartState = ref.watch(cartStateProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24.0,
        24.0,
        24.0,
        MediaQuery.of(context).viewInsets.bottom + 24.0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24.0),
          // Product image & meta
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.all(8),
                child: product.imageUrl != null
                    ? Image.network(
                        product.imageUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            Image.asset(
                              'assets/images/hyperfeeds_logo.png',
                              fit: BoxFit.contain,
                            ),
                      )
                    : Image.asset(
                        'assets/images/hyperfeeds_logo.png',
                        fit: BoxFit.contain,
                      ),
              ),
              const SizedBox(width: 16.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      'SKU: ${product.sku}',
                      style: const TextStyle(
                        fontSize: 12.0,
                        color: AppColors.textLight,
                      ),
                    ),
                    if (product.barcode != null)
                      Text(
                        'Barcode: ${product.barcode}',
                        style: const TextStyle(
                          fontSize: 12.0,
                          color: AppColors.textLight,
                        ),
                      ),
                    Text(
                      'Pack Size: ${product.packSize}',
                      style: const TextStyle(
                        fontSize: 12.0,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24.0),
          if (product.description != null) ...[
            const Text(
              'Description',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0),
            ),
            const SizedBox(height: 8.0),
            Text(
              product.description!,
              style: const TextStyle(color: AppColors.textLight, height: 1.4),
            ),
            const SizedBox(height: 24.0),
          ],
          // Stock indicator & Pricing
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Price',
                    style: TextStyle(fontSize: 12, color: AppColors.textLight),
                  ),
                  if (hasPrice)
                    Text(
                      '${product.currency} ${product.amount!.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryNavy,
                      ),
                    )
                  else
                    const Text(
                      'Unpriced',
                      style: TextStyle(
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Available Stock',
                    style: TextStyle(fontSize: 12, color: AppColors.textLight),
                  ),
                  Text(
                    '${available.toStringAsFixed(1)} units',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isOutOfStock ? AppColors.error : AppColors.success,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32.0),
          // Quantity selector & Add to cart button
          if (!isOutOfStock && hasPrice) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _quantity <= 1.0
                      ? null
                      : () => setState(() => _quantity -= 1.0),
                  icon: const Icon(Icons.remove_circle_outline, size: 32),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    _quantity.toStringAsFixed(0),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _quantity >= available
                      ? null
                      : () => setState(() => _quantity += 1.0),
                  icon: const Icon(Icons.add_circle_outline, size: 32),
                ),
              ],
            ),
            const SizedBox(height: 24.0),
            ElevatedButton(
              onPressed: cartState.isSubmitting
                  ? null
                  : () async {
                      final ok = await ref
                          .read(cartStateProvider.notifier)
                          .updateItemQuantity(product.id, _quantity);
                      if (mounted && ok) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${product.name} added to cart.'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    },
              child: cartState.isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Add to Cart'),
            ),
          ] else ...[
            ElevatedButton(
              onPressed: null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.border,
              ),
              child: const Text('Unavailable'),
            ),
          ],
          const SizedBox(height: 16.0),
        ],
      ),
    );
  }
}

class _CartBottomSheet extends ConsumerStatefulWidget {
  const _CartBottomSheet();

  @override
  ConsumerState<_CartBottomSheet> createState() => _CartBottomSheetState();
}

class _CartBottomSheetState extends ConsumerState<_CartBottomSheet> {
  bool _isCheckingOut = false;
  String _paymentMethod = 'PAY_ON_APP';
  String _fulfilmentMethod = 'PICKUP';

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartStateProvider);
    final customerEmail = ref.watch(authStateProvider).customerProfile?.email;
    final canPayOnline =
        customerEmail != null && customerEmail.trim().isNotEmpty;
    if (!canPayOnline && _paymentMethod == 'PAY_ON_APP') {
      _paymentMethod = 'PAY_AT_SHOP';
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        if (cart.checkoutResult != null) {
          // Show Paynow Payment Instructions page
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24.0),
                const Icon(
                  Icons.payments_outlined,
                  size: 80,
                  color: AppColors.brandOrange,
                ),
                const SizedBox(height: 24.0),
                const Text(
                  'Order Placed Successfully!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryNavy,
                  ),
                ),
                const SizedBox(height: 8.0),
                Text(
                  'Order Reference: ${cart.checkoutResult!.reference}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24.0),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment Instructions:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        cart.checkoutResult!.instructions,
                        style: const TextStyle(height: 1.4),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {
                    ref.read(cartStateProvider.notifier).clearCheckoutResult();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Back to Shop'),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16.0),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16.0),
              const Row(
                children: [
                  Icon(Icons.shopping_cart, color: AppColors.primaryNavy),
                  SizedBox(width: 8.0),
                  Text(
                    'Shopping Cart',
                    style: TextStyle(
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
              Expanded(
                child: cart.items.isEmpty
                    ? const Center(
                        child: Text(
                          'Your cart is empty.',
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 16.0,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: cart.items.length,
                        itemBuilder: (context, index) {
                          final item = cart.items[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12.0),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4.0),
                                        Text(
                                          'USD ${item.unitPrice.toStringAsFixed(2)} / unit',
                                          style: const TextStyle(
                                            color: AppColors.textLight,
                                            fontSize: 12.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                        ),
                                        onPressed: () {
                                          ref
                                              .read(cartStateProvider.notifier)
                                              .updateItemQuantity(
                                                item.productId,
                                                item.quantity - 1.0,
                                              );
                                        },
                                      ),
                                      Text(
                                        item.quantity.toStringAsFixed(0),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                        ),
                                        onPressed: () {
                                          ref
                                              .read(cartStateProvider.notifier)
                                              .updateItemQuantity(
                                                item.productId,
                                                item.quantity + 1.0,
                                              );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (cart.items.isNotEmpty) ...[
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount:',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'USD ${cart.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20.0,
                          fontWeight: FontWeight.w900,
                          color: AppColors.brandOrange,
                        ),
                      ),
                    ],
                  ),
                ),
                const Text(
                  'How would you like to pay?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                RadioListTile<String>(
                  value: 'PAY_ON_APP',
                  groupValue: _paymentMethod,
                  dense: true,
                  title: const Text('Pay for order on the app'),
                  onChanged: canPayOnline
                      ? (value) => setState(() => _paymentMethod = value!)
                      : null,
                ),
                if (!canPayOnline)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      'Update your email under My Account to enable Paynow online payment.',
                      style: TextStyle(
                        color: AppColors.brandOrange,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                RadioListTile<String>(
                  value: 'PAY_AT_SHOP',
                  groupValue: _paymentMethod,
                  dense: true,
                  title: const Text('Pay for order at the shop'),
                  subtitle: const Text(
                    'The order number expires if payment is not made in time.',
                    style: TextStyle(
                      color: AppColors.brandOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onChanged: (value) => setState(() => _paymentMethod = value!),
                ),
                const Text(
                  'How would you like to receive it?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                RadioListTile<String>(
                  value: 'PICKUP',
                  groupValue: _fulfilmentMethod,
                  dense: true,
                  title: const Text('Pick up at the shop'),
                  onChanged: (value) =>
                      setState(() => _fulfilmentMethod = value!),
                ),
                RadioListTile<String>(
                  value: 'DELIVERY',
                  groupValue: _fulfilmentMethod,
                  dense: true,
                  title: const Text('Delivery'),
                  subtitle: const Text(
                    'Delivery fee is paid when the order is received.',
                    style: TextStyle(
                      color: AppColors.brandOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onChanged: (value) =>
                      setState(() => _fulfilmentMethod = value!),
                ),
                ElevatedButton(
                  onPressed: _isCheckingOut || cart.isSubmitting
                      ? null
                      : () async {
                          setState(() => _isCheckingOut = true);
                          final ok = await ref
                              .read(cartStateProvider.notifier)
                              .checkout(
                                paymentMethod: _paymentMethod,
                                fulfilmentMethod: _fulfilmentMethod,
                              );
                          if (!ok && mounted) {
                            setState(() => _isCheckingOut = false);
                            final error =
                                ref.read(cartStateProvider).error ??
                                'Checkout failed';
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(error),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        },
                  child: _isCheckingOut || cart.isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _paymentMethod == 'PAY_ON_APP'
                              ? 'Place Order and Pay'
                              : 'Generate Order Number',
                        ),
                ),
                const SizedBox(height: 16.0),
              ],
            ],
          ),
        );
      },
    );
  }
}
