/// ProfessorOS – Forgot Password Screen.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/error_parser.dart';
import '../data/auth_repository.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _done    = false;
  String? _error;

  late final AnimationController _enterCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fade  = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));
    _enterCtrl.forward();
  }

  @override
  void dispose() { _enterCtrl.dispose(); _emailCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await AuthRepository().forgotPassword(_emailCtrl.text.trim());
      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (mounted) setState(() => _error = ErrorParser.parse(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Stack(children: [
        // Ambient blob
        Positioned(top: -120, right: -120,
          child: Container(width: 400, height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [AppColors.primaryIndigo.withOpacity(0.12), Colors.transparent]),
            ))),
        Positioned(bottom: -80, left: -80,
          child: Container(width: 300, height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [AppColors.accentPink.withOpacity(0.08), Colors.transparent]),
            ))),
        // Content
        Center(child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: FadeTransition(opacity: _fade, child: SlideTransition(position: _slide,
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.all(36),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.r8),
                  border: Border.all(color: AppColors.ruleStrong, width: 1),
                ),
                child: _done ? _buildSuccess() : _buildForm(),
              ),
            ),
          )),
        )),
      ]),
    );
  }

  Widget _buildSuccess() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          color: AppColors.canvas,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.ruleStrong, width: 1),
        ),
        child: const Icon(Icons.send_outlined, color: AppColors.inkPrimary, size: 28),
      ),
      const SizedBox(height: 24),
      Text('Instructions Dispatched', style: GoogleFonts.fraunces(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.inkPrimary)),
      const SizedBox(height: 10),
      Text('If an active academic account exists for that email,\nyou will receive a password reset link shortly.',
        style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.inkSecondary, height: 1.5), textAlign: TextAlign.center),
      const SizedBox(height: 28),
      OutlinedButton(
        onPressed: () => context.go('/auth/login'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.inkPrimary,
          side: const BorderSide(color: AppColors.ruleStrong, width: 1),
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r6)),
        ),
        child: Text('Return to Sign In', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
      ),
    ]);
  }

  Widget _buildForm() {
    return Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Back button
      Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: () => context.go('/auth/login'),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.inkSecondary),
            const SizedBox(width: 6),
            Text('Back', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.inkSecondary)),
          ]),
        ),
      ),
      const SizedBox(height: 24),

      // Icon
      Container(width: 52, height: 52,
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.circular(AppRadius.r6),
          border: Border.all(color: AppColors.marginRule, width: 1),
        ),
        child: const Icon(Icons.lock_reset_rounded, color: AppColors.inkPrimary, size: 26)),
      const SizedBox(height: 16),

      Text('Reset Password', style: GoogleFonts.fraunces(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.inkPrimary, letterSpacing: -0.4)),
      const SizedBox(height: 6),
      Text("Enter your academic email to request a secure password recovery link.", style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.inkSecondary, height: 1.5)),
      const SizedBox(height: 24),

      if (_error != null) Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.statusCritical.withOpacity(0.06),
          borderRadius: BorderRadius.circular(AppRadius.r6),
          border: Border.all(color: AppColors.statusCritical.withOpacity(0.3))),
        child: Text(_error!, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.statusCriticalInk)),
      ),

      TextFormField(
        controller: _emailCtrl,
        validator: Validators.email,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(labelText: 'Academic Email', prefixIcon: Icon(Icons.alternate_email_rounded)),
      ),
      const SizedBox(height: 24),

      ElevatedButton(
        onPressed: _loading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.inkPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r6)),
          textStyle: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        child: _loading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('Send Reset Link'),
      ),
    ]));
  }
}
