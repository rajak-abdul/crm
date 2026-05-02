// ╔══════════════════════════════════════════════════════════════╗
// ║               lib/screens/login_screen.dart                  ║
// ║                                                              ║
// ║  CONTAINS:                                                   ║
// ║   1. LoginState   — idle / loading / success / error         ║
// ║   2. LoginCubit   — POST /api/auth/login  → saves token      ║
// ║   3. LoginScreen  — email + password form UI                 ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/login/cubit/login_cubit.dart' show LoginCubit;
import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

// ══════════════════════════════════════════════════════════════
// 1️⃣  STATE
// ══════════════════════════════════════════════════════════════
abstract class LoginState extends Equatable {
  const LoginState();
  @override List<Object?> get props => [];
}
class LoginIdle    extends LoginState {}
class LoginLoading extends LoginState {}
class LoginSuccess extends LoginState {}
class LoginError extends LoginState {
  final String message;
  const LoginError(this.message);
  @override List<Object?> get props => [message];
}


// ══════════════════════════════════════════════════════════════
// 3️⃣  SCREEN
// ══════════════════════════════════════════════════════════════
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => LoginCubit(),
    child: const _LoginView(),
  );
}

class _LoginView extends StatefulWidget {
  const _LoginView();
  @override State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _showPass      = false;
  final _forgotEmailCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _forgotEmailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LoginCubit, LoginState>(
      listener: (context, state) {
        if (state is LoginSuccess) {
          // ✅ Replace the entire route stack with MainShell
          Navigator.of(context).pushReplacementNamed('/home');
        }
      },
      builder: (context, state) {
        final loading = state is LoginLoading;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 60),

                  // ── Logo / Brand ──────────────────────────
                  Center(child: Column(children: [
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1D4ED8), Color(0xFF0EA5E9)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(
                          color: AppColors.primary.withOpacity(0.35),
                          blurRadius: 20, offset: const Offset(0, 8),
                        )],
                      ),
                      child: const Icon(Icons.business_center_rounded,
                          color: Colors.white, size: 36),
                    ),
                    const SizedBox(height: 16),
                    const Text('Welcome Back',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    const Text('Sign in to your account',
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  ])),

                  const SizedBox(height: 48),

                  // ── Error Banner ─────────────────────────
                  if (state is LoginError)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.dangerLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                        const SizedBox(width: 10),
                        Expanded(child: Text(state.message,
                            style: const TextStyle(fontSize: 13, color: AppColors.danger, fontWeight: FontWeight.w500))),
                      ]),
                    ),

                  // ── Email ─────────────────────────────────
                  const _Label('Email Address'),
                  const SizedBox(height: 8),
                  TextField(
                    controller:   _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    enabled:      !loading,
                    style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText:    'Enter your email',
                      prefixIcon:  const Icon(Icons.email_outlined, color: AppColors.textSecondary, size: 20),
                      filled:      true,
                      fillColor:   loading ? AppColors.divider : AppColors.surface,
                      border:        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 1.8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ── Password ──────────────────────────────
                  const _Label('Password'),
                  const SizedBox(height: 8),
                  TextField(
                    controller:      _passwordCtrl,
                    obscureText:     !_showPass,
                    textInputAction: TextInputAction.done,
                    enabled:         !loading,
                    onSubmitted:     (_) => _submit(context),
                    style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText:   '••••••••',
                      prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textSecondary, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: AppColors.textSecondary, size: 20,
                        ),
                        onPressed: () => setState(() => _showPass = !_showPass),
                      ),
                      filled:      true,
                      fillColor:   loading ? AppColors.divider : AppColors.surface,
                      border:        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 1.8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),

                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: loading ? null : () => _showForgotPasswordDialog(context),
                      child: const Text(
                        'Forgot your password?',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Submit Button ─────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: loading ? null : () => _submit(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: loading
                          ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : const Text('Sign In',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Footer ────────────────────────────────
                  const Center(child: Text('© 2025 TZI. All rights reserved.',
                      style: TextStyle(fontSize: 12, color: AppColors.textHint))),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _submit(BuildContext context) {
    FocusScope.of(context).unfocus();
    context.read<LoginCubit>().login(_emailCtrl.text, _passwordCtrl.text);
  }

  bool _isValidForgotEmail(String email) {
    final value = email.trim();
    if (value.isEmpty) return false;
    final hasBasicEmailShape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
    return hasBasicEmailShape && value.toLowerCase().endsWith('.com');
  }

  Future<void> _showForgotPasswordDialog(BuildContext context) async {
    final loginCubit = context.read<LoginCubit>();
    _forgotEmailCtrl.text = _emailCtrl.text.trim();

    String? localError;
    bool sending = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !sending,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                'Forgot Password',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter your email address. We will send you a password reset link.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _forgotEmailCtrl,
                    enabled: !sending,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'Enter your email address',
                      errorText: localError,
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: sending ? null : () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: sending
                      ? null
                      : () async {
                          final email = _forgotEmailCtrl.text.trim();
                          if (!_isValidForgotEmail(email)) {
                            setState(() => localError = 'Enter a valid email (must include @ and end with .com)');
                            return;
                          }

                          setState(() {
                            localError = null;
                            sending = true;
                          });

                          final result = await loginCubit.requestPasswordReset(email);

                          if (!mounted) return;
                          if (!result.success) {
                            setState(() {
                              localError = result.message;
                              sending = false;
                            });
                            return;
                          }

                          Navigator.of(dialogCtx).pop();
                          await _showEmailSentDialog(
                            context,
                            email,
                            result.message,
                          );
                        },
                  child: sending
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Send reset link'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEmailSentDialog(
    BuildContext context,
    String email,
    String apiMessage,
  ) {
    return showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
          contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          title: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Color(0xFF22C55E)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Check Your Email',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),
              const CircleAvatar(
                radius: 24,
                backgroundColor: Color(0xFFE8F9EE),
                child: Icon(Icons.check, color: Color(0xFF22C55E), size: 28),
              ),
              const SizedBox(height: 16),
                Text(
                apiMessage,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "We've sent a password reset link to\n$email. Please check your inbox and follow the instructions.",
                style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              const Text(
                "Didn't receive the email? Check your spam folder or try again.",
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Remember your password? Back to login'),
            ),
          ],
        );
      },
    );
  }

}

// ─── Small label widget ───────────────────────────────────────
class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary));
}