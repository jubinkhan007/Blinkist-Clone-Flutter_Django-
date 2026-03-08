import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

final goRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) =>
          const PlaceholderScreen(title: 'Splash / Auth Check'),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const PlaceholderScreen(title: 'Login'),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const PlaceholderScreen(title: 'Home'),
    ),
  ],
);

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('Placeholder for $title')),
    );
  }
}
