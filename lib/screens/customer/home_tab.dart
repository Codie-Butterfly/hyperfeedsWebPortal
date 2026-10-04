import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../constants/theme.dart';
import '../../providers/branch_provider.dart';
import '../../providers/home_content_provider.dart';
import '../../providers/support_notification_provider.dart';
import '../../providers/catalogue_provider.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  void _showNotificationInbox(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return const _NotificationInboxDialog();
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchState = ref.watch(branchStateProvider);
    final homeContent = ref.watch(homeContentStateProvider);
    final catalogue = ref.watch(catalogueStateProvider);
    final notificationState = ref.watch(supportNotificationStateProvider);
    final selectedBranch = branchState.selectedBranch;
    final productImages = {
      for (final product in catalogue.allProducts) product.id: product.imageUrl,
    };
    final advertSlides = <Map<String, dynamic>>[
      ...homeContent.advertisements,
      ...homeContent.specials.map(
        (special) => {
          'template_type': 'SPECIAL',
          'title': special.name,
          'body':
              '${special.currency} ${special.promotionalPrice.toStringAsFixed(2)} special price',
          'cta_label': 'Shop now',
          'cta_route': '/shop',
          'image_url': productImages[special.productId],
        },
      ),
      if (homeContent.chickBookingOpen)
        {
          'template_type': 'CHICKS',
          'title': 'Day-Old Chick Bookings Now Open',
          'body':
              'Book broiler and layer chicks for collection at your branch.',
          'cta_label': 'Book chicks',
          'cta_route': '/chicks',
          'asset_image': 'assets/images/hero_chickens.jpg',
        },
      ...catalogue.allProducts
          .where((product) => (product.available ?? 0) > 0)
          .map(
            (product) => {
              'template_type': 'NEW_PRODUCT',
              'title': product.name,
              'body':
                  '${product.packSize} • ${product.currency ?? 'USD'} ${product.amount?.toStringAsFixed(2) ?? ''} • In stock',
              'image_url': product.imageUrl,
              'cta_label': 'Shop now',
              'cta_route': '/shop',
            },
          ),
    ];

    final unreadCount = notificationState.notifications
        .where((n) => n.readAt == null)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.location_on, color: AppColors.brandOrange),
            const SizedBox(width: 8.0),
            Expanded(
              child: Text(
                selectedBranch?.name ?? 'Select Branch',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () => context.go('/branch-selection'),
              child: const Text(
                'Change',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () => _showNotificationInbox(context, ref),
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(homeContentStateProvider.notifier).refreshContent();
          ref.read(supportNotificationStateProvider.notifier).refreshAll();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (advertSlides.isNotEmpty)
                _AdvertisementCarousel(adverts: advertSlides),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  color: const Color(0xFFFFF4E8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.brandOrange,
                      child: Icon(
                        Icons.calculate_outlined,
                        color: Colors.white,
                      ),
                    ),
                    title: const Text(
                      'Feed Calculator',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    subtitle: const Text(
                      'Estimate feed and bags for every animal.',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => context.go('/feed-calculator'),
                  ),
                ),
              ),

              // Categories Grid
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(
                  'Browse Categories',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryNavy,
                  ),
                ),
              ),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _CategoryShortcut(
                    imagePath: 'assets/images/animal_chicken.png',
                    title: 'Poultry',
                    onTap: () {
                      ref
                          .read(catalogueStateProvider.notifier)
                          .selectCategoryByName('Poultry Feed');
                      context.go('/shop');
                    },
                  ),
                  _CategoryShortcut(
                    imagePath: 'assets/images/animal_cow_icon.png',
                    title: 'Cattle',
                    onTap: () {
                      ref
                          .read(catalogueStateProvider.notifier)
                          .selectCategoryByName('Cattle Feed');
                      context.go('/shop');
                    },
                  ),
                  _CategoryShortcut(
                    imagePath: 'assets/images/animal_goat.png',
                    title: 'Goat / Sheep',
                    onTap: () {
                      ref
                          .read(catalogueStateProvider.notifier)
                          .selectCategoryByName('Goat & Sheep Feed');
                      context.go('/shop');
                    },
                  ),
                  _CategoryShortcut(
                    imagePath: 'assets/images/animal_rabbit.png',
                    title: 'Rabbit',
                    onTap: () {
                      ref
                          .read(catalogueStateProvider.notifier)
                          .selectCategoryByName('Rabbit Feed');
                      context.go('/shop');
                    },
                  ),
                  _CategoryShortcut(
                    imagePath: 'assets/images/animal_pig.png',
                    title: 'Pigs',
                    onTap: () {
                      ref
                          .read(catalogueStateProvider.notifier)
                          .selectCategoryByName('Pig Feed');
                      context.go('/shop');
                    },
                  ),
                  _CategoryShortcut(
                    imagePath: 'assets/images/animal_dogs.png',
                    title: 'Dog',
                    onTap: () {
                      ref
                          .read(catalogueStateProvider.notifier)
                          .selectCategoryByName('Pet Food');
                      context.go('/shop');
                    },
                  ),
                ],
              ),

              // Specials Section
              if (homeContent.specials.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text(
                    'Exclusive Specials',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                ),
                SizedBox(
                  height: 160,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: homeContent.specials.length,
                    itemBuilder: (context, index) {
                      final spec = homeContent.specials[index];
                      return Container(
                        width: 260,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.brandOrange,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'SPECIAL',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${spec.currency} ${spec.promotionalPrice.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: AppColors.brandOrange,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  spec.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.primaryNavy,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Spacer(),
                                OutlinedButton(
                                  onPressed: () => context.go('/shop'),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(
                                      double.infinity,
                                      32,
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: const Text(
                                    'View Product',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],

              // Announcements Section
              if (homeContent.announcements.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text(
                    'Announcements',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: homeContent.announcements.length,
                  itemBuilder: (context, index) {
                    final ann = homeContent.announcements[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              ann.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.primaryNavy,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              ann.body,
                              style: const TextStyle(
                                color: AppColors.textLight,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdvertisementCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> adverts;
  const _AdvertisementCarousel({required this.adverts});

  @override
  State<_AdvertisementCarousel> createState() => _AdvertisementCarouselState();
}

class _AdvertisementCarouselState extends State<_AdvertisementCarousel> {
  final PageController controller = PageController();
  Timer? timer;
  int page = 0;
  int direction = 1;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || widget.adverts.length < 2 || !controller.hasClients)
        return;
      if (page >= widget.adverts.length - 1) direction = -1;
      if (page <= 0) direction = 1;
      page += direction;
      controller.animateToPage(
        page,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 205,
        child: PageView.builder(
          controller: controller,
          itemCount: widget.adverts.length,
          onPageChanged: (value) => setState(() => page = value),
          itemBuilder: (_, index) =>
              _ActiveAdvertisement(advert: widget.adverts[index]),
        ),
      ),
      if (widget.adverts.length > 1)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text('${page + 1} / ${widget.adverts.length}'),
        ),
    ],
  );
}

class _ActiveAdvertisement extends StatelessWidget {
  final Map<String, dynamic> advert;
  const _ActiveAdvertisement({required this.advert});
  @override
  Widget build(BuildContext context) {
    final type = advert['template_type']?.toString() ?? 'SPECIAL';
    final icon = switch (type) {
      'DISCOUNT' => Icons.percent,
      'CHICKS' => Icons.egg,
      'NEW_PRODUCT' => Icons.new_releases,
      _ => Icons.local_offer,
    };
    final route = advert['cta_route']?.toString();
    final imageUrl =
        advert['imageUrl']?.toString() ?? advert['image_url']?.toString();
    final assetImage = advert['asset_image']?.toString();
    return GestureDetector(
      onTap: route == null ? null : () => context.go(route),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        decoration: BoxDecoration(
          color: AppColors.primaryNavy,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: AppColors.brandOrange, size: 28),
                    const SizedBox(height: 6),
                    Text(
                      advert['title']?.toString() ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      advert['body']?.toString() ?? '',
                      style: const TextStyle(color: Colors.white70),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (advert['cta_label'] != null) ...[
                      const SizedBox(height: 6),
                      Flexible(
                        child: Text(
                          advert['cta_label'].toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Container(
                height: double.infinity,
                color: Colors.white,
                child: _advertImage(imageUrl, assetImage),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _advertImage(String? imageUrl, String? assetImage) {
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackImage(assetImage),
      );
    }
    return _fallbackImage(assetImage);
  }

  Widget _fallbackImage(String? assetImage) => Image.asset(
    assetImage ?? 'assets/images/hyperfeeds_logo.png',
    fit: assetImage == null ? BoxFit.contain : BoxFit.cover,
    errorBuilder: (_, __, ___) => const Icon(
      Icons.inventory_2_outlined,
      color: AppColors.primaryNavy,
      size: 48,
    ),
  );
}

class _CategoryShortcut extends StatelessWidget {
  final String? imagePath;
  final IconData? icon;
  final String title;
  final VoidCallback onTap;

  const _CategoryShortcut({
    this.imagePath,
    this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
                color: Colors.white,
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: icon != null
                  ? Icon(icon, size: 46, color: AppColors.primaryNavy)
                  : Image.asset(
                      imagePath!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.store,
                          color: AppColors.primaryNavy,
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NotificationInboxDialog extends ConsumerWidget {
  const _NotificationInboxDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationState = ref.watch(supportNotificationStateProvider);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.notifications_active, color: AppColors.brandOrange),
          SizedBox(width: 8),
          Text('Inbox Messages'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: notificationState.notifications.isEmpty
            ? const Center(
                child: Text(
                  'Your inbox is empty.',
                  style: TextStyle(color: AppColors.textLight),
                ),
              )
            : ListView.separated(
                itemCount: notificationState.notifications.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final notif = notificationState.notifications[index];
                  final isUnread = notif.readAt == null;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      notif.title,
                      style: TextStyle(
                        fontWeight: isUnread
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isUnread
                            ? AppColors.primaryNavy
                            : AppColors.textLight,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(notif.body),
                        const SizedBox(height: 4),
                        Text(
                          '${notif.createdAt.day}/${notif.createdAt.month} ${notif.createdAt.hour}:${notif.createdAt.minute.toString().padLeft(2, "0")}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                    trailing: isUnread
                        ? IconButton(
                            icon: const Icon(
                              Icons.mark_email_read,
                              color: AppColors.brandOrange,
                            ),
                            onPressed: () {
                              ref
                                  .read(
                                    supportNotificationStateProvider.notifier,
                                  )
                                  .markAsRead(notif.id);
                            },
                          )
                        : null,
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
