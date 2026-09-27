/// ProfessorOS – Reset Password Screen.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/error_parser.dart';
import '../data/auth_repository.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? token;
  const ResetPasswordScreen({super.key, this.token});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;

  late final AnimationController _enterCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  int get _strength => Validators.passwordStrength(_passCtrl.text);

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
  void dispose() {
    _enterCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await AuthRepository().resetPassword(widget.token ?? '', _passCtrl.text);
      if (mounted) context.go('/auth/login');
    } catch (e) {
      setState(() => _error = ErrorParser.parse(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strengthColors = [
      AppColors.dangerRose,
      const Color(0xFFEA580C),
      AppColors.accentAmber,
      AppColors.successGreen,
      AppColors.successGreen,
    ];
    final strengthLabels = ['Too weak', 'Weak', 'Fair', 'Strong', 'Very strong'];

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Stack(
        children: [
          Positioned(
            top: -100, right: -100,
            child: Container(
              width: 380, height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [AppColors.primaryIndigo.withOpacity(0.12), Colors.transparent]),
              ),
            ),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Container(
                      padding: const EdgeInsets.all(36),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.r8),
                        border: Border.all(color: AppColors.ruleStrong, width: 1),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              width: 52, height: 52,
                              decoration: BoxDecoration(
                                color: AppColors.canvas,
                                borderRadius: BorderRadius.circular(AppRadius.r6),
                                border: Border.all(color: AppColors.marginRule, width: 1),
                              ),
                              child: const Icon(Icons.key_rounded, color: AppColors.inkPrimary, size: 26),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Create New Password',
                              style: GoogleFonts.fraunces(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.inkPrimary, letterSpacing: -0.4),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Your new password must be secure and different from previous passwords.',
                              style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.inkSecondary, height: 1.5),
                            ),
                            const SizedBox(height: 24),

                            if (_error != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: AppColors.dangerRose.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.dangerRose.withOpacity(0.2)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.dangerRose),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(_error!, style: GoogleFonts.inter(fontSize: 13, color: AppColors.dangerRose))),
                                  ],
                                ),
                              ),
                            ],

                            TextFormField(
                              controller: _passCtrl,
                              validator: Validators.password,
                              obscureText: _obscurePass,
                              decoration: InputDecoration(
                                labelText: 'New password',
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePass ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),

                            if (_passCtrl.text.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: List.generate(4, (i) => Expanded(
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    height: 4,
                                    margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      color: i < _strength ? strengthColors[_strength] : AppColors.border,
                                    ),
                                  ),
                                )),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _strength > 0 ? strengthLabels[_strength] : '',
                                style: GoogleFonts.inter(fontSize: 12, color: strengthColors[_strength.clamp(0, 4)], fontWeight: FontWeight.w500),
                              ),
                            ],

                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirmCtrl,
                              obscureText: _obscureConfirm,
                              decoration: InputDecoration(
                                labelText: 'Confirm new password',
                                prefixIcon: const Icon(Icons.lock_reset_rounded),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                ),
                              ),
                              validator: (v) => v != _passCtrl.text ? 'Passwords do not match.' : null,
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
                                  : const Text('Update Password'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
