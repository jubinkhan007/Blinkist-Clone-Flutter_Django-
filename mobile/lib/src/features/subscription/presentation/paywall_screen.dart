import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/subscription/subscription_repository.dart';

class PaywallScreen extends ConsumerWidget {
  final String? bookSlug;
  final String? bookTitle;

  const PaywallScreen({super.key, this.bookSlug, this.bookTitle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAsync = ref.watch(subscriptionInfoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Go Premium')),
      body: subAsync.when(
        data: (sub) {
          final isSignedOut = sub == null;
          final trialDays = sub?.trialDaysRemaining ?? 0;
          final status = sub?.subscriptionStatus ?? 'signed_out';
          final isPremium = sub?.isPremium ?? false;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (bookTitle != null) ...[
                Text(bookTitle!, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
              ],
              Text(
                'Unlock audio, full summaries, and offline downloads.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              _Bullet(text: 'Listen to audio summaries'),
              _Bullet(text: 'Read full book summaries'),
              _Bullet(text: 'Download for offline'),
              const SizedBox(height: 24),
              Row(
                children: [
                  Chip(label: Text('Status: $status')),
                  const SizedBox(width: 8),
                  Chip(label: Text('Trial: $trialDays day(s) left')),
                ],
              ),
              const SizedBox(height: 16),
              if (isPremium)
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('You are Premium'),
                )
              else if (isSignedOut)
                FilledButton.icon(
                  onPressed: () => context.go('/profile'),
                  icon: const Icon(Icons.person),
                  label: const Text('Sign in to Subscribe'),
                )
              else
                FilledButton(
                  onPressed: () async {
                    try {
                      final repo = ref.read(subscriptionRepositoryProvider);
                      final initiation = await repo.initiatePayment();
                      if (!context.mounted) return;

                      final uri = Uri.parse(initiation.gatewayUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
                      } else {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not open payment link.'),
                          ),
                        );
                      }
                    } on DioException catch (e) {
                      if (!context.mounted) return;
                      if (e.response?.statusCode == 401) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please sign in to subscribe.'),
                          ),
                        );
                        context.go('/profile');
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Subscribe failed: ${e.message}'),
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Subscribe failed: $e')),
                      );
                    }
                  },
                  child: const Text('Subscribe'),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(subscriptionInfoProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
              if (sub == null) ...[
                const SizedBox(height: 12),
                Text(
                  'Note: you appear to be signed out (no token). Log in to start a trial and subscribe.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => context.go('/profile'),
                  icon: const Icon(Icons.person),
                  label: const Text('Go to Account'),
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load subscription: $e')),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;

  const _Bullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
