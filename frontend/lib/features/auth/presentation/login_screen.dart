import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/journal_ui/journal_components.dart';
import '../providers/auth_provider.dart';
import '../data/auth_repository.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/error_parser.dart';
import 'package:local_auth/local_auth.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;
  bool _isUnverified = false;
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _canUseBiometrics = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      final creds = await DioClient.getBiometricCreds();
      if (canCheck && isDeviceSupported && creds != null) {
        setState(() => _canUseBiometrics = true);
      }
    } catch (_) {}
  }

  Future<void> _authenticateBiometrics() async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Scan your fingerprint or face to sign in securely',
        options: const AuthenticationOptions(stickyAuth: true),
      );
      if (authenticated) {
        final creds = await DioClient.getBiometricCreds();
        if (creds != null) {
          _emailCtrl.text = creds['email']!;
          _passCtrl.text = creds['password']!;
          _submit();
        }
      }
    } catch (e) {
      _showSnack('Biometric authentication failed or canceled.');
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; _isUnverified = false; });

    await ref.read(authProvider.notifier).login(_emailCtrl.text.trim(), _passCtrl.text);
    if (!mounted) return;

    final authState = ref.read(authProvider);
    if (authState.hasError) {
      final msg = ErrorParser.parse(authState.error!);
      setState(() {
        _error = msg;
        _isUnverified = msg.toLowerCase().contains('verify');
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
      await DioClient.saveBiometricCreds(_emailCtrl.text.trim(), _passCtrl.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed in successfully!'),
            backgroundColor: AppColors.verified,
            duration: Duration(seconds: 2),
          ),
        );
        final role = authState.valueOrNull?['role'];
        context.go(role == 'admin' ? '/admin' : '/courses');
      }
    }
  }

  Future<void> _resendVerification() async {
    try {
      await AuthRepository().resendVerification(_emailCtrl.text.trim());
      if (mounted) _showSnack('Verification email sent!', success: true);
    } catch (_) {}
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppColors.verified : AppColors.feedbackRed,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'ProfessorOS',
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: 26,
                      fontWeight: FontWeight.w400,
                      color: AppColors.inkPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to your academic account',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: AppColors.inkSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.feedbackRed.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.feedbackRed),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_error!, style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkPrimary))),
                            ],
                          ),
                          if (_isUnverified) ...[
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: _resendVerification,
                              child: Text('Resend verification email →',
                                style: GoogleFonts.inter(fontSize: 13, color: AppColors.signal, fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ],
                      ),
                    ),

                  TextFormField(
                    controller: _emailCtrl,
                    validator: Validators.email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Email address'),
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _passCtrl,
                    validator: Validators.password,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (!_loading) _submit();
                    },
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.go('/auth/forgot-password'),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  PrimaryButton(
                    label: 'Sign in',
                    loadingLabel: 'Signing in…',
                    isLoading: _loading,
                    onPressed: _submit,
                  ),
                  if (_canUseBiometrics) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _authenticateBiometrics,
                      style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                      icon: const Icon(Icons.fingerprint_rounded, size: 24),
                      label: const Text('Sign in with Biometrics'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  
                  Center(
                    child: RichText(
                      text: TextSpan(
                        style: GoogleFonts.inter(fontSize: 14, color: AppColors.inkSecondary),
                        children: [
                          const TextSpan(text: "Don't have an account? "),
                          WidgetSpan(
                            child: GestureDetector(
                              onTap: () => context.go('/auth/register'),
                              child: Text('Sign up', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.signal)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
