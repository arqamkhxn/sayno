import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/contract/application/contract_controller.dart';
import '../features/contract/presentation/contract_calendar_screen.dart';
import '../features/contract/presentation/contract_completion_screen.dart';
import '../features/contract/presentation/contract_create_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/health/presentation/health_screen.dart';
import '../features/protection/application/session_controller.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/settings/presentation/blocked_apps_screen.dart';
import '../features/settings/presentation/release_cooldown_screen.dart';
import '../features/settings/presentation/partner_setup_screen.dart';
import '../features/settings/presentation/verification_error_screen.dart';
import '../features/wallet/presentation/wallet_screen.dart';
import '../features/replacement/presentation/gateway_screen.dart';
import '../features/replacement/presentation/identity_setup_screen.dart';
import '../features/replacement/presentation/intentional_content_screen.dart';
import '../features/replacement/presentation/reflection_screen.dart';
import '../features/replacement/presentation/exit_summary_screen.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/email_login_screen.dart';
import '../features/auth/presentation/phone_login_screen.dart';
import '../features/content/presentation/intentional_home_screen.dart';
import '../features/content/presentation/feed_video_player_screen.dart';
import '../features/identity/application/identity_controller.dart';
import '../features/identity/presentation/identity_selection_screen.dart';
import '../features/identity/presentation/identity_priority_screen.dart';
import '../features/identity/presentation/identity_goals_screen.dart';
import '../features/identity/presentation/identity_review_screen.dart';
import '../shared/widgets/bottom_nav_bar.dart';

part 'app_router.g.dart';

class RouterListenable extends ChangeNotifier {
  final Ref _ref;
  RouterListenable(this._ref) {
    _ref.listen(activeContractProvider, (_, __) => notifyListeners());
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
    _ref.listen(identityControllerProvider, (_, __) => notifyListeners());
  }
}

@riverpod
GoRouter appRouter(Ref ref) {
  final refreshListenable = RouterListenable(ref);

  return GoRouter(
    initialLocation: '/dashboard',
    debugLogDiagnostics: false,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final activeContractAsync = ref.read(activeContractProvider);
      if (activeContractAsync.isLoading) return null;

      final activeContract = activeContractAsync.value;
      final nowUtc = getSystemTime().toUtc();

      final isContractCreateLoc = state.matchedLocation == '/contract/create';
      final isContractCompletionLoc = state.matchedLocation == '/contract/completion';

      if (activeContract != null) {
        final isExpired = activeContract.isExpired(nowUtc);

        if (isExpired) {
          if (!isContractCompletionLoc) {
            return '/contract/completion';
          }
        } else {
          if (isContractCreateLoc || isContractCompletionLoc) {
            return '/dashboard';
          }
        }
      } else {
        if (isContractCompletionLoc || state.matchedLocation == '/contract/calendar') {
          return '/dashboard';
        }
      }
      
      final isSplash = state.matchedLocation == '/';
      if (isSplash) {
        return '/dashboard';
      }
      
      final authStateAsync = ref.read(authStateProvider);
      final identityStateAsync = ref.read(identityControllerProvider);
      final authState = authStateAsync.value;
      final identityState = identityStateAsync.value;
      
      debugPrint('ROUTER REDIRECT CALLED | '
                 'Current loc: ${state.matchedLocation} | '
                 'AuthState: ${authState?.uid} (isLoading: ${authStateAsync.isLoading}) | '
                 'IdentityState: ${identityState?.id} (isLoading: ${identityStateAsync.isLoading})');
      
      final isLoginLoc = state.matchedLocation.startsWith('/login');

      // Enforce identity setup for authenticated users
      if (authState != null) {
        if (identityState == null && !state.uri.path.startsWith('/identity')) {
          debugPrint('ROUTER REDIRECTING | Current: ${state.matchedLocation} | Target: /identity/select | Reason: Authenticated but no identity');
          return '/identity/select';
        } else if (isLoginLoc) {
          debugPrint('ROUTER REDIRECTING | Current: ${state.matchedLocation} | Target: /dashboard | Reason: Authenticated user at login screen');
          return '/dashboard'; // Safe fallback when trying to reach login page while authenticated
        }
      }
      
      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppScaffoldWithNav(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/health',
                builder: (context, state) => const HealthScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const IntentionalHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/wallet',
                builder: (context, state) => const WalletScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'blocked-apps',
                    builder: (context, state) => const BlockedAppsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/contract/create',
        builder: (context, state) => const ContractCreateScreen(),
      ),
      GoRoute(
        path: '/contract/completion',
        builder: (context, state) => const ContractCompletionScreen(),
      ),
      GoRoute(
        path: '/contract/calendar',
        builder: (context, state) => const ContractCalendarScreen(),
      ),
      GoRoute(
        path: '/release-cooldown',
        builder: (context, state) => const ReleaseCooldownScreen(),
      ),
      GoRoute(
        path: '/partner-setup',
        builder: (context, state) => const PartnerSetupScreen(),
      ),
      GoRoute(
        path: '/verification-error',
        builder: (context, state) => const VerificationErrorScreen(),
      ),
      GoRoute(
        path: '/replacement/gateway',
        builder: (context, state) => const GatewayScreen(),
      ),
      GoRoute(
        path: '/replacement/identity',
        builder: (context, state) => const IdentitySetupScreen(),
      ),
      GoRoute(
        path: '/replacement/content',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>? ?? {};
          return IntentionalContentScreen(
            videoId: args['videoId'] as String? ?? '',
            title: args['title'] as String? ?? 'Content',
          );
        },
      ),
      GoRoute(
        path: '/replacement/reflection',
        builder: (context, state) => const ReflectionScreen(),
      ),
      GoRoute(
        path: '/replacement/exit_summary',
        builder: (context, state) => const ExitSummaryScreen(),
      ),
      GoRoute(
        path: '/content/player',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>? ?? {};
          return FeedVideoPlayerScreen(
            videoId: args['videoId'] as String? ?? '',
            title: args['title'] as String? ?? 'Content',
          );
        },
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/login/email',
        builder: (context, state) => const EmailLoginScreen(),
      ),
      GoRoute(
        path: '/login/phone',
        builder: (context, state) => const PhoneLoginScreen(),
      ),
      GoRoute(
        path: '/identity/select',
        builder: (context, state) => const IdentitySelectionScreen(),
      ),
      GoRoute(
        path: '/identity/priority',
        builder: (context, state) => const IdentityPriorityScreen(),
      ),
      GoRoute(
        path: '/identity/goals',
        builder: (context, state) => const IdentityGoalsScreen(),
      ),
      GoRoute(
        path: '/identity/review',
        builder: (context, state) => const IdentityReviewScreen(),
      ),
    ],
  );
}
