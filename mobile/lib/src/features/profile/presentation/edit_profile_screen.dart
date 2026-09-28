import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/subscription/subscription_repository.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _avatarController = TextEditingController();
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _bioController.dispose();
    _avatarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionAsync = ref.watch(subscriptionInfoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: subscriptionAsync.when(
        data: (sub) {
          if (sub == null) {
            return const Center(child: Text('Sign in to edit your profile.'));
          }

          if (!_initialized) {
            _initialized = true;
            _firstNameController.text = sub.firstName ?? '';
            _lastNameController.text = sub.lastName ?? '';
            _bioController.text = sub.bio ?? '';
            _avatarController.text = sub.avatarUrl ?? '';
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 34,
                    backgroundImage: _avatarController.text.trim().isNotEmpty
                        ? NetworkImage(_avatarController.text.trim())
                        : null,
                    child: _avatarController.text.trim().isEmpty
                        ? const Icon(Icons.person_outline, size: 34)
                        : null,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(labelText: 'First Name'),
                  maxLength: 100,
                  validator: _requiredName,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(labelText: 'Last Name'),
                  maxLength: 100,
                  validator: _requiredName,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bioController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Bio'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _avatarController,
                  decoration: const InputDecoration(labelText: 'Avatar URL'),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : () => _save(context),
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Changes'),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Failed to load profile: $error')),
      ),
    );
  }

  String? _requiredName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Required';
    }
    if (trimmed.length > 100) {
      return 'Must be 100 characters or fewer';
    }
    return null;
  }

  Future<void> _save(BuildContext context) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(subscriptionRepositoryProvider)
          .updateProfile(
            firstName: _firstNameController.text,
            lastName: _lastNameController.text,
            bio: _bioController.text,
            avatarUrl: _avatarController.text,
          );
      ref.invalidate(subscriptionInfoProvider);
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save profile: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
