import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_parser.dart';
import '../../../shared/widgets/prof_empty_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/course_repository.dart';
import '../providers/course_providers.dart';

class CourseListScreen extends ConsumerStatefulWidget {
  const CourseListScreen({super.key});

  @override
  ConsumerState<CourseListScreen> createState() => _CourseListScreenState();
}

class _CourseListScreenState extends ConsumerState<CourseListScreen> {
  String _filter = 'active'; // 'active', 'archived'

  Future<void> _showJoinCourseDialog(BuildContext context) async {
    final codeCtrl = TextEditingController();
    var loading = false;
    var error = '';

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Join Course'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Enter the 6-character code provided by your instructor:'),
              const SizedBox(height: 12),
              TextField(
                controller: codeCtrl,
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Course Code',
                  hintText: 'e.g. A1B2C3',
                ),
              ),
              if (error.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(error,
                    style: const TextStyle(
                        color: AppColors.feedbackRed, fontSize: 13)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      final code = codeCtrl.text.trim().toUpperCase();
                      if (code.length < 4) {
                        setDialogState(() => error = 'Enter a valid join code');
                        return;
                      }
                      setDialogState(() {
                        loading = true;
                        error = '';
                      });
                      try {
                        await CourseRepository().joinCourse(code);
                        if (context.mounted) {
                          ref.invalidate(courseListProvider);
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Successfully joined course!'),
                              backgroundColor: AppColors.verified,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          error = ErrorParser.parse(e);
                          loading = false;
                        });
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Join'),
            ),
          ],
        ),
      ),
    );
    codeCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role =
        ref.watch(authProvider).valueOrNull?['role'] as String? ?? 'student';
    final isAdmin = role == 'admin';
    final isProf = role == 'professor' || role == 'admin';
    final coursesAsync = ref.watch(courseListProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 600;
                final heading = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isProf ? 'Course Ledger' : 'My Enrollments',
                      style: GoogleFonts.fraunces(
                        fontSize: isNarrow ? 28 : 32,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isProf
                          ? 'Manage offerings, HEC rubrics & student cohorts.'
                          : 'Your active academic courses.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.inkSecondary,
                      ),
                    ),
                  ],
                );

                final actionButton = isProf
                    ? ElevatedButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Create Course'),
                        onPressed: () => context.go('/courses/new'),
                      )
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.group_add_rounded, size: 18),
                        label: const Text('Join with Code'),
                        onPressed: () => _showJoinCourseDialog(context),
                      );

                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    isNarrow ? 20 : 40,
                    isNarrow ? 28 : 48,
                    isNarrow ? 20 : 40,
                    24,
                  ),
                  child: isNarrow
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            heading,
                            const SizedBox(height: 18),
                            actionButton,
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(child: heading),
                            actionButton,
                          ],
                        ),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(
                      bottom:
                          BorderSide(color: AppColors.marginRule, width: 1)),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _TabBtn(
                          label: 'Active',
                          active: _filter == 'active',
                          onTap: () => setState(() => _filter = 'active')),
                      const SizedBox(width: 24),
                      _TabBtn(
                          label: 'Archived',
                          active: _filter == 'archived',
                          onTap: () => setState(() => _filter = 'archived')),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            sliver: coursesAsync.when(
              loading: () => const SliverToBoxAdapter(
                  child: Center(
                      child:
                          CircularProgressIndicator(color: AppColors.signal))),
              error: (err, _) => SliverToBoxAdapter(
                child: Text('Failed to load: $err',
                    style: const TextStyle(color: AppColors.feedbackRed)),
              ),
              data: (data) {
                final allCourses = (data['courses'] as List<dynamic>)
                    .cast<Map<String, dynamic>>();
                final courses = allCourses.where((c) {
                  final isArchived = (c['is_archived'] as bool? ?? false);
                  if (_filter == 'active') return !isArchived;
                  if (_filter == 'archived') return isArchived;
                  return true;
                }).toList();

                if (courses.isEmpty) {
                  final String emptyTitle = isAdmin
                      ? 'No courses created'
                      : (isProf ? 'No courses assigned' : 'No courses found');
                  final String emptySub = isAdmin
                      ? 'Click Create Course to add a course and assign it to a professor.'
                      : (isProf
                          ? 'You have not been assigned to any active courses yet. Contact an administrator.'
                          : 'You are not enrolled in any courses.');
                  return SliverToBoxAdapter(
                    child: ProfEmptyState(
                      icon: Icons.menu_book_rounded,
                      title: emptyTitle,
                      subtitle: emptySub,
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final course = courses[index];
                      return _CourseRow(course: course, isProf: isProf);
                    },
                    childCount: courses.length,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabBtn(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  color: active ? AppColors.signal : Colors.transparent,
                  width: 2)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: active ? AppColors.inkPrimary : AppColors.inkSecondary,
          ),
        ),
      ),
    );
  }
}

class _CourseRow extends StatefulWidget {
  final Map<String, dynamic> course;
  final bool isProf;
  const _CourseRow({required this.course, required this.isProf});

  @override
  State<_CourseRow> createState() => _CourseRowState();
}

class _CourseRowState extends State<_CourseRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final course = widget.course;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.go('/courses/${course['id']}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.bgActive : Colors.transparent,
            border: const Border(
                bottom: BorderSide(color: AppColors.marginRule, width: 1)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course['title'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    course['code'],
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 13, color: AppColors.inkSecondary),
                  ),
                ],
              );
              final meta = Text(
                widget.isProf
                    ? course['semester']
                    : course['professor_name'] ?? 'Unknown',
                style: GoogleFonts.inter(
                    fontSize: 14, color: AppColors.inkSecondary),
              );
              final enrollment = Text(
                '${course['enrollment_count']} students',
                style: GoogleFonts.inter(
                    fontSize: 14, color: AppColors.inkSecondary),
              );

              if (constraints.maxWidth < 600) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: meta),
                        enrollment,
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.inkSecondary, size: 20),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 3, child: title),
                  Expanded(flex: 2, child: meta),
                  Expanded(flex: 1, child: enrollment),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.inkSecondary, size: 20),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
