import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/subscription/subscription_models.dart';
import '../../../../core/subscription/subscription_repository.dart';
import '../../../../core/theme/app_theme.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  final String? bookSlug;
  final String? bookTitle;

  const PaywallScreen({super.key, this.bookSlug, this.bookTitle});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  int? _selectedPlanId;
  final TextEditingController _couponController = TextEditingController();
  CouponValidationResult? _appliedCoupon;
  bool _validatingCoupon = false;
  bool _startingTrial = false;
  bool _initiatingCheckout = false;
  String? _couponErrorMessage;

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _handleValidateCoupon(List<SubscriptionPlanModel> plans) async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _validatingCoupon = true;
      _couponErrorMessage = null;
    });

    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      final result = await repo.validateCoupon(code, planId: _selectedPlanId);
      if (result.isValid) {
        setState(() {
          _appliedCoupon = result;
          _couponErrorMessage = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '🎉 Coupon applied! ${result.discountPercent}% off',
              ),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
      } else {
        setState(() {
          _couponErrorMessage = result.message;
          _appliedCoupon = null;
        });
      }
    } catch (e) {
      setState(() {
        _couponErrorMessage = 'Failed to validate promo code';
        _appliedCoupon = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _validatingCoupon = false;
        });
      }
    }
  }

  void _clearCoupon() {
    setState(() {
      _appliedCoupon = null;
      _couponErrorMessage = null;
      _couponController.clear();
    });
  }

  Future<void> _handleStartTrial() async {
    setState(() => _startingTrial = true);
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      final result = await repo.startFreeTrial(trialDays: 7);
      ref.invalidate(subscriptionInfoProvider);
      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.green.shade700,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start trial: $e')),
      );
    } finally {
      if (mounted) setState(() => _startingTrial = false);
    }
  }

  Future<void> _handleStripeCheckout(int planId) async {
    setState(() => _initiatingCheckout = true);
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      final initiation = await repo.createStripeCheckout(
        planId: planId,
        couponCode: _appliedCoupon?.code,
      );
      if (!mounted) return;

      final uri = Uri.parse(initiation.gatewayUrl);
      final opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      if (!opened) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.response?.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to subscribe.')),
        );
        context.go('/profile');
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Checkout failed: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Checkout error: $e')),
      );
    } finally {
      if (mounted) setState(() => _initiatingCheckout = false);
    }
  }

  Future<void> _handleLegacyCheckout() async {
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      final initiation = await repo.initiatePayment();
      if (!mounted) return;

      final uri = Uri.parse(initiation.gatewayUrl);
      final opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      if (!opened) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment initiation failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final subAsync = ref.watch(subscriptionInfoProvider);
    final plansAsync = ref.watch(subscriptionPlansProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Go Premium'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(subscriptionInfoProvider);
              ref.invalidate(subscriptionPlansProvider);
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: subAsync.when(
        data: (sub) {
          final isSignedOut = sub == null;
          final isPremium = sub?.isPremium ?? false;
          final status = sub?.subscriptionStatus ?? 'signed_out';
          final trialDays = sub?.trialDaysRemaining ?? 0;
          final hasUsedTrial = (sub?.trialDaysRemaining ?? 0) > 0 || status == 'trialing' || status == 'active';
          final trialLabel = trialDays > 0
              ? '$trialDays day${trialDays == 1 ? '' : 's'} left'
              : status == 'trialing'
              ? 'Trial active'
              : 'No active trial';

          return plansAsync.when(
            data: (plans) {
              // Default to annual plan if available, else first plan
              if (_selectedPlanId == null && plans.isNotEmpty) {
                final annual = plans.firstWhere(
                  (p) => p.billingInterval == 'year',
                  orElse: () => plans.first,
                );
                _selectedPlanId = annual.id;
              }

              final selectedPlan = plans.firstWhere(
                (p) => p.id == _selectedPlanId,
                orElse: () => plans.isNotEmpty ? plans.first : const SubscriptionPlanModel(
                  id: 0,
                  name: 'Monthly',
                  slug: 'monthly',
                  billingInterval: 'month',
                  priceUsd: 9.99,
                  priceBdt: 999.0,
                  stripePriceId: '',
                  appleProductId: '',
                  googleProductId: '',
                ),
              );

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  // Hero Header
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
                          widget.bookTitle == null
                              ? 'Premium unlocks the full Blinkist experience'
                              : 'Keep going with ${widget.bookTitle}',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.bookTitle == null
                              ? 'Listen, read in full, generate AI Action Plans, and save titles offline with one upgrade.'
                              : 'Unlock audio narrations, full summaries, and offline access for this title and your whole library.',
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
                  const SizedBox(height: 20),

                  // Plans Selection Section
                  if (!isPremium) ...[
                    Text(
                      'Choose Your Plan',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...plans.map((plan) {
                      final isSelected = plan.id == _selectedPlanId;
                      final isAnnual = plan.billingInterval == 'year';
                      final isLifetime = plan.billingInterval == 'lifetime';

                      double finalPrice = plan.priceUsd;
                      if (_appliedCoupon != null) {
                        final factor = (100 - _appliedCoupon!.discountPercent) / 100.0;
                        finalPrice = double.parse((finalPrice * factor).toStringAsFixed(2));
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedPlanId = plan.id;
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colorScheme.primary.withValues(alpha: 0.08)
                                  : colorScheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.outlineVariant.withValues(alpha: 0.5),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? colorScheme.primary
                                          : colorScheme.outline,
                                      width: isSelected ? 6 : 2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            plan.name,
                                            style: theme.textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          if (isAnnual) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade600,
                                                borderRadius: BorderRadius.circular(999),
                                              ),
                                              child: const Text(
                                                'SAVE 33%',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ] else if (isLifetime) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.purple.shade600,
                                                borderRadius: BorderRadius.circular(999),
                                              ),
                                              child: const Text(
                                                'ONE TIME',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isAnnual
                                            ? 'Billed yearly at \$${plan.priceUsd}/yr (\$${(plan.priceUsd / 12).toStringAsFixed(2)}/mo)'
                                            : isLifetime
                                            ? 'Pay once, keep forever'
                                            : 'Billed monthly, cancel anytime',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (_appliedCoupon != null)
                                      Text(
                                        '\$${plan.priceUsd.toStringAsFixed(2)}',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          decoration: TextDecoration.lineThrough,
                                          color: colorScheme.outline,
                                        ),
                                      ),
                                    Text(
                                      '\$${finalPrice.toStringAsFixed(2)}',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: isSelected ? colorScheme.primary : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 12),

                    // Promo / Referral Code Box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.discount_outlined,
                                size: 18,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Have a promo or friend referral code?',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (_appliedCoupon != null)
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.green.shade300),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle_rounded,
                                        size: 16,
                                        color: Colors.green.shade700,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${_appliedCoupon!.code} (${_appliedCoupon!.discountPercent}% OFF)',
                                        style: TextStyle(
                                          color: Colors.green.shade800,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: _clearCoupon,
                                  child: const Text('Remove'),
                                ),
                              ],
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _couponController,
                                    textCapitalization: TextCapitalization.characters,
                                    decoration: InputDecoration(
                                      hintText: 'Enter code (e.g. REF-ALEX-9K2M)',
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      isDense: true,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      errorText: _couponErrorMessage,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton.tonal(
                                  onPressed: _validatingCoupon
                                      ? null
                                      : () => _handleValidateCoupon(plans),
                                  child: _validatingCoupon
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Text('Apply'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Benefits Summary
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.42),
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionTitle(
                            icon: Icons.bolt_rounded,
                            title: 'What you get with Premium',
                          ),
                          SizedBox(height: 16),
                          _BenefitTile(
                            icon: Icons.headphones_rounded,
                            title: 'Studio-Grade Audio Narrations',
                            subtitle:
                                'Listen seamlessly while commuting, exercising, or doing chores.',
                          ),
                          SizedBox(height: 12),
                          _BenefitTile(
                            icon: Icons.auto_stories_rounded,
                            title: 'Full Unabridged Blinks & Summaries',
                            subtitle:
                                'Read beyond previews and extract actionable insights in 15 minutes.',
                          ),
                          SizedBox(height: 12),
                          _BenefitTile(
                            icon: Icons.psychology_rounded,
                            title: 'AI Companion & Habit Roadmap',
                            subtitle:
                                'Generate personalized 7-day micro-habit roadmaps and ask questions to books.',
                          ),
                          SizedBox(height: 12),
                          _BenefitTile(
                            icon: Icons.download_for_offline_rounded,
                            title: '100% Offline Access',
                            subtitle:
                                'Download summaries and audiobooks for flights and dead zones.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  if (isPremium) ...[
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text('Continue with Premium'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/profile'),
                      icon: const Icon(Icons.manage_accounts_outlined),
                      label: const Text('Manage Account & Billing'),
                    ),
                  ] else if (isSignedOut) ...[
                    FilledButton.icon(
                      onPressed: () => context.go('/profile'),
                      icon: const Icon(Icons.person_rounded),
                      label: const Text('Sign In to Start'),
                    ),
                  ] else ...[
                    // Free Trial Button if user has not used trial yet
                    if (!hasUsedTrial) ...[
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: colorScheme.primary,
                        ),
                        onPressed: _startingTrial ? null : _handleStartTrial,
                        icon: _startingTrial
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.star_rounded),
                        label: Text(
                          _startingTrial ? 'Starting...' : 'Start 7-Day Free Trial',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'No commitment. Cancel anytime in your profile.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Stripe Checkout Primary Button
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: hasUsedTrial
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHighest,
                        foregroundColor: hasUsedTrial
                            ? Colors.white
                            : colorScheme.onSurface,
                      ),
                      onPressed: _initiatingCheckout
                          ? null
                          : () => _handleStripeCheckout(selectedPlan.id),
                      icon: _initiatingCheckout
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.payment_rounded),
                      label: Text(
                        _initiatingCheckout
                            ? 'Preparing Secure Checkout...'
                            : 'Pay with Card / Stripe (\$${_appliedCoupon != null ? ((100 - _appliedCoupon!.discountPercent) / 100.0 * selectedPlan.priceUsd).toStringAsFixed(2) : selectedPlan.priceUsd.toStringAsFixed(2)})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Alternative Gateway (SSLCommerz)
                    OutlinedButton.icon(
                      onPressed: _handleLegacyCheckout,
                      icon: const Icon(Icons.account_balance_wallet_outlined),
                      label: Text(
                        'Pay with Mobile Banking / BDT (৳${selectedPlan.priceBdt.toStringAsFixed(0)})',
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  // Security and Guarantee badges
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline, size: 14, color: colorScheme.outline),
                      const SizedBox(width: 6),
                      Text(
                        '256-bit SSL Encrypted • Cancel Anytime',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Failed to load plans: $e'),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 40, color: colorScheme.error),
                const SizedBox(height: 12),
                Text('Failed to load account: $e'),
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

  static String _labelizeStatus(String raw) {
    if (raw.isEmpty) return 'Unknown';
    return raw
        .split('_')
        .map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}')
        .join(' ');
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
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
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
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
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
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
