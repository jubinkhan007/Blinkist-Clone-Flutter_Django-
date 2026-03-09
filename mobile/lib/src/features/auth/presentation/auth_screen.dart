import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/auth_repository.dart';
import '../../../../core/subscription/subscription_repository.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _loginEmail = TextEditingController();
  final _loginPassword = TextEditingController();

  final _signupName = TextEditingController();
  final _signupEmail = TextEditingController();
  final _signupPassword = TextEditingController();

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmail.dispose();
    _loginPassword.dispose();
    _signupName.dispose();
    _signupEmail.dispose();
    _signupPassword.dispose();
    super.dispose();
  }

  void _showError(Object e) {
    String message = 'Authentication failed. Please try again.';
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        message = data.values.join('\n');
      } else if (data is String && data.trim().isNotEmpty) {
        message = data;
      }
    } else if (e is StateError) {
      message = e.message;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _login() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .login(email: _loginEmail.text, password: _loginPassword.text);
      ref.invalidate(authStatusProvider);
      ref.invalidate(subscriptionInfoProvider);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signup() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .signup(
            displayName: _signupName.text,
            email: _signupEmail.text,
            password: _signupPassword.text,
          );
      ref.invalidate(authStatusProvider);
      ref.invalidate(subscriptionInfoProvider);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Sign in'),
            Tab(text: 'Create account'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _AuthForm(
                title: 'Welcome back',
                fields: [
                  TextField(
                    controller: _loginEmail,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _loginPassword,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                ],
                primaryText: 'Sign in',
                busy: _busy,
                onPrimary: _busy ? null : _login,
              ),
              _AuthForm(
                title: 'Create your account',
                fields: [
                  TextField(
                    controller: _signupName,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _signupEmail,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _signupPassword,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                ],
                primaryText: 'Create account',
                busy: _busy,
                onPrimary: _busy ? null : _signup,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AuthForm extends StatelessWidget {
  final String title;
  final List<Widget> fields;
  final String primaryText;
  final bool busy;
  final VoidCallback? onPrimary;

  const _AuthForm({
    required this.title,
    required this.fields,
    required this.primaryText,
    required this.busy,
    required this.onPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        ...fields,
        const SizedBox(height: 20),
        FilledButton(
          onPressed: onPrimary,
          child: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(primaryText),
        ),
      ],
    );
  }
}
