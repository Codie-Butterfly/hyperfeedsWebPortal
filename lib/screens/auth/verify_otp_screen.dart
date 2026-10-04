import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../constants/theme.dart';
import '../../providers/auth_provider.dart';

class VerifyOtpScreen extends ConsumerStatefulWidget {
  const VerifyOtpScreen({super.key});

  @override
  ConsumerState<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends ConsumerState<VerifyOtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  Timer? _timer;
  int _secondsRemaining = 30;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _secondsRemaining = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _timer?.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authStateProvider.notifier).verifyOtp(
          _codeController.text.trim(),
        );

    if (mounted) {
      if (success) {
        context.go('/branch-selection');
      } else {
        final error = ref.read(authStateProvider).error ?? 'Invalid verification code';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _cancel() {
    ref.read(authStateProvider.notifier).cancelSignup();
    context.go('/welcome');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phone Verification'),
        actions: [
          TextButton(
            onPressed: _cancel,
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24.0),
                const Icon(
                  Icons.sms_failed_outlined,
                  size: 80,
                  color: AppColors.brandOrange,
                ),
                const SizedBox(height: 24.0),
                const Text(
                  'Verify Your Number',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24.0,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryNavy,
                  ),
                ),
                const SizedBox(height: 8.0),
                Text(
                  'A 6-digit OTP code has been sent to ${authState.maskedPhone ?? "your phone number"}. Enter the code below.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textLight, fontSize: 14.0),
                ),
                const SizedBox(height: 32.0),
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24.0, letterSpacing: 8.0, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    labelText: 'Verification Code',
                    counterText: '',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Enter the code';
                    if (val.length != 6 || int.tryParse(val) == null) {
                      return 'Code must be exactly 6 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Didn\'t receive code? '),
                    if (_secondsRemaining > 0)
                      Text(
                        'Resend in ${_secondsRemaining}s',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textLight),
                      )
                    else
                      TextButton(
                        onPressed: () {
                          // Resend challenge by going back/signup or triggering fresh signup
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please go back to request a new code.'),
                            ),
                          );
                        },
                        child: const Text(
                          'Request Again',
                          style: TextStyle(color: AppColors.brandOrange, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 32.0),
                ElevatedButton(
                  onPressed: authState.isLoading ? null : _verify,
                  child: authState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Verify & Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
