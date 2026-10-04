import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../constants/theme.dart';

import '../../providers/auth_provider.dart';
import '../../providers/order_booking_provider.dart';

class AccountTab extends ConsumerWidget {
  const AccountTab({super.key});

  Future<void> _editEmail(
    BuildContext context,
    WidgetRef ref,
    String? current,
  ) async {
    final controller = TextEditingController(text: current ?? '');
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Update email address'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Email address',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null || email.isEmpty || !context.mounted) return;
    final ok = await ref
        .read(authStateProvider.notifier)
        .updateCustomerEmail(email);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Email address updated.'
              : ref.read(authStateProvider).error ?? 'Could not update email.',
        ),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderBookingState = ref.watch(orderBookingStateProvider);
    final customerProfile = ref.watch(authStateProvider).customerProfile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Account'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(orderBookingStateProvider.notifier).refreshAll(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(orderBookingStateProvider.notifier).refreshAll(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile Section
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.primaryNavy,
                        foregroundColor: Colors.white,
                        child: Icon(Icons.person, size: 36),
                      ),
                      const SizedBox(width: 16.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customerProfile == null
                                  ? 'Hyperfeeds Customer'
                                  : '${customerProfile.firstName} ${customerProfile.lastName}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18.0,
                                color: AppColors.primaryNavy,
                              ),
                            ),
                            const SizedBox(height: 4.0),
                            Text(
                              customerProfile?.phoneNumber ??
                                  'Customer Account',
                              style: const TextStyle(
                                color: AppColors.textLight,
                                fontSize: 13.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, color: AppColors.error),
                        onPressed: () {
                          ref.read(authStateProvider.notifier).logout();
                        },
                        tooltip: 'Logout',
                      ),
                    ],
                  ),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.email_outlined,
                    color: AppColors.primaryNavy,
                  ),
                  title: const Text('Email address'),
                  subtitle: Text(
                    customerProfile?.email?.isNotEmpty == true
                        ? customerProfile!.email!
                        : 'Required for online payment',
                  ),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _editEmail(context, ref, customerProfile?.email),
                ),
              ),
              const SizedBox(height: 24.0),

              // Chick Bookings list
              const Text(
                'My Chick Bookings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 12.0),
              orderBookingState.bookings.isEmpty
                  ? const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'No chick bookings found.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textLight),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: orderBookingState.bookings.length,
                      itemBuilder: (context, index) {
                        final booking = orderBookingState.bookings[index];
                        final isOrdered = booking.status == 'ORDERED';
                        final canCancel =
                            isOrdered &&
                            booking.cutoffAt.isAfter(DateTime.now());
                        final cutoffText = DateFormat(
                          'yyyy-MM-dd HH:mm',
                        ).format(booking.cutoffAt.toLocal());
                        final deliveryText = DateFormat(
                          'EEEE, d MMMM yyyy',
                        ).format(DateTime.parse(booking.deliveryDate));

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12.0),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      booking.reference,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0,
                                        vertical: 4.0,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isOrdered
                                            ? AppColors.warning.withOpacity(0.1)
                                            : booking.status == 'CONFIRMED'
                                            ? AppColors.success.withOpacity(0.1)
                                            : AppColors.textLight.withOpacity(
                                                0.1,
                                              ),
                                        borderRadius: BorderRadius.circular(
                                          4.0,
                                        ),
                                      ),
                                      child: Text(
                                        booking.status,
                                        style: TextStyle(
                                          fontSize: 10.0,
                                          fontWeight: FontWeight.bold,
                                          color: isOrdered
                                              ? AppColors.warning
                                              : booking.status == 'CONFIRMED'
                                              ? AppColors.success
                                              : AppColors.textLight,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8.0),
                                Text('${booking.chickType} • ${booking.breed}'),
                                const SizedBox(height: 4.0),
                                Text('Quantity: ${booking.quantity} chicks'),
                                const SizedBox(height: 4.0),
                                Text(
                                  'Bill: ${booking.currency} ${booking.totalAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4.0),
                                Text('Expected pickup: $deliveryText'),
                                const SizedBox(height: 4.0),
                                Text(
                                  'Batch cutoff: $cutoffText',
                                  style: const TextStyle(
                                    fontSize: 11.0,
                                    color: AppColors.textLight,
                                  ),
                                ),
                                if (canCancel) ...[
                                  const SizedBox(height: 12.0),
                                  OutlinedButton(
                                    onPressed: orderBookingState.isSubmitting
                                        ? null
                                        : () async {
                                            final ok = await ref
                                                .read(
                                                  orderBookingStateProvider
                                                      .notifier,
                                                )
                                                .cancelBooking(booking.id);
                                            if (context.mounted && ok) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Booking cancelled successfully.',
                                                  ),
                                                  backgroundColor:
                                                      AppColors.success,
                                                ),
                                              );
                                            }
                                          },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.error,
                                      side: const BorderSide(
                                        color: AppColors.error,
                                      ),
                                      minimumSize: const Size(
                                        double.infinity,
                                        36,
                                      ),
                                    ),
                                    child: orderBookingState.isSubmitting
                                        ? const SizedBox(
                                            height: 16,
                                            width: 16,
                                            child: CircularProgressIndicator(
                                              color: AppColors.error,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text('Cancel Holding'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),

              const SizedBox(height: 24.0),

              // Orders List
              const Text(
                'My Feed Orders',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 12.0),
              orderBookingState.orders.isEmpty
                  ? const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'No orders found.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textLight),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: orderBookingState.orders.length,
                      itemBuilder: (context, index) {
                        final order = orderBookingState.orders[index];
                        final formatter = DateFormat('yyyy-MM-dd HH:mm');
                        final dateText = formatter.format(order.createdAt);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12.0),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 8.0,
                            ),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  order.reference,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${order.currency} ${order.total.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.brandOrange,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4.0),
                                Text('Date: $dateText'),
                                const SizedBox(height: 4.0),
                                Row(
                                  children: [
                                    const Text('Status: '),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: order.status == 'CONFIRMED'
                                            ? AppColors.success.withOpacity(0.1)
                                            : AppColors.warning.withOpacity(
                                                0.1,
                                              ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        order.status,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: order.status == 'CONFIRMED'
                                              ? AppColors.success
                                              : AppColors.warning,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
              const SizedBox(height: 24.0),
            ],
          ),
        ),
      ),
    );
  }
}
