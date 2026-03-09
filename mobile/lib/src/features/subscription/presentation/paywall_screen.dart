import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
              else
                FilledButton(
                  onPressed: () async {
                    final repo = ref.read(subscriptionRepositoryProvider);
                    final initiation = await repo.initiatePayment();
                    if (!context.mounted) return;

                    await showModalBottomSheet<void>(
                      context: context,
                      showDragHandle: true,
                      builder: (_) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payment Link (${initiation.mode})',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            SelectableText(initiation.gatewayUrl),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                FilledButton.icon(
                                  onPressed: initiation.gatewayUrl.isEmpty
                                      ? null
                                      : () async {
                                          await Clipboard.setData(
                                            ClipboardData(
                                              text: initiation.gatewayUrl,
                                            ),
                                          );
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('Link copied'),
                                            ),
                                          );
                                        },
                                  icon: const Icon(Icons.copy),
                                  label: const Text('Copy link'),
                                ),
                                const SizedBox(width: 12),
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'After completing payment, return to the app and tap Refresh.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    );
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
