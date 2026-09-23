/// ProfessorOS – Student Dashboard Screen.
/// Shows enrolled courses, live upcoming deadlines, recent feedback, and real metrics.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/prof_shimmer.dart';
import '../../../shared/widgets/prof_empty_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/course_providers.dart';
import '../data/course_repository.dart';
import '../../../core/utils/error_parser.dart';
import 'widgets/upcoming_deadlines_widget.dart';
import 'widgets/recent_feedback_widget.dart';

class StudentDashboardScreen extends ConsumerWidget {
  const StudentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(studentDashboardProvider);
    final user = ref.watch(authProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Student Dashboard',
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
            Text('Your enrolled courses and progress',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () => _showJoinDialog(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Join Course'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryIndigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
      body: coursesAsync.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(24),
          children: List.generate(3, (_) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ProfShimmer.card(height: 160),
          )),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.dangerRose),
                const SizedBox(height: 12),
                Text('Failed to load courses', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(ErrorParser.parse(err), textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: AppColors.dangerRose)),
              ],
            ),
          ),
        ),
        data: (data) {
          final allCourses = (data['courses'] as List<dynamic>).cast<Map<String, dynamic>>();
          final stats = (data['stats'] as Map<String, dynamic>?) ?? {};
          final upcoming = ((data['upcoming'] as List<dynamic>?) ?? [])
              .cast<Map<String, dynamic>>()
              .map((item) {
                final deadline = DateTime.tryParse(item['deadline']?.toString() ?? '');
                final hours = deadline == null ? 9999 : deadline.difference(DateTime.now()).inHours;
                return <String, dynamic>{
                  ...item,
                  'due_date_label': deadline == null ? 'Due soon' : _formatDeadline(deadline),
                  'is_urgent': hours <= 48,
                };
              }).toList();
          final feedback = ((data['feedback'] as List<dynamic>?) ?? [])
              .cast<Map<String, dynamic>>()
              .map((item) => <String, dynamic>{
                    ...item,
                    'comment': item['feedback'] ?? '',
                    'date_label': _formatDate(item['graded_at']),
                  })
              .toList();
          
          if (allCourses.isEmpty) {
            return ProfEmptyState(
              icon: Icons.school_rounded,
              title: 'Not enrolled in any courses',
              subtitle: 'Your professor will enroll you shortly. Contact them if you believe this is an error.',
              actionLabel: null,
            );
          }

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Welcome header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppGradients.primaryButton,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [const BoxShadow(color: Color(0x304F46E5), blurRadius: 16, offset: Offset(0, 6))],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Welcome back,',
                              style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withOpacity(0.8))),
                          const SizedBox(height: 4),
                          Text(user?['full_name'] ?? 'Student',
                              style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                          const SizedBox(height: 6),
                          Text('${allCourses.length} active enrollment(s)',
                              style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.7))),
                        ],
                      ),
                    ),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.school_rounded, color: Colors.white, size: 32),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Quick Stats (Live calculations)
              Row(
                children: [
                  _quickStatCard('Enrolled', '${allCourses.length}', Icons.menu_book_rounded, AppColors.primaryIndigo),
                  const SizedBox(width: 12),
                  _quickStatCard('Pending', '${stats['pending'] ?? 0}', Icons.pending_actions_rounded, AppColors.accentAmber),
                  const SizedBox(width: 12),
                  _quickStatCard('Graded', '${stats['graded'] ?? 0}', Icons.grading_rounded, AppColors.successGreen),
                ],
              ),
              const SizedBox(height: 24),

              // Upcoming Deadlines Section
              UpcomingDeadlinesWidget(items: upcoming),
              const SizedBox(height: 24),

              // Recent Feedback Section
              RecentFeedbackWidget(feedbackItems: feedback),
              const SizedBox(height: 24),

              // My Courses Section
              Text('My Courses',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 12),

              ...allCourses.map((course) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => context.go('/courses/${course['id']}'),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primaryIndigo.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.menu_book_rounded, color: AppColors.primaryIndigo, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(course['title'],
                                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                const SizedBox(height: 4),
                                Text('${course['code']} • ${course['semester']}',
                                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.bgPage,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('${course['assignment_count'] ?? 0} asg',
                                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                ),
              )),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showJoinDialog(BuildContext context, WidgetRef ref) async {
    final codeCtrl = TextEditingController();
    bool loading = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Join Course', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter the 6-character course code provided by your instructor.',
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeCtrl,
                autofocus: true,
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Course Code',
                  hintText: 'e.g. A9B8C7',
                  counterText: '',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: loading ? null : () async {
                final code = codeCtrl.text.trim().toUpperCase();
                if (code.isEmpty) return;
                setState(() => loading = true);
                try {
                  await CourseRepository().joinCourse(code);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ref.invalidate(courseListProvider);
                    ref.invalidate(studentDashboardProvider);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Successfully joined the course!'),
                      backgroundColor: AppColors.successGreen,
                    ));
                  }
                } catch (e) {
                  setState(() => loading = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(ErrorParser.parse(e)),
                    backgroundColor: AppColors.dangerRose,
                  ));
                }
              },
              child: loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Join'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDeadline(DateTime date) {
    final difference = date.difference(DateTime.now());
    if (difference.inHours < 24) return 'Due today';
    if (difference.inDays == 1) return 'Due tomorrow';
    return 'Due in ${difference.inDays} days';
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'Recently';
    final days = DateTime.now().difference(date).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    return '$days days ago';
  }

  Widget _quickStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(value, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
