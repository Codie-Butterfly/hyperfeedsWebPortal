import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/theme.dart';
import '../providers/branch_provider.dart';

class BranchSelectionScreen extends ConsumerWidget {
  const BranchSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchState = ref.watch(branchStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select a Branch'),
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(branchStateProvider.notifier).fetchBranches(),
        child: Column(
          children: [
            if (branchState.isOffline)
              Container(
                color: AppColors.warning,
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: const Row(
                  children: [
                    Icon(Icons.wifi_off, color: Colors.white),
                    SizedBox(width: 8.0),
                    Expanded(
                      child: Text(
                        'Offline mode. Showing cached branches.',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: branchState.isLoading && branchState.branches.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : branchState.branches.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                            const Center(
                              child: Text(
                                'No branches available.\nSwipe down to retry.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textLight, fontSize: 16.0),
                              ),
                            ),
                          ],
                        )
                      : Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12.0),
                                child: Text(
                                  'Choose your default branch for catalog browsing and pickup orders:',
                                  style: TextStyle(
                                    fontSize: 16.0,
                                    color: AppColors.textDark,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: branchState.branches.length,
                                  itemBuilder: (context, index) {
                                    final branch = branchState.branches[index];
                                    final isSelected = branchState.selectedBranch?.id == branch.id;

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 12.0),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16.0),
                                        side: BorderSide(
                                          color: isSelected ? AppColors.brandOrange : AppColors.border,
                                          width: isSelected ? 2.0 : 1.0,
                                        ),
                                      ),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16.0,
                                          vertical: 8.0,
                                        ),
                                        leading: CircleAvatar(
                                          backgroundColor: isSelected
                                              ? AppColors.brandOrange.withOpacity(0.1)
                                              : AppColors.primaryNavy.withOpacity(0.05),
                                          foregroundColor: isSelected ? AppColors.brandOrange : AppColors.primaryNavy,
                                          child: const Icon(Icons.store),
                                        ),
                                        title: Text(
                                          branch.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16.0,
                                            color: AppColors.primaryNavy,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 4.0),
                                            Text(branch.address),
                                            const SizedBox(height: 2.0),
                                            Text(
                                              'Phone: ${branch.phoneNumber}',
                                              style: const TextStyle(fontSize: 12.0),
                                            ),
                                            if (branch.openingHours != null) ...[
                                              const SizedBox(height: 2.0),
                                              Text(
                                                'Hours: ${branch.openingHours}',
                                                style: const TextStyle(fontSize: 12.0),
                                              ),
                                            ],
                                          ],
                                        ),
                                        trailing: isSelected
                                            ? const Icon(Icons.check_circle, color: AppColors.brandOrange)
                                            : const Icon(Icons.chevron_right),
                                        onTap: () async {
                                          await ref.read(branchStateProvider.notifier).selectBranch(branch);
                                          if (context.mounted) {
                                            context.go('/home');
                                          }
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
