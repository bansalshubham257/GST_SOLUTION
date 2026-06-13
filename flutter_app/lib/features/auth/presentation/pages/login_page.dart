// lib/features/auth/presentation/pages/login_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    ref.listen(authStateProvider, (_, next) {
      next.whenOrNull(
        error: (error, _) => _showError(error.toString()),
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
                const SizedBox(height: 48),
                _buildHeader(),
                const SizedBox(height: 40),
                _buildInputFields(),
                const SizedBox(height: 24),
                _buildPrimaryButton(authState.isLoading),
                const SizedBox(height: 16),
                _buildDemoButton(authState.isLoading),
                const SizedBox(height: 32),
                _buildFooterText(),
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
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.content_cut, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 24),
        Text(
          'Welcome to\nRegister',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Simple GST invoicing for Indian businesses',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
          label: 'Username',
          hint: 'Enter your username',
          controller: _usernameController,
          prefix: const Icon(Icons.person_outline, size: 20),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Enter username';
            return null;
          },
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Password',
          hint: '••••••••',
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
            if (v == null || v.isEmpty) return 'Enter password';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPrimaryButton(bool isLoading) {
    return AppButton(
      label: 'Sign In',
      onPressed: _handleLogin,
      isLoading: isLoading,
      icon: Icons.login,
    );
  }

  Widget _buildDemoButton(bool isLoading) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.4)),
        color: AppColors.primary.withOpacity(0.05),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isLoading ? null : _handleDemoLogin,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.explore_outlined, color: AppColors.primary, size: 20),
                SizedBox(width: 10),
                Text(
                  'Try Demo  (Limited Access)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterText() {
    return Center(
      child: Text(
        'No sign up option available.\nContact your admin to get credentials.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondaryLight,
            ),
        textAlign: TextAlign.center,
      ),
    );
  }

  void _handleLogin() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authStateProvider.notifier).loginWithUsername(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );
  }

  void _handleDemoLogin() {
    ref.read(authStateProvider.notifier).tryDemo();
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

