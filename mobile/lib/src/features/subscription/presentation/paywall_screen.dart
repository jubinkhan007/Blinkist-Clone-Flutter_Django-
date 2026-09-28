import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/subscription/subscription_repository.dart';
import '../../../../core/theme/app_theme.dart';

class PaywallScreen extends ConsumerWidget {
  final String? bookSlug;
  final String? bookTitle;

  const PaywallScreen({super.key, this.bookSlug, this.bookTitle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAsync = ref.watch(subscriptionInfoProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Go Premium')),
      body: subAsync.when(
        data: (sub) {
          final isSignedOut = sub == null;
          final isPremium = sub?.isPremium ?? false;
          final status = sub?.subscriptionStatus ?? 'signed_out';
          final trialDays = sub?.trialDaysRemaining ?? 0;
          final trialLabel = trialDays > 0
              ? '$trialDays day${trialDays == 1 ? '' : 's'} left'
              : status == 'trialing'
              ? 'Trial active'
              : 'No active trial';

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.16),
                      colorScheme.surface,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.workspace_premium_rounded,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      bookTitle == null
                          ? 'Premium unlocks the full Blinkist experience'
                          : 'Keep going with $bookTitle',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      bookTitle == null
                          ? 'Listen, read in full, and save titles offline with one upgrade.'
                          : 'Unlock audio, full summaries, and offline access for this title and the rest of your library.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _Badge(
                          icon: Icons.lock_open_rounded,
                          label: isPremium
                              ? 'Premium active'
                              : isSignedOut
                              ? 'Sign in required'
                              : _labelizeStatus(status),
                        ),
                        _Badge(icon: Icons.timer_outlined, label: trialLabel),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.42),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _SectionTitle(
                        icon: Icons.bolt_rounded,
                        title: 'What you get',
                      ),
                      SizedBox(height: 16),
                      _BenefitTile(
                        icon: Icons.headphones_rounded,
                        title: 'Audio summaries',
                        subtitle:
                            'Listen while commuting, walking, or working.',
                      ),
                      SizedBox(height: 12),
                      _BenefitTile(
                        icon: Icons.auto_stories_rounded,
                        title: 'Full book summaries',
                        subtitle:
                            'Read beyond the preview and keep your momentum.',
                      ),
                      SizedBox(height: 12),
                      _BenefitTile(
                        icon: Icons.download_for_offline_rounded,
                        title: 'Offline access',
                        subtitle:
                            'Save content for flights, travel, and low-signal moments.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                color: colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.42),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle(
                        icon: Icons.shield_outlined,
                        title: 'Your plan',
                      ),
                      const SizedBox(height: 16),
                      _InfoRow(
                        label: 'Account status',
                        value: isSignedOut
                            ? 'Signed out'
                            : isPremium
                            ? 'Premium'
                            : _labelizeStatus(status),
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(label: 'Trial', value: trialLabel),
                      if (sub?.subscriptionEndDate != null) ...[
                        const SizedBox(height: 12),
                        _InfoRow(
                          label: 'Renews / ends',
                          value: _formatDate(sub!.subscriptionEndDate!),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (isSignedOut)
                _HintCard(
                  icon: Icons.person_outline_rounded,
                  title: 'Sign in to start',
                  message:
                      'Your account needs to be signed in before trial or payment can begin.',
                )
              else if (isPremium)
                _HintCard(
                  icon: Icons.verified_rounded,
                  title: 'Premium is already active',
                  message:
                      'You can return to reading now, or open your account to review subscription details.',
                )
              else
                _HintCard(
                  icon: Icons.payments_outlined,
                  title: 'Ready when you are',
                  message:
                      'Continue to checkout to activate premium access for your account.',
                ),
              const SizedBox(height: 18),
              if (isPremium)
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Continue with Premium'),
                )
              else if (isSignedOut)
                FilledButton.icon(
                  onPressed: () => context.go('/profile'),
                  icon: const Icon(Icons.person_rounded),
                  label: const Text('Sign In to Continue'),
                )
              else
                FilledButton.icon(
                  onPressed: () => _handleSubscribe(context, ref),
                  icon: const Icon(Icons.workspace_premium_rounded),
                  label: const Text('Unlock Premium'),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(subscriptionInfoProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh Status'),
              ),
              if (isSignedOut || isPremium) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => context.go('/profile'),
                  icon: const Icon(Icons.manage_accounts_outlined),
                  label: Text(isSignedOut ? 'Go to Account' : 'Manage Account'),
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 40,
                  color: colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text(
                  'Failed to load subscription',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$e',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(subscriptionInfoProvider),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubscribe(BuildContext context, WidgetRef ref) async {
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      final initiation = await repo.initiatePayment();
      if (!context.mounted) return;

      final uri = Uri.parse(initiation.gatewayUrl);
      final openedInApp = await launchUrl(
        uri,
        mode: LaunchMode.inAppBrowserView,
      );
      if (!openedInApp) {
        final openedExternally = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!openedExternally) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open payment link.')),
          );
        }
      }
    } on DioException catch (e) {
      if (!context.mounted) return;
      if (e.response?.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to subscribe.')),
        );
        context.go('/profile');
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Subscribe failed: ${e.message}')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Subscribe failed: $e')));
    }
  }

  static String _labelizeStatus(String raw) {
    if (raw.isEmpty) return 'Unknown';
    return raw
        .split('_')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  static String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _BenefitTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _BenefitTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _HintCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _HintCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Badge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
