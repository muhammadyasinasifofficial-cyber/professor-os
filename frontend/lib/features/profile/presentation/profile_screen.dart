/// ProfessorOS – Profile / Account Settings Screen.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../shared/journal_ui/journal_components.dart';
import '../../../core/utils/avatar_helper.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/prof_badge.dart';
import '../../../shared/widgets/prof_confirm_sheet.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // ── Name editing ─────────────────────────────────────
  bool _editingName = false;
  bool _savingName = false;
  final _nameCtrl = TextEditingController();

  // ── Password change ───────────────────────────────────
  final _pwFormKey = GlobalKey<FormState>();
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _savingPw = false;
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ── Update display name ───────────────────────────────
  Future<void> _saveName() async {
    final newName = _nameCtrl.text.trim();
    if (newName.length < 2) {
      _showSnack('Name must be at least 2 characters.', error: true);
      return;
    }
    setState(() => _savingName = true);
    try {
      await AuthRepository().updateProfile(newName);
      await ref.read(authProvider.notifier).refreshUser();
      if (mounted) {
        setState(() => _editingName = false);
        _showSnack('Name updated successfully.');
      }
    } catch (e) {
      if (mounted) _showSnack(_extractError(e), error: true);
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  // ── Change password ───────────────────────────────────
  Future<void> _changePassword() async {
    if (!_pwFormKey.currentState!.validate()) return;
    if (_newPassCtrl.text != _confirmCtrl.text) {
      _showSnack('Passwords do not match.', error: true);
      return;
    }
    setState(() => _savingPw = true);
    try {
      await AuthRepository()
          .changePassword(_oldPassCtrl.text, _newPassCtrl.text);
      if (mounted) {
        _oldPassCtrl.clear();
        _newPassCtrl.clear();
        _confirmCtrl.clear();
        _showSnack('Password changed successfully.');
      }
    } catch (e) {
      if (mounted) _showSnack(_extractError(e), error: true);
    } finally {
      if (mounted) setState(() => _savingPw = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────
  String _extractError(Object e) {
    if (e is DioException) {
      final detail = e.response?.data?['detail'];
      if (detail is String) return detail;
    }
    return e.toString().replaceFirst('Exception: ', '');
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.dangerRose : AppColors.successGreen,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.valueOrNull;
    final name = user?['full_name'] as String? ?? 'Professor';
    final email = user?['email'] as String? ?? '';
    final role = user?['role'] as String? ?? 'professor';
    final verified = user?['is_verified'] as bool? ?? true;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: Text('Account Settings',
            style: GoogleFonts.fraunces(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppColors.inkPrimary)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding:
            EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                // ── Avatar + Name Row ─────────────────
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: const BoxDecoration(
                    border:
                        Border(bottom: BorderSide(color: AppColors.marginRule)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.inkPrimary,
                        child: Text(
                          AvatarHelper.initialsFor(name),
                          style: GoogleFonts.fraunces(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color: AppColors.bgPage),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_editingName)
                              Row(children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _nameCtrl,
                                    autofocus: true,
                                    decoration: const InputDecoration(
                                        labelText: 'Full Name'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _savingName
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.inkPrimary))
                                    : IconButton(
                                        icon: const Icon(Icons.check_rounded,
                                            color: AppColors.verified),
                                        onPressed: _saveName),
                                IconButton(
                                    icon: const Icon(Icons.close_rounded,
                                        color: AppColors.inkSecondary),
                                    onPressed: () =>
                                        setState(() => _editingName = false)),
                              ])
                            else
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 220),
                                    child: Text(
                                      name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.fraunces(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.inkPrimary),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 18,
                                        color: AppColors.inkSecondary),
                                    onPressed: () {
                                      _nameCtrl.text = name;
                                      setState(() => _editingName = true);
                                    },
                                  ),
                                ],
                              ),
                            const SizedBox(height: 4),
                            Text(email,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.jetBrainsMono(
                                    fontSize: 14,
                                    color: AppColors.inkSecondary)),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                ProfBadge(
                                  label: verified
                                      ? 'Verified Academic'
                                      : 'Unverified',
                                  color: verified
                                      ? AppColors.verified
                                      : AppColors.pending,
                                ),
                                ProfBadge(
                                  label:
                                      role[0].toUpperCase() + role.substring(1),
                                  color: AppColors.inkPrimary,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Performance Metrics by Role ───────────────
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: const BoxDecoration(
                    border:
                        Border(bottom: BorderSide(color: AppColors.marginRule)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Platform Overview',
                          style: GoogleFonts.fraunces(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: AppColors.inkPrimary)),
                      const SizedBox(height: 24),
                      if (role == 'admin') _buildAdminStats(context),
                      if (role == 'professor') _buildProfStats(context),
                      if (role == 'student') _buildStudentStats(context),
                      if (role == 'ta') _buildTAStats(context),
                    ],
                  ),
                ),

                // ── Change Password Form ───────────────
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: const BoxDecoration(
                    border:
                        Border(bottom: BorderSide(color: AppColors.marginRule)),
                  ),
                  child: Form(
                    key: _pwFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Change Password',
                            style: GoogleFonts.fraunces(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: AppColors.inkPrimary)),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _oldPassCtrl,
                          obscureText: _obscureOld,
                          decoration: InputDecoration(
                            labelText: 'Current Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(
                                  _obscureOld
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: AppColors.textMuted),
                              onPressed: () =>
                                  setState(() => _obscureOld = !_obscureOld),
                            ),
                          ),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Current password is required.'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _newPassCtrl,
                          obscureText: _obscureNew,
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            prefixIcon: const Icon(Icons.lock_reset_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(
                                  _obscureNew
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: AppColors.textMuted),
                              onPressed: () =>
                                  setState(() => _obscureNew = !_obscureNew),
                            ),
                          ),
                          validator: Validators.password,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _confirmCtrl,
                          obscureText: _obscureConfirm,
                          decoration: InputDecoration(
                            labelText: 'Confirm New Password',
                            prefixIcon:
                                const Icon(Icons.check_circle_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: AppColors.textMuted),
                              onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),
                          validator: (v) => v != _newPassCtrl.text
                              ? 'Passwords do not match.'
                              : null,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _savingPw ? null : _changePassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.inkPrimary,
                            foregroundColor: AppColors.bgPage,
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                            textStyle: GoogleFonts.inter(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          child: _savingPw
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5))
                              : const Text('Update Password'),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── APPEARANCE & DESIGN SYSTEM ────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.r6),
                      border: Border.all(color: AppColors.rule, width: 1),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'APPEARANCE & DESIGN SYSTEM',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            color: AppColors.inkGhost,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Select your visual environment. You can switch between "The Journal" (v2 2026/2027) and "Marginalia" (v1 Classic) at any time.',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: AppColors.inkSecondary,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Design System Switcher
                        Text(
                          'Design Edition',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.inkPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _buildSelectionChip(
                              label: 'The Journal v2 (2026/2027 Editorial)',
                              isSelected: ref.watch(themeStateProvider).designSystem == DesignSystem.journal,
                              onTap: () {
                                ref.read(themeStateProvider.notifier).setDesignSystem(DesignSystem.journal);
                                JournalToastManager.show(context, 'Switched to The Journal v2 Design');
                              },
                            ),
                            _buildSelectionChip(
                              label: 'Marginalia v1 (Classic Paper)',
                              isSelected: ref.watch(themeStateProvider).designSystem == DesignSystem.marginalia,
                              onTap: () {
                                ref.read(themeStateProvider.notifier).setDesignSystem(DesignSystem.marginalia);
                                JournalToastManager.show(context, 'Switched to Marginalia v1 Design');
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),
                        const Divider(color: AppColors.rule, height: 1),
                        const SizedBox(height: 20),

                        // Theme Mode Switcher
                        Text(
                          'Theme Palette',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.inkPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _buildSelectionChip(
                              label: 'Pressroom Night (Dark - Default)',
                              isSelected: ref.watch(themeStateProvider).themeMode == JournalThemeMode.dark,
                              onTap: () {
                                ref.read(themeStateProvider.notifier).setThemeMode(JournalThemeMode.dark);
                                JournalToastManager.show(context, 'Theme set to Pressroom Night');
                              },
                            ),
                            _buildSelectionChip(
                              label: 'Pressroom Day (Light)',
                              isSelected: ref.watch(themeStateProvider).themeMode == JournalThemeMode.light,
                              onTap: () {
                                ref.read(themeStateProvider.notifier).setThemeMode(JournalThemeMode.light);
                                JournalToastManager.show(context, 'Theme set to Pressroom Day');
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.logout_rounded,
                        color: AppColors.feedbackRed),
                    label: Text('Sign out from all active sessions',
                        style: GoogleFonts.inter(
                            color: AppColors.feedbackRed,
                            fontWeight: FontWeight.w600)),
                    onPressed: () async {
                      final confirmed = await ProfConfirmSheet.show(
                        context,
                        title: 'Sign Out Everywhere',
                        body:
                            'This will invalidate your current authentication token and log out all active sessions on other browsers.',
                        confirmLabel: 'Sign Out Everywhere',
                      );
                      if (confirmed == true && mounted) {
                        await ref.read(authProvider.notifier).logout();
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.feedbackRed),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _academicStatCard(
      String title, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
          border: Border(
        bottom: BorderSide(color: AppColors.marginRule),
        right: BorderSide(color: AppColors.marginRule),
      )),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 12, color: AppColors.inkSecondary)),
                const SizedBox(height: 6),
                Text(val,
                    style: GoogleFonts.fraunces(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminStats(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 560;
    final children = [
      Expanded(
          child: _academicStatCard('Total Cohorts Analyzed', '12',
              Icons.analytics_outlined, AppColors.inkPrimary)),
      if (!isMobile) const SizedBox(width: 14),
      Expanded(
          child: _academicStatCard('Global HEC Sync Status', 'Synced',
              Icons.sync_rounded, AppColors.verified)),
      if (!isMobile) const SizedBox(width: 14),
      Expanded(
          child: _academicStatCard('AI Model Uptime', '99.9%',
              Icons.dns_outlined, AppColors.successGreen)),
    ];
    return isMobile
        ? Column(
            children: children
                .map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 14), child: c))
                .toList())
        : Row(children: children);
  }

  Widget _buildProfStats(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 560;
    final row1 = [
      Expanded(
          child: _academicStatCard('Students Flagged At-Risk', '18',
              Icons.warning_amber_rounded, AppColors.pending)),
      if (!isMobile) const SizedBox(width: 14),
      Expanded(
          child: _academicStatCard('HEC Compliance Score', '98.4%',
              Icons.verified_outlined, AppColors.verified)),
    ];
    final row2 = [
      Expanded(
          child: _academicStatCard('AI Grading Speed', '1.2m / sub',
              Icons.bolt_outlined, AppColors.signal)),
      if (!isMobile) const SizedBox(width: 14),
      Expanded(child: Container()), // Empty space for alignment
    ];

    return isMobile
        ? Column(
            children: [...row1, ...row2]
                .whereType<Expanded>()
                .map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 14), child: c))
                .toList())
        : Column(children: [
            Row(children: row1),
            const SizedBox(height: 14),
            Row(children: row2)
          ]);
  }

  Widget _buildStudentStats(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 560;
    final children = [
      Expanded(
          child: _academicStatCard('Overall Competency Index', '82 / 100',
              Icons.psychology_outlined, AppColors.primaryIndigo)),
      if (!isMobile) const SizedBox(width: 14),
      Expanded(
          child: _academicStatCard('Weakness Areas', '3 Identified',
              Icons.troubleshoot_rounded, AppColors.pending)),
      if (!isMobile) const SizedBox(width: 14),
      Expanded(
          child: _academicStatCard('Automated Feedback', '45 Processed',
              Icons.chat_bubble_outline_rounded, AppColors.verified)),
    ];
    return isMobile
        ? Column(
            children: children
                .map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 14), child: c))
                .toList())
        : Row(children: children);
  }

  Widget _buildTAStats(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 560;
    final children = [
      Expanded(
          child: _academicStatCard('Eval Batches Processed', '8 Batches',
              Icons.batch_prediction_outlined, AppColors.primaryIndigo)),
      if (!isMobile) const SizedBox(width: 14),
      Expanded(
          child: _academicStatCard('Discrepancy vs AI', '2.1%',
              Icons.compare_arrows_rounded, AppColors.pending)),
      if (!isMobile) const SizedBox(width: 14),
      Expanded(
          child: _academicStatCard('Pending Reviews', '14',
              Icons.pending_actions_rounded, AppColors.feedbackRed)),
    ];
    return isMobile
        ? Column(
            children: children
                .map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 14), child: c))
                .toList())
        : Row(children: children);
  }

  Widget _buildSelectionChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surfaceMid : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.r4),
            border: Border.all(
              color: isSelected ? AppColors.ruleStrong : AppColors.rule,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.statusPassInk,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? AppColors.inkPrimary : AppColors.inkSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
