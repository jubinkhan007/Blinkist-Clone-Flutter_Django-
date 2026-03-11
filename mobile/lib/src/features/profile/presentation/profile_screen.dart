import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/auth/auth_repository.dart';
import '../../../../core/subscription/subscription_repository.dart';
import '../../auth/presentation/auth_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStatusProvider);

    // Show full-screen auth when logged out — no AppBar wrapper
    if (authAsync.valueOrNull == false) {
      return const AuthScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(subscriptionInfoProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: authAsync.when(
        data: (loggedIn) {
          if (!loggedIn) return const AuthScreen();

          final subAsync = ref.watch(subscriptionInfoProvider);
          return subAsync.when(
            data: (sub) {
              if (sub == null) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Session expired',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please sign in again to manage your subscription.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () async {
                          await ref.read(authRepositoryProvider).logout();
                          ref.invalidate(authStatusProvider);
                          ref.invalidate(subscriptionInfoProvider);
                        },
                        icon: const Icon(Icons.login),
                        label: const Text('Sign in'),
                      ),
                    ],
                  ),
                );
              }

              final fullName = [
                sub.firstName?.trim(),
                sub.lastName?.trim(),
              ].whereType<String>().where((s) => s.isNotEmpty).join(' ');
              final displayName = fullName.isNotEmpty
                  ? fullName
                  : (sub.username?.trim().isNotEmpty == true
                        ? sub.username!.trim()
                        : (sub.email ?? ''));
              final initials = displayName.isNotEmpty
                  ? displayName
                        .split(RegExp(r'\\s+'))
                        .where((p) => p.isNotEmpty)
                        .take(2)
                        .map((p) => p.characters.first.toUpperCase())
                        .join()
                  : 'U';

              final status = sub.subscriptionStatus ?? 'unknown';
              final isTrial = status == 'trialing';
              final trialDays = sub.trialDaysRemaining;
              final trialProgress = isTrial
                  ? ((7 - trialDays).clamp(0, 7) / 7.0)
                  : null;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    elevation: 0,
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                            backgroundImage:
                                (sub.avatarUrl?.isNotEmpty ?? false)
                                ? NetworkImage(sub.avatarUrl!)
                                : null,
                            child: (sub.avatarUrl?.isNotEmpty ?? false)
                                ? null
                                : Text(
                                    initials,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if ((sub.email ?? '').isNotEmpty)
                                  Text(
                                    sub.email!,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusPill(
                            label: sub.isPremium ? 'Premium' : 'Free',
                            icon: sub.isPremium
                                ? Icons.verified
                                : Icons.lock_open,
                            color: sub.isPremium
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.workspace_premium,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Subscription',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _KeyValue(
                            icon: Icons.shield_outlined,
                            label: 'Status',
                            value: status,
                          ),
                          if (isTrial) ...[
                            const SizedBox(height: 10),
                            _KeyValue(
                              icon: Icons.timer_outlined,
                              label: 'Trial remaining',
                              value: '$trialDays day(s)',
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: trialProgress,
                                minHeight: 8,
                              ),
                            ),
                          ],
                          if (sub.subscriptionEndDate != null) ...[
                            const SizedBox(height: 10),
                            _KeyValue(
                              icon: Icons.event_outlined,
                              label: 'Renews/ends',
                              value: sub.subscriptionEndDate
                                  .toString()
                                  .split('.')
                                  .first,
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => context.push('/paywall'),
                                  icon: const Icon(Icons.manage_accounts),
                                  label: Text(
                                    sub.isPremium ? 'Manage plan' : 'Upgrade',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton.filledTonal(
                                tooltip: 'Refresh',
                                onPressed: () =>
                                    ref.invalidate(subscriptionInfoProvider),
                                icon: const Icon(Icons.refresh),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.help_outline),
                          title: const Text('Help & support'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: null,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.privacy_tip_outlined),
                          title: const Text('Privacy'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.tonalIcon(
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
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Failed to load account: $e'),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load auth status: $e')),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _StatusPill({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _KeyValue({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 18, color: muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: muted),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
