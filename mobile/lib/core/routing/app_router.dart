import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../src/features/home/presentation/home_screen.dart';
import '../../src/features/explore/presentation/explore_screen.dart';
import '../../src/features/book/presentation/book_detail_screen.dart';
import '../../src/features/reader/presentation/reader_screen.dart';
import '../../src/features/reader/presentation/audio_player_screen.dart';
import '../../src/features/reader/presentation/full_book_screen.dart';
import '../../src/features/profile/presentation/edit_profile_screen.dart';
import '../../src/features/profile/presentation/profile_screen.dart';
import '../../src/features/library/presentation/downloads_screen.dart';
import '../../src/features/subscription/presentation/payment_return_screen.dart';
import '../../src/features/subscription/presentation/paywall_screen.dart';
import '../../src/features/notifications/presentation/notifications_screen.dart';
import '../../src/features/onboarding/presentation/onboarding_screen.dart';
import '../../src/features/catalog/presentation/collection_detail_screen.dart';
import '../../src/features/progress/presentation/reading_stats_screen.dart';
import 'deep_link_service.dart';

// Keys for nested navigation
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      final rawPath = state.uri.toString();
      if (rawPath.startsWith('blinkist:') || rawPath.contains('blinkist.com')) {
        return DeepLinkService.normalize(rawPath);
      }
      return null;
    },
    routes: [
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return AppScaffold(child: child);
        },
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          GoRoute(
            path: '/explore',
            builder: (context, state) {
              return ExploreScreen(
                initialCategorySlug: state.uri.queryParameters['category'],
                initialQuery: state.uri.queryParameters['search'] ??
                    state.uri.queryParameters['q'],
                initialFormat: state.uri.queryParameters['format'],
                initialDuration: state.uri.queryParameters['duration'],
                initialSortBy: state.uri.queryParameters['sort'] ??
                    state.uri.queryParameters['sort_by'],
              );
            },
          ),
          GoRoute(
            path: '/library',
            builder: (context, state) {
              final tab = state.uri.queryParameters['tab'];
              return DownloadsScreen(initialTab: tab);
            },
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      // Future routes (Login, Book Detail, Player) go here OUTSIDE the shell
      // so they can hide the bottom navigation bar.
      GoRoute(
        path: '/books/:slug',
        builder: (context, state) {
          final slug = state.pathParameters['slug']!;
          return BookDetailScreen(slug: slug);
        },
      ),
      GoRoute(
        path: '/books/:slug/read',
        builder: (context, state) {
          final slug = state.pathParameters['slug']!;
          return ReaderScreen(slug: slug);
        },
      ),
      GoRoute(
        path: '/books/:slug/listen',
        builder: (context, state) {
          final slug = state.pathParameters['slug']!;
          final secParam = state.uri.queryParameters['section'];
          final posParam = state.uri.queryParameters['pos'];
          final initialSection =
              secParam != null ? int.tryParse(secParam) : null;
          final initialPos = posParam != null ? int.tryParse(posParam) : null;
          return AudioPlayerScreen(
            slug: slug,
            initialSectionIndex: initialSection,
            initialPositionSeconds: initialPos,
          );
        },
      ),
      GoRoute(
        path: '/books/:slug/full',
        builder: (context, state) {
          final slug = state.pathParameters['slug']!;
          return FullBookScreen(slug: slug);
        },
      ),
      GoRoute(
        path: '/paywall',
        builder: (context, state) {
          final slug = state.uri.queryParameters['slug'];
          final title = state.uri.queryParameters['title'];
          return PaywallScreen(bookSlug: slug, bookTitle: title);
        },
      ),
      GoRoute(
        path: '/payment-return',
        builder: (context, state) {
          final status = state.uri.queryParameters['status'] ?? 'unknown';
          final tranId = state.uri.queryParameters['tran_id'];
          return PaymentReturnScreen(status: status, tranId: tranId);
        },
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/collections/:slug',
        builder: (context, state) {
          final slug = state.pathParameters['slug']!;
          return CollectionDetailScreen(slug: slug);
        },
      ),
      GoRoute(
        path: '/stats',
        builder: (context, state) => const ReadingStatsScreen(),
      ),
    ],
  );
});

// Basic Bottom Navigation Scaffold
class AppScaffold extends StatelessWidget {
  final Widget child;

  const AppScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _calculateSelectedIndex(context),
        onDestinationSelected: (int index) => _onItemTapped(index, context),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_books_outlined),
            selectedIcon: Icon(Icons.library_books),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  static int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/explore')) {
      return 1;
    }
    if (location.startsWith('/library')) {
      return 2;
    }
    if (location.startsWith('/profile')) {
      return 3;
    }
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/explore');
        break;
      case 2:
        context.go('/library');
        break;
      case 3:
        context.go('/profile');
        break;
    }
  }
}
