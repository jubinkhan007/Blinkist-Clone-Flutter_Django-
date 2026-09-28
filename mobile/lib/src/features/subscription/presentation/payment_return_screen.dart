import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/subscription/subscription_repository.dart';

class PaymentReturnScreen extends ConsumerStatefulWidget {
  final String status;
  final String? tranId;

  const PaymentReturnScreen({super.key, required this.status, this.tranId});

  @override
  ConsumerState<PaymentReturnScreen> createState() =>
      _PaymentReturnScreenState();
}

class _PaymentReturnScreenState extends ConsumerState<PaymentReturnScreen> {
  bool _isRefreshing = true;

  @override
  void initState() {
    super.initState();
    _refreshSubscription();
  }

  Future<void> _refreshSubscription() async {
    try {
      final _ = await ref.refresh(subscriptionInfoProvider.future);
    } catch (_) {
      ref.invalidate(subscriptionInfoProvider);
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final config = _statusConfig(widget.status, colorScheme);

    return Scaffold(
      appBar: AppBar(title: const Text('Payment status')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: config.tint.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(config.icon, size: 36, color: config.tint),
                  ),
                  Text(
                    config.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    config.message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  if (widget.tranId?.isNotEmpty == true) ...[
                    const SizedBox(height: 18),
                    Text(
                      'Transaction: ${widget.tranId}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  if (_isRefreshing) ...[
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 16),
                    Text(
                      'Refreshing your account status...',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                  FilledButton.icon(
                    onPressed: _isRefreshing
                        ? null
                        : () => context.go('/profile'),
                    icon: Icon(config.primaryIcon),
                    label: Text(config.primaryLabel),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isRefreshing ? null : () => context.go('/'),
                    icon: const Icon(Icons.home_outlined),
                    label: const Text('Back to Home'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _PaymentReturnConfig _statusConfig(String status, ColorScheme colorScheme) {
    switch (status) {
      case 'success':
        return _PaymentReturnConfig(
          title: 'Premium unlocked',
          message:
              'Your payment was confirmed. Your subscription status has been refreshed.',
          icon: Icons.verified_rounded,
          tint: colorScheme.primary,
          primaryLabel: 'Go to Account',
          primaryIcon: Icons.manage_accounts_outlined,
        );
      case 'failed':
        return _PaymentReturnConfig(
          title: 'Payment failed',
          message:
              'The transaction did not complete. You can try the checkout again from the app.',
          icon: Icons.error_outline_rounded,
          tint: colorScheme.error,
          primaryLabel: 'Try Again Later',
          primaryIcon: Icons.refresh_rounded,
        );
      case 'cancelled':
        return _PaymentReturnConfig(
          title: 'Payment cancelled',
          message:
              'No charge was completed. You can resume premium checkout whenever you are ready.',
          icon: Icons.do_disturb_on_outlined,
          tint: colorScheme.onSurfaceVariant,
          primaryLabel: 'Back to Account',
          primaryIcon: Icons.person_outline_rounded,
        );
      default:
        return _PaymentReturnConfig(
          title: 'Payment update',
          message:
              'Your app has received the checkout response. Review your account for the latest subscription state.',
          icon: Icons.info_outline_rounded,
          tint: colorScheme.primary,
          primaryLabel: 'Open Account',
          primaryIcon: Icons.person_outline_rounded,
        );
    }
  }
}

class _PaymentReturnConfig {
  final String title;
  final String message;
  final IconData icon;
  final Color tint;
  final String primaryLabel;
  final IconData primaryIcon;

  const _PaymentReturnConfig({
    required this.title,
    required this.message,
    required this.icon,
    required this.tint,
    required this.primaryLabel,
    required this.primaryIcon,
  });
}
