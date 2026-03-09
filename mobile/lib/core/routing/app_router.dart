import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../src/features/home/presentation/home_screen.dart';
import '../../src/features/explore/presentation/explore_screen.dart';
import '../../src/features/book/presentation/book_detail_screen.dart';
import '../../src/features/reader/presentation/reader_screen.dart';
import '../../src/features/reader/presentation/audio_player_screen.dart';
import '../../src/features/reader/presentation/full_book_screen.dart';
import '../../src/features/profile/presentation/profile_screen.dart';
import '../../src/features/subscription/presentation/paywall_screen.dart';

// Keys for nested navigation
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
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
            builder: (context, state) => const ExploreScreen(),
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
          return AudioPlayerScreen(slug: slug);
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
    if (location.startsWith('/profile')) {
      return 2;
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
        context.go('/profile');
        break;
    }
  }
}
