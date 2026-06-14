import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../providers/auth_provider.dart';

class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _agreeToTerms = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    ref.listen(authStateProvider, (_, next) {
      next.whenOrNull(
        error: (error, _) => _showError(error.toString()),
        data: (data) {
          if (data.isLoggedIn) context.go('/dashboard');
        },
      );
    });

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                _buildHeader(),
                const SizedBox(height: 32),
                _buildInputFields(),
                const SizedBox(height: 12),
                _buildTermsCheckbox(),
                const SizedBox(height: 24),
                _buildSignupButton(authState.isLoading),
                const SizedBox(height: 24),
                _buildLoginLink(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.person_add, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 20),
        Text(
          'Create Account',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Start with a free plan — no credit card needed.\nUpgrade anytime for unlimited access.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondaryLight,
              ),
        ),
      ],
    );
  }

  Widget _buildInputFields() {
    return Column(
      children: [
        AppTextField(
          label: 'Name (optional)',
          hint: 'Your name or business name',
          controller: _nameController,
          prefix: const Icon(Icons.badge_outlined, size: 20),
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Username',
          hint: 'Choose a username',
          controller: _usernameController,
          prefix: const Icon(Icons.person_outline, size: 20),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Enter a username';
            if (v.length < 3) return 'Username must be at least 3 characters';
            return null;
          },
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Password',
          hint: 'At least 4 characters',
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          prefix: const Icon(Icons.lock_outline, size: 20),
          suffix: IconButton(
            icon: Icon(
              _isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 20,
            ),
            onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Enter a password';
            if (v.length < 4) return 'Password must be at least 4 characters';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      children: [
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: _agreeToTerms,
            onChanged: (v) => setState(() => _agreeToTerms = v ?? false),
            activeColor: AppColors.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'I agree to the Terms & Conditions and Privacy Policy',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignupButton(bool isLoading) {
    return AppButton(
      label: 'Create Free Account',
      onPressed: _handleSignup,
      isLoading: isLoading,
      icon: Icons.person_add,
    );
  }

  Widget _buildLoginLink() {
    return Center(
      child: TextButton(
        onPressed: () => context.go('/login'),
        child: RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.bodyMedium,
            children: [
              const TextSpan(
                text: 'Already have an account? ',
                style: TextStyle(color: AppColors.textSecondaryLight),
              ),
              TextSpan(
                text: 'Sign In',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSignup() {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeToTerms) {
      _showError('Please agree to the Terms & Conditions');
      return;
    }
    ref.read(authStateProvider.notifier).signup(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      name: _nameController.text.trim(),
    );
  }

  void _showError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
