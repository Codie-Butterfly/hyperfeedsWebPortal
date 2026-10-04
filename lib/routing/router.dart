import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/branch_provider.dart';

// Screens
import '../screens/welcome_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/verify_otp_screen.dart';
import '../screens/auth/employee_login_screen.dart';
import '../screens/branch_selection_screen.dart';
import '../screens/customer/navigation_shell.dart';
import '../screens/customer/home_tab.dart';
import '../screens/customer/shop_tab.dart';
import '../screens/customer/chicks_tab.dart';
import '../screens/customer/ask_tab.dart';
import '../screens/customer/account_tab.dart';
import '../screens/customer/feed_calculator_screen.dart';
import '../screens/employee/admin_dashboard.dart';
import '../screens/employee/executive_dashboard.dart';
import '../screens/employee/main_manager_dashboard.dart';
import '../screens/employee/manager_dashboard.dart';
import '../screens/employee/expert_dashboard.dart';
import '../screens/employee/customer_service_dashboard.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: kIsWeb ? '/employee-login' : '/welcome',
    refreshListenable: Listenable.merge([
      _StateNotifierListenable(ref.read(authStateProvider.notifier)),
      _StateNotifierListenable(ref.read(branchStateProvider.notifier)),
    ]),
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final branchState = ref.read(branchStateProvider);

      final isAuthenticated = authState.isAuthenticated;
      final isVerificationPending = authState.isVerificationPending;
      final role = authState.role;
      final hasSelectedBranch = branchState.selectedBranch != null;

      final currentLoc = state.uri.path;
      final isAuthPath =
          currentLoc.startsWith('/welcome') ||
          currentLoc.startsWith('/signup') ||
          currentLoc.startsWith('/verify-otp') ||
          currentLoc.startsWith('/employee-login');

      // 1. If not authenticated
      if (!isAuthenticated) {
        if (kIsWeb) {
          return currentLoc == '/employee-login' ? null : '/employee-login';
        }
        if (isVerificationPending) {
          return '/verify-otp';
        }
        if (!isAuthPath) {
          return '/welcome';
        }
        return null;
      }

      // Staff web navigation always follows the authenticated role. API permissions
      // remain authoritative for every action and branch-scoped request.
      if (kIsWeb && role != UserRole.customer) {
        final home = switch (role) {
          UserRole.admin => '/admin',
          UserRole.ceo => '/ceo',
          UserRole.mainManager => '/main-manager',
          UserRole.branchManager => '/manager',
          UserRole.customerService => '/customer-service',
          UserRole.animalHealthExpert => '/expert',
          _ => '/employee-login',
        };
        if (currentLoc != home) return home;
        return null;
      }

      // 2. If authenticated, prevent going to auth screens
      if (isAuthPath) {
        if (role == UserRole.customer) {
          return hasSelectedBranch ? '/home' : '/branch-selection';
        } else {
          // Employee dashboard routing
          switch (role) {
            case UserRole.admin:
              return '/admin';
            case UserRole.ceo:
              return '/ceo';
            case UserRole.mainManager:
              return '/main-manager';
            case UserRole.branchManager:
              return '/manager';
            case UserRole.customerService:
              return '/customer-service';
            case UserRole.animalHealthExpert:
              return '/expert';
            default:
              return '/welcome';
          }
        }
      }

      // 3. For customer routing: must have a branch selected
      if (role == UserRole.customer) {
        if (!hasSelectedBranch && currentLoc != '/branch-selection') {
          return '/branch-selection';
        }
      }

      return null;
    },
    routes: [
      // Auth routes
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/verify-otp',
        builder: (context, state) => const VerifyOtpScreen(),
      ),
      GoRoute(
        path: '/employee-login',
        builder: (context, state) => const EmployeeLoginScreen(),
      ),
      GoRoute(
        path: '/branch-selection',
        builder: (context, state) => const BranchSelectionScreen(),
      ),

      // Customer app main tabs (using ShellRoute to display bottom navigation bar)
      ShellRoute(
        builder: (context, state, child) => NavigationShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (context, state) => const HomeTab()),
          GoRoute(path: '/shop', builder: (context, state) => const ShopTab()),
          GoRoute(
            path: '/chicks',
            builder: (context, state) => const ChicksTab(),
          ),
          GoRoute(path: '/ask', builder: (context, state) => const AskTab()),
          GoRoute(
            path: '/account',
            builder: (context, state) => const AccountTab(),
          ),
          GoRoute(
            path: '/feed-calculator',
            builder: (context, state) => const FeedCalculatorScreen(),
          ),
        ],
      ),

      // Employee dashboards
      GoRoute(
        path: '/ceo',
        builder: (context, state) => const ExecutiveDashboard(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboard(),
      ),
      GoRoute(
        path: '/main-manager',
        builder: (context, state) => const MainManagerDashboard(),
      ),
      GoRoute(
        path: '/manager',
        builder: (context, state) => const ManagerDashboard(),
      ),
      GoRoute(
        path: '/expert',
        builder: (context, state) => const ExpertDashboard(),
      ),
      GoRoute(
        path: '/customer-service',
        builder: (context, state) => const CustomerServiceDashboard(),
      ),
    ],
  );
});

// Helper class to convert StateNotifier to Listenable for GoRouter
class _StateNotifierListenable extends ChangeNotifier {
  final StateNotifier _notifier;
  _StateNotifierListenable(this._notifier) {
    _notifier.addListener((_) {
      notifyListeners();
    });
  }
}
