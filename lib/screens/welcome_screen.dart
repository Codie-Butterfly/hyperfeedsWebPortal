import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/theme.dart';
import '../providers/auth_provider.dart';
import 'auth/signup_screen.dart';
import 'auth/employee_login_screen.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    return Scaffold(
      backgroundColor: AppColors.primaryNavy,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Hero(
                  tag: 'logo',
                  child: Image.asset(
                    'assets/images/hyperfeeds_logo.png',
                    height: 160.0,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.agriculture,
                        size: 100,
                        color: AppColors.brandOrange,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24.0),
              const Text(
                'HYPERFEEDS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32.0,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 12.0),
              const Text(
                'Premium feed, day-old chick bookings, and expert livestock advice directly to your farm.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.border,
                  fontSize: 16.0,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: auth.isLoading
                    ? null
                    : () async {
                        final restored = await ref
                            .read(authStateProvider.notifier)
                            .checkInitialSession();
                        if (!context.mounted) return;
                        if (!restored) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SignupScreen(),
                            ),
                          );
                        }
                      },
                child: const Text('Customer Portal'),
              ),
              const SizedBox(height: 16.0),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const EmployeeLoginScreen(),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white, width: 1.5),
                ),
                child: const Text('Employee Login'),
              ),
              const SizedBox(height: 16.0),
              const Text(
                'Hyperfeeds Mobile • v1.0.0',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white24, fontSize: 12.0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
