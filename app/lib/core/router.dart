import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:starpath/core/constants.dart';
import 'package:starpath/features/auth/data/auth_provider.dart';
import 'package:starpath/features/auth/presentation/login_page.dart';
import 'package:starpath/features/onboarding/presentation/onboarding_page.dart';
import 'package:starpath/features/agent_studio/presentation/agent_create_page.dart';
import 'package:starpath/features/agent_studio/presentation/agent_studio_page.dart';
import 'package:starpath/features/agent_studio/presentation/partner_background_editor_page.dart';
import 'package:starpath/features/agent_studio/presentation/partner_personality_editor_page.dart';
import 'package:starpath/features/chat/presentation/chat_list_page.dart';
import 'package:starpath/features/chat/presentation/chat_detail_page.dart';
import 'package:starpath/features/chat/presentation/user_dm_detail_page.dart';
import 'package:starpath/features/chat/presentation/notification_inbox_page.dart';
import 'package:starpath/features/discovery/presentation/discovery_page.dart';
import 'package:starpath/features/discovery/presentation/card_detail_page.dart';
import 'package:starpath/features/discovery/domain/card_model.dart';
import 'package:starpath/features/creation/presentation/create_card_page.dart';
import 'package:starpath/features/profile/presentation/edit_profile_page.dart';
import 'package:starpath/features/profile/presentation/profile_page.dart';
import 'package:starpath/features/profile/presentation/settings_page.dart';
import 'package:starpath/features/profile/presentation/user_profile_view_page.dart';
import 'package:starpath/features/profile/presentation/wallet_page.dart';
import 'package:starpath/shared/widgets/animated_navigation_shell_body.dart';
import 'package:starpath/shared/widgets/main_scaffold.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter(WidgetRef ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/discovery',
    redirect: (context, state) {
      final loc = state.uri.path;
      if (loc == '/' || loc.isEmpty) {
        return '/discovery';
      }

      final isLoginRoute = state.matchedLocation == '/login';
      final isOnboardingRoute = state.matchedLocation == '/onboarding';

      if (AppConstants.skipAuthForPreview) {
        if (isLoginRoute || isOnboardingRoute) {
          return '/discovery';
        }
        return null;
      }

      if (!authState.isLoggedIn) {
        return isLoginRoute ? null : '/login';
      }

      if (!authState.hasCompletedOnboarding) {
        return isOnboardingRoute ? null : '/onboarding';
      }

      if (isLoginRoute || isOnboardingRoute) {
        return '/discovery';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) => '/discovery',
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      StatefulShellRoute(
        builder: (context, state, navigationShell) {
          return MainScaffold(navigationShell: navigationShell);
        },
        navigatorContainerBuilder: (context, navigationShell, children) {
          return AnimatedNavigationShellBody(
            currentIndex: navigationShell.currentIndex,
            children: children,
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/discovery',
                builder: (context, state) => const DiscoveryPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chat',
                builder: (context, state) => const ChatListPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/agents',
                builder: (context, state) => const AgentStudioPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/create',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CreateCardPage(),
      ),
      GoRoute(
        path: '/agents/create',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AgentCreatePage(),
      ),
      GoRoute(
        path: '/agents/:agentId/personality',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final agentId = state.pathParameters['agentId']!;
          return PartnerPersonalityEditorPage(agentId: agentId);
        },
      ),
      GoRoute(
        path: '/agents/background-editor',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PartnerBackgroundEditorPage(),
      ),
      GoRoute(
        path: '/dm/:peerId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['peerId']!;
          return UserDmDetailPage(peerId: id);
        },
      ),
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final kind = state.uri.queryParameters['kind'] ?? 'mentions';
          return NotificationInboxPage(kind: kind);
        },
      ),
      GoRoute(
        path: '/chat/:conversationId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['conversationId']!;
          return ChatDetailPage(conversationId: id);
        },
      ),
      GoRoute(
        path: '/chat/agent/:agentId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final agentId     = state.pathParameters['agentId']!;
          final agentName   = state.uri.queryParameters['agentName'];
          final helloVideo  = state.uri.queryParameters['helloVideo'];
          final haitVideo   = state.uri.queryParameters['haitVideo'];
          final breatheVideo = state.uri.queryParameters['breatheVideo'];
          final downVideo   = state.uri.queryParameters['downVideo'];
          return ChatDetailPage(
            agentId:      agentId,
            agentName:    agentName,
            helloVideo:   helloVideo,
            haitVideo:    haitVideo,
            breatheVideo: breatheVideo,
            downVideo:    downVideo,
          );
        },
      ),
      GoRoute(
        path: '/wallet',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const WalletPage(),
      ),
      GoRoute(
        path: '/profile/edit',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const EditProfilePage(),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/cards/:cardId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['cardId']!;
          final extra = state.extra;
          return CardDetailPage(
            cardId: id,
            initialCard: extra is ContentCardModel ? extra : null,
          );
        },
      ),
      GoRoute(
        path: '/u/:userId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['userId']!;
          return UserProfileViewPage(userId: id);
        },
      ),
    ],
  );
}
