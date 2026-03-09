import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/auth_repository.dart';
import '../../../../core/subscription/subscription_repository.dart';
import '../../auth/presentation/auth_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStatusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: authAsync.when(
        data: (loggedIn) {
          if (!loggedIn) {
            return const AuthScreen();
          }

          final subAsync = ref.watch(subscriptionInfoProvider);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'You are signed in.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              subAsync.when(
                data: (sub) {
                  if (sub == null) return const Text('Could not load /me/');
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Premium: ${sub.isPremium ? "Yes" : "No"}'),
                      Text('Status: ${sub.subscriptionStatus ?? "-"}'),
                      Text('Trial days remaining: ${sub.trialDaysRemaining}'),
                      if (sub.subscriptionEndDate != null)
                        Text('Ends: ${sub.subscriptionEndDate}'),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(),
                ),
                error: (e, _) => Text('Failed to load subscription: $e'),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(subscriptionInfoProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh subscription'),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () async {
                  await ref.read(authRepositoryProvider).logout();
                  ref.invalidate(authStatusProvider);
                  ref.invalidate(subscriptionInfoProvider);
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load auth status: $e')),
      ),
    );
  }
}
