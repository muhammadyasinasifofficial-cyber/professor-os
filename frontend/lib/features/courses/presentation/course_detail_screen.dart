import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/journal_ui/journal_components.dart';
import '../../../shared/widgets/prof_badge.dart';
import '../../../shared/widgets/prof_card.dart';
import '../../../shared/widgets/prof_shimmer.dart';
import '../../../shared/widgets/prof_empty_state.dart';
import '../../../shared/widgets/hec_weightage_widget.dart';
import '../../../shared/widgets/prof_confirm_sheet.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/error_parser.dart';
import '../data/course_repository.dart';
import '../providers/course_providers.dart';
import 'ai_quiz_obe_dialog.dart';

class CourseDetailScreen extends ConsumerStatefulWidget {
  final int courseId;
  const CourseDetailScreen({super.key, required this.courseId});

  @override
  ConsumerState<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen>
    with TickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    final role =
        ref.read(authProvider).valueOrNull?['role'] as String? ?? 'student';
    final isProf = role == 'professor' || role == 'admin';
    _tabCtrl = TabController(length: isProf ? 4 : 2, vsync: this);
    _tabCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _openAIQuizAndOBE([String? courseTitle]) async {
    final title = courseTitle ?? 'Course Assessments';
    await AiQuizObeDialog.show(context, widget.courseId, title);
  }

  Future<void> _showCourseChat([String? courseTitle]) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => CourseAiChatDialog(
        courseId: widget.courseId,
        courseTitle: courseTitle ?? 'Course',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 600;
    final role =
        ref.watch(authProvider).valueOrNull?['role'] as String? ?? 'student';
    final isProf = role == 'professor' || role == 'admin';

    final courseAsync = ref.watch(courseDetailProvider(widget.courseId));

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.bgPage,
        title: courseAsync.when(
          data: (c) => Row(
            children: [
              ProfBadge(label: c['code'], color: AppColors.inkPrimary),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(c['title'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSerifDisplay(
                          fontWeight: FontWeight.w400,
                          fontSize: 24,
                          color: AppColors.inkPrimary))),
            ],
          ),
          loading: () => const ProfShimmer(width: 120, height: 20),
          error: (_, __) => const Text('Course Details'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.psychology, size: 16),
              label: isNarrow
                  ? const SizedBox.shrink()
                  : const Text('Ask Course AI'),
              onPressed: () => _showCourseChat(
                  courseAsync.valueOrNull?['title'] as String?),
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.surfaceMid,
                foregroundColor: AppColors.inkPrimary,
                side: const BorderSide(color: AppColors.ruleStrong),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
              ),
            ),
          ),
          if (isProf) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: isNarrow
                    ? const SizedBox.shrink()
                    : const Text('AI Quiz & OBE'),
                onPressed: () => _openAIQuizAndOBE(
                    courseAsync.valueOrNull?['title'] as String?),
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.surfaceMid,
                  foregroundColor: AppColors.inkPrimary,
                  side: const BorderSide(color: AppColors.ruleStrong),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.insights_rounded, size: 16),
                label: isNarrow
                    ? const SizedBox.shrink()
                    : const Text('Cohort Analytics'),
                onPressed: () =>
                    context.go('/courses/${widget.courseId}/analytics'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.surfaceMid,
                  foregroundColor: AppColors.inkPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  side: const BorderSide(color: AppColors.ruleStrong),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: IconButton(
                icon: const Icon(Icons.settings_outlined,
                    color: AppColors.inkPrimary),
                tooltip: 'Course Settings',
                onPressed: () => context.go('/courses/${widget.courseId}/edit'),
              ),
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          labelColor: AppColors.inkPrimary,
          unselectedLabelColor: AppColors.inkSecondary,
          indicatorSize: TabBarIndicatorSize.label,
          indicator: const UnderlineTabIndicator(
            borderSide: BorderSide(color: AppColors.inkPrimary, width: 2),
          ),
          labelStyle: GoogleFonts.dmSans(
              fontWeight: FontWeight.w600, fontSize: 14),
          unselectedLabelStyle: GoogleFonts.dmSans(
              fontWeight: FontWeight.w500, fontSize: 14),
          tabs: isProf
              ? const [
                  Tab(text: 'Assignments'),
                  Tab(text: 'Materials'),
                  Tab(text: 'Students Roster'),
                  Tab(text: 'Course Settings'),
                ]
              : const [
                  Tab(text: 'Assignments'),
                  Tab(text: 'Materials'),
                ],
        ),
      ),
      body: courseAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text(ErrorParser.parse(e),
                style: const TextStyle(color: AppColors.dangerRose))),
        data: (course) => TabBarView(
          controller: _tabCtrl,
          children: isProf
              ? [
                  _AssignmentsTab(courseId: widget.courseId, isProf: true),
                  _MaterialsTab(courseId: widget.courseId, isProf: true),
                  _StudentsTab(courseId: widget.courseId, isProf: true),
                  _SettingsTab(course: course),
                ]
              : [
                  _AssignmentsTab(courseId: widget.courseId, isProf: false),
                  _MaterialsTab(courseId: widget.courseId, isProf: false),
                ],
        ),
      ),
      floatingActionButton: isProf
          ? (_tabCtrl.index == 0
              ? FloatingActionButton.extended(
                  onPressed: () =>
                      context.go('/courses/${widget.courseId}/assignments/new'),
                  backgroundColor: AppColors.inkPrimary,
                  elevation: 0,
                  icon: const Icon(Icons.add_rounded, color: AppColors.canvas),
                  label: Text('New Assignment',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600, color: AppColors.canvas)),
                )
              : null)
          : FloatingActionButton.extended(
              onPressed: () =>
                  _showCourseChat(courseAsync.valueOrNull?['title'] as String?),
              backgroundColor: AppColors.inkPrimary,
              elevation: 0,
              icon:
                  const Icon(Icons.auto_awesome, color: AppColors.canvas, size: 20),
              label: Text('Ask Course AI',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700, color: AppColors.canvas)),
            ),
    );
  }
}

class _AssignmentsTab extends ConsumerStatefulWidget {
  final int courseId;
  final bool isProf;
  const _AssignmentsTab({required this.courseId, required this.isProf});

  @override
  ConsumerState<_AssignmentsTab> createState() => _AssignmentsTabState();
}

class _AssignmentsTabState extends ConsumerState<_AssignmentsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  IconData _getAssignmentIcon(String type) {
    switch (type.toLowerCase()) {
      case 'qna':
        return Icons.quiz_rounded;
      case 'file':
        return Icons.cloud_upload_rounded;
      case 'mcq':
        return Icons.check_circle_outline_rounded;
      case 'programming':
        return Icons.terminal_rounded;
      case 'hybrid':
        return Icons.hub_rounded;
      default:
        return Icons.article_rounded;
    }
  }

  Future<void> _showAssignTADialog(
      BuildContext context, int assignmentId, String title) async {
    try {
      final repo = CourseRepository();
      final roster = await repo.listEnrollments(widget.courseId);
      final tas = roster
          .where((e) => (e['role'] ?? '').toString().toLowerCase() == 'ta')
          .toList();
      final assigned =
          (await repo.listAssignmentTAs(widget.courseId, assignmentId))
              .map((e) => e['user_id'] as int)
              .toSet();
      if (!context.mounted) return;
      final selected = Set<int>.from(assigned);
      final save = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text('Assign TAs · $title'),
            content: SizedBox(
              width: 420,
              child: tas.isEmpty
                  ? const Text(
                      'Enroll at least one user as a TA in this course first.')
                  : ListView(
                      shrinkWrap: true,
                      children: tas.map((ta) {
                        final id = ta['user_id'] as int;
                        return CheckboxListTile(
                          value: selected.contains(id),
                          title: Text(ta['user_name'] ?? 'User #$id'),
                          subtitle: Text(ta['user_email'] ?? ''),
                          onChanged: (value) => setDialogState(() {
                            if (value == true) {
                              selected.add(id);
                            } else {
                              selected.remove(id);
                            }
                          }),
                        );
                      }).toList(),
                    ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              if (tas.isNotEmpty)
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Save')),
            ],
          ),
        ),
      );
      if (save != true) return;
      final current = assigned;
      for (final id in selected.difference(current)) {
        await repo.assignTA(widget.courseId, assignmentId, id);
      }
      for (final id in current.difference(selected)) {
        await repo.removeTA(widget.courseId, assignmentId, id);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Assignment delegation updated.'),
          backgroundColor: AppColors.successGreen,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ErrorParser.parse(e)),
          backgroundColor: AppColors.dangerRose,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final courseId = widget.courseId;
    final isProf = widget.isProf;
    final assignmentsAsync = ref.watch(assignmentListProvider(courseId));
    return assignmentsAsync.when(
      loading: () => ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (_, __) => ProfShimmer.card(height: 100),
      ),
      error: (e, _) => Center(child: Text(ErrorParser.parse(e))),
      data: (data) {
        final assignments = data['assignments'] as List<dynamic>;
        if (assignments.isEmpty) {
          return ProfEmptyState(
            icon: Icons.assignment_outlined,
            title: 'No assignments created yet.',
            subtitle: isProf
                ? 'Create an assignment with HEC rubric to start collecting submissions.'
                : 'Check back when your professor posts an assignment.',
            actionLabel: isProf ? 'Create First Assignment' : null,
            onAction: isProf
                ? () => context.go('/courses/$courseId/assignments/new')
                : null,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          itemCount: assignments.length,
          itemBuilder: (context, index) {
            final a = assignments[index] as Map<String, dynamic>;
            final status = (a['status'] as String? ?? 'draft').toLowerCase();
            final statusColor = status == 'published'
                ? AppColors.verified
                : (status == 'closed'
                    ? AppColors.inkSecondary
                    : AppColors.pending);

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () =>
                    context.go('/courses/$courseId/assignments/${a['id']}'),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  decoration: const BoxDecoration(
                    border: Border(
                        bottom:
                            BorderSide(color: AppColors.marginRule, width: 1)),
                  ),
                  child: Row(
                    children: [
                      Icon(_getAssignmentIcon(a['type'] ?? 'text'),
                          color: AppColors.inkSecondary, size: 24),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a['title'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.inkPrimary)),
                            const SizedBox(height: 4),
                            Text(
                                '${a['max_marks']} pts • ${a['type'].toString().toUpperCase()}',
                                style: GoogleFonts.jetBrainsMono(
                                    fontSize: 13,
                                    color: AppColors.inkSecondary)),
                          ],
                        ),
                      ),
                      ProfBadge(
                          label: status.toUpperCase(), color: statusColor),
                      const SizedBox(width: 16),
                      if (isProf) ...[
                        IconButton(
                          icon: const Icon(Icons.group_add_rounded,
                              color: AppColors.primaryIndigo, size: 20),
                          tooltip: 'Assign Teaching Assistant',
                          onPressed: () => _showAssignTADialog(
                              context, a['id'] as int, a['title'] as String),
                        ),
                        if (status == 'draft')
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _PublishButton(
                              courseId: courseId,
                              assignmentId: a['id'] as int,
                              onPublished: () => ref
                                  .invalidate(assignmentListProvider(courseId)),
                            ),
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: AppColors.dangerRose, size: 20),
                          tooltip: 'Delete Assignment',
                          onPressed: () async {
                            final confirm = await ProfConfirmSheet.show(
                              context,
                              title: 'Delete Assignment',
                              body:
                                  'Are you sure you want to permanently delete "${a['title']}" and its submissions?',
                            );
                            if (confirm == true) {
                              try {
                                await CourseRepository()
                                    .deleteAssignment(courseId, a['id'] as int);
                                ref.invalidate(
                                    assignmentListProvider(courseId));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(
                                    content: Text('Assignment deleted.'),
                                    backgroundColor: AppColors.successGreen,
                                  ));
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: Text(ErrorParser.parse(e)),
                                    backgroundColor: AppColors.dangerRose,
                                  ));
                                }
                              }
                            }
                          },
                        ),
                      ],
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.inkSecondary),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _PublishButton extends ConsumerStatefulWidget {
  final int courseId;
  final int assignmentId;
  final VoidCallback onPublished;
  const _PublishButton(
      {required this.courseId,
      required this.assignmentId,
      required this.onPublished});

  @override
  ConsumerState<_PublishButton> createState() => _PublishButtonState();
}

class _PublishButtonState extends ConsumerState<_PublishButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ElevatedButton(
        onPressed: _loading
            ? null
            : () async {
                setState(() => _loading = true);
                try {
                  await CourseRepository()
                      .publishAssignment(widget.courseId, widget.assignmentId);
                  widget.onPublished();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Assignment published!'),
                      backgroundColor: AppColors.successGreen,
                    ));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Failed: ${ErrorParser.parse(e)}'),
                      backgroundColor: AppColors.dangerRose,
                    ));
                  }
                } finally {
                  if (mounted) setState(() => _loading = false);
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.verified,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle:
              GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        child: _loading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : const Text('Publish'),
      ),
    );
  }
}

class _StudentsTab extends ConsumerStatefulWidget {
  final int courseId;
  final bool isProf;
  const _StudentsTab({required this.courseId, required this.isProf});

  @override
  ConsumerState<_StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends ConsumerState<_StudentsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _enrollDialog() async {
    final emailCtrl = TextEditingController();
    String role = 'student';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Enroll Student or TA',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: 'Student Email',
                    hintText: 'e.g. student@univ.edu.pk'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'student', child: Text('Student')),
                  DropdownMenuItem(
                      value: 'ta', child: Text('Teaching Assistant (TA)')),
                ],
                onChanged: (val) => role = val!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final email = emailCtrl.text.trim();
              if (email.isEmpty) return;
              try {
                await CourseRepository()
                    .enrollUserByEmail(widget.courseId, email, role);
                if (mounted) {
                  Navigator.pop(ctx);
                  ref.invalidate(courseEnrollmentsProvider(widget.courseId));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('User enrolled successfully.'),
                      backgroundColor: AppColors.successGreen));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(ErrorParser.parse(e)),
                      backgroundColor: AppColors.dangerRose));
                }
              }
            },
            child: const Text('Enroll'),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      try {
        final bytes = result.files.single.bytes!;
        final name = result.files.single.name;
        final res = await CourseRepository()
            .importEnrollmentsCsv(widget.courseId, bytes, name);
        ref.invalidate(courseEnrollmentsProvider(widget.courseId));
        if (mounted) {
          final created = res['created'] ?? 0;
          final errors = (res['errors'] as List? ?? []);
          final msg = errors.isEmpty
              ? '$created ${created == 1 ? 'student' : 'students'} enrolled successfully.'
              : '$created enrolled, ${errors.length} errors (check CSV format).';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(msg),
            backgroundColor:
                errors.isEmpty ? AppColors.successGreen : AppColors.accentAmber,
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ErrorParser.parse(e)),
            backgroundColor: AppColors.dangerRose,
          ));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final enrollmentsAsync =
        ref.watch(courseEnrollmentsProvider(widget.courseId));
    final courseAsync = ref.watch(courseDetailProvider(widget.courseId));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ProfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.isProf) ...[
                  courseAsync.when(
                    data: (course) {
                      final code = course['join_code'] ?? 'N/A';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primaryIndigo.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.primaryIndigo.withOpacity(0.15)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.vpn_key_rounded,
                                color: AppColors.primaryIndigo, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Course Join Code',
                                      style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textMuted,
                                          letterSpacing: 0.5)),
                                  const SizedBox(height: 2),
                                  Text(code,
                                      style: GoogleFonts.outfit(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primaryIndigo,
                                          letterSpacing: 1.5)),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.copy_rounded, size: 14),
                              label: const Text('Copy'),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: code));
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(const SnackBar(
                                  content:
                                      Text('Course code copied to clipboard!'),
                                  behavior: SnackBarBehavior.floating,
                                ));
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                side: const BorderSide(
                                    color: AppColors.primaryIndigo),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Text('Enrolled Student Roster',
                        style: GoogleFonts.outfit(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    if (widget.isProf)
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            icon:
                                const Icon(Icons.person_add_rounded, size: 16),
                            label: const Text('Enroll Single'),
                            onPressed: _enrollDialog,
                          ),
                          OutlinedButton.icon(
                            icon:
                                const Icon(Icons.upload_file_rounded, size: 16),
                            label: const Text('Import CSV'),
                            onPressed: _uploadCsv,
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _searchCtrl,
                  onChanged: (val) =>
                      setState(() => _query = val.trim().toLowerCase()),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                    hintText: 'Search by student name, email, or role...',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 20),
                enrollmentsAsync.when(
                  loading: () => ProfShimmer.lines(count: 4),
                  error: (e, _) => Center(
                      child: Text(e.toString(),
                          style: const TextStyle(color: AppColors.dangerRose))),
                  data: (enrollments) {
                    final filtered = enrollments.where((e) {
                      final name =
                          (e['user_name'] ?? '').toString().toLowerCase();
                      final email =
                          (e['user_email'] ?? '').toString().toLowerCase();
                      final role = (e['role'] ?? '').toString().toLowerCase();
                      return name.contains(_query) ||
                          email.contains(_query) ||
                          role.contains(_query);
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                            child: Text('No enrolled students found.',
                                style: TextStyle(color: AppColors.textMuted))),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final item = filtered[index] as Map<String, dynamic>;
                        final name =
                            item['user_name'] ?? 'User #${item['user_id']}';
                        final email = item['user_email'] ?? '';
                        final role = (item['role'] ?? 'student')
                            .toString()
                            .toUpperCase();
                        final initials = name.isNotEmpty
                            ? name
                                .split(' ')
                                .map((e) => e.isNotEmpty ? e[0] : '')
                                .take(2)
                                .join()
                                .toUpperCase()
                            : 'U';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                AppColors.primaryIndigo.withOpacity(0.1),
                            child: Text(initials,
                                style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryIndigo)),
                          ),
                          title: Text(name,
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              email.isNotEmpty
                                  ? '$email • Role: $role'
                                  : 'Role: $role',
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: AppColors.textMuted)),
                          trailing: Wrap(
                            spacing: 8,
                            alignment: WrapAlignment.end,
                            children: [
                              ProfBadge(
                                  label: role,
                                  color: role == 'TA'
                                      ? AppColors.accentAmber
                                      : AppColors.inkPrimary),
                              if (widget.isProf) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      color: AppColors.dangerRose, size: 20),
                                  onPressed: () async {
                                    final confirm = await ProfConfirmSheet.show(
                                      context,
                                      title: 'Remove Student',
                                      body:
                                          'Are you sure you want to remove "$name" from this course?',
                                    );
                                    if (confirm == true) {
                                      await CourseRepository().removeEnrollment(
                                          widget.courseId, item['user_id']);
                                      ref.invalidate(courseEnrollmentsProvider(
                                          widget.courseId));
                                    }
                                  },
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsTab extends ConsumerWidget {
  final Map<String, dynamic> course;
  const _SettingsTab({required this.course});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider).valueOrNull?['role'] as String?;
    final canManageCourse = role == 'professor' || role == 'admin';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Course Details',
                        style: GoogleFonts.outfit(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    Text('Title: ${course['title']}',
                        style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Course Code: ${course['code']}',
                        style: GoogleFonts.inter(fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('Semester: ${course['semester']}',
                        style: GoogleFonts.inter(fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ProfCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('HEC Assessment Weightage',
                        style: GoogleFonts.outfit(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    HECWeightageWidget(
                      quiz: course['quiz_weight'] ?? 20,
                      assignment: course['assignment_weight'] ?? 20,
                      midterm: course['midterm_weight'] ?? 20,
                      finalExam: course['final_weight'] ?? 40,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (canManageCourse) ...[
                ProfCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Danger Zone',
                          style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.dangerRose)),
                      const SizedBox(height: 6),
                      Text(
                        'Archiving hides this course from active dashboards while preserving all historical assignments, rubrics, submissions, and CLO analytics intact for accreditation audits.',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textMuted,
                            height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.archive_outlined,
                            color: AppColors.dangerRose),
                        label: const Text('Archive Course (Preserves Data)',
                            style: TextStyle(
                                color: AppColors.dangerRose,
                                fontWeight: FontWeight.w600)),
                        onPressed: () async {
                          final confirm = await ProfConfirmSheet.show(
                            context,
                            title: 'Archive Course',
                            body:
                                'Are you sure you want to archive "${course['title']}"? This will hide it from active lists while keeping all student grades and rubrics preserved.',
                          );
                          if (confirm == true) {
                            try {
                              final cid = course['id'] as int;
                              await CourseRepository().archiveCourse(cid);
                              ref.invalidate(courseListProvider);
                              ref.invalidate(courseDetailProvider(cid));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Course archived successfully.')));
                                context.go('/courses');
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(ErrorParser.parse(e)),
                                        backgroundColor: AppColors.dangerRose));
                              }
                            }
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.dangerRose),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.delete_forever_outlined,
                            color: AppColors.dangerRose),
                        label: const Text('Delete Course Permanently',
                            style: TextStyle(
                                color: AppColors.dangerRose,
                                fontWeight: FontWeight.w600)),
                        onPressed: () async {
                          final confirm = await ProfConfirmSheet.show(
                            context,
                            title: 'Delete Course Permanently',
                            body:
                                'This permanently deletes "${course['title']}" and all assignments, submissions, rubrics, CLOs, enrollments, and analytics. This cannot be undone.',
                          );
                          if (confirm == true) {
                            try {
                              final cid = course['id'] as int;
                              await CourseRepository()
                                  .permanentlyDeleteCourse(cid);
                              ref.invalidate(courseListProvider);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Course permanently deleted.')));
                                context.go('/courses');
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(ErrorParser.parse(e)),
                                        backgroundColor: AppColors.dangerRose));
                              }
                            }
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.dangerRose),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── M-09 Native Course AI Assistant (Multi-Turn RAG Chat) ───

class CourseChatMessage {
  final bool isUser;
  final String text;
  final DateTime timestamp;
  final List<Map<String, dynamic>> sources;

  CourseChatMessage({
    required this.isUser,
    required this.text,
    required this.timestamp,
    this.sources = const [],
  });
}

class CourseAiChatDialog extends StatefulWidget {
  final int courseId;
  final String courseTitle;

  const CourseAiChatDialog({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  State<CourseAiChatDialog> createState() => _CourseAiChatDialogState();
}

class _CourseAiChatDialogState extends State<CourseAiChatDialog> {
  final List<CourseChatMessage> _messages = [];
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _loading = false;
  late final String _sessionId;
  final Set<int> _expandedSourceIndexes = {};

  final List<String> _quickPrompts = [
    'Summarize key concepts from course lecture materials',
    'What are the core formulas and definitions?',
    'Give me 3 practice quiz questions with solutions',
    'Explain the most challenging topics in simple terms',
  ];

  @override
  void initState() {
    super.initState();
    _sessionId =
        'session_${widget.courseId}_${DateTime.now().millisecondsSinceEpoch}';
    _messages.add(
      CourseChatMessage(
        isUser: false,
        text:
            'Hello! I am your AI Teaching Assistant for ${widget.courseTitle}.\n\nAsk me any question about course concepts, exam prep, or pick a suggested topic below!',
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = (presetText ?? _inputCtrl.text).trim();
    if (text.isEmpty || _loading) return;

    if (presetText == null) {
      _inputCtrl.clear();
    }

    setState(() {
      _messages.add(CourseChatMessage(
        isUser: true,
        text: text,
        timestamp: DateTime.now(),
      ));
      _loading = true;
    });
    _scrollToBottom();

    try {
      final res = await CourseRepository().chatWithCourse(
        widget.courseId,
        text,
        sessionId: _sessionId,
      );

      final reply = res['response']?.toString() ?? 'No response returned.';
      final rawSources = res['sources'] as List<dynamic>? ?? [];
      final sources = rawSources.whereType<Map<String, dynamic>>().toList();

      if (mounted) {
        setState(() {
          _messages.add(CourseChatMessage(
            isUser: false,
            text: reply,
            timestamp: DateTime.now(),
            sources: sources,
          ));
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(CourseChatMessage(
            isUser: false,
            text:
                'I encountered an issue processing your query: ${ErrorParser.parse(e)}',
            timestamp: DateTime.now(),
          ));
          _loading = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _messages.add(
        CourseChatMessage(
          isUser: false,
          text:
              'Chat cleared! How can I help you with ${widget.courseTitle}?',
          timestamp: DateTime.now(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isMobile = size.width < 640;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 32,
        vertical: isMobile ? 24 : 32,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: isMobile ? double.infinity : 760,
        height: isMobile ? size.height * 0.85 : 700,
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Dialog Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: AppColors.bgPage,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMid,
                      borderRadius: BorderRadius.circular(AppRadius.r4),
                      border: Border.all(color: AppColors.rule, width: 1),
                    ),
                    child: const Icon(Icons.psychology,
                        color: AppColors.inkPrimary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI Teaching Assistant',
                            style: GoogleFonts.dmSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.inkPrimary)),
                        Text(widget.courseTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                fontSize: 12, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Clear Conversation',
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    onPressed: _clearChat,
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Quick Prompt Chips
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: AppColors.bgSurface,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _quickPrompts.map((prompt) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(prompt,
                            style: GoogleFonts.inter(
                                fontSize: 12, fontWeight: FontWeight.w500)),
                        backgroundColor: AppColors.bgPage,
                        side: const BorderSide(color: AppColors.border),
                        onPressed: _loading ? null : () => _sendMessage(prompt),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Messages List
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                itemCount: _messages.length,
                itemBuilder: (context, i) {
                  final msg = _messages[i];
                  return _buildMessageItem(msg, i);
                },
              ),
            ),

            // Thinking Indicator
            if (_loading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.signal),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'AI is retrieving course materials & synthesizing answer...',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),

            // Input Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.bgPage,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText:
                            'Ask any question about lectures, assignments, or concepts...',
                        hintStyle: GoogleFonts.inter(
                            fontSize: 13, color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.bgSurface,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppColors.signal),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _loading ? null : () => _sendMessage(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.inkPrimary,
                      foregroundColor: AppColors.canvas,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.r4)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    child: const Icon(Icons.send_rounded, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(CourseChatMessage msg, int msgIndex) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14, left: 60),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceMid,
            borderRadius: BorderRadius.circular(AppRadius.r4),
            border: Border.all(color: AppColors.ruleStrong, width: 1),
          ),
          child: SelectableText(
            msg.text,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: AppColors.inkPrimary,
              height: 1.5,
            ),
          ),
        ),
      );
    }

    // Assistant response
    final isExpanded = _expandedSourceIndexes.contains(msgIndex);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, right: 40),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.r4),
          border: Border.all(color: AppColors.rule, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology, size: 16, color: AppColors.signal),
                const SizedBox(width: 6),
                Text('AI Assistant',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.signal)),
                const Spacer(),
                Text(
                  '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 10, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SelectableText(
              msg.text,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.inkPrimary,
                height: 1.5,
              ),
            ),
            // RAG Sources Citations
            if (msg.sources.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              InkWell(
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedSourceIndexes.remove(msgIndex);
                    } else {
                      _expandedSourceIndexes.add(msgIndex);
                    }
                  });
                },
                child: Row(
                  children: [
                    const Icon(Icons.menu_book_rounded,
                        size: 14, color: AppColors.signal),
                    const SizedBox(width: 6),
                    Text(
                      '${msg.sources.length} Verified Course Material Reference${msg.sources.length > 1 ? 's' : ''}',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.signal),
                    ),
                    const Spacer(),
                    Icon(
                      isExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 16,
                      color: AppColors.signal,
                    ),
                  ],
                ),
              ),
              if (isExpanded) ...[
                const SizedBox(height: 8),
                ...msg.sources.map((src) {
                  final filename = src['source']?.toString() ?? 'Document';
                  final chunkId = src['chunk_id'];
                  final score = src['score'];
                  final snippet = src['text']?.toString() ?? '';

                  return Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.bgPage,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.insert_drive_file_outlined,
                                size: 14, color: AppColors.textMuted),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '$filename ${chunkId != null ? '(Chunk #$chunkId)' : ''}',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.inkPrimary),
                              ),
                            ),
                            if (score != null)
                              ProfBadge(
                                label:
                                    '${((score as num) * 100).toStringAsFixed(0)}% match',
                                color: AppColors.primaryIndigo,
                              ),
                          ],
                        ),
                        if (snippet.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            snippet,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontStyle: FontStyle.italic),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// ── Materials Tab (Lecture Slides, Notes & RAG Knowledge) ─────────────
class _MaterialsTab extends ConsumerStatefulWidget {
  final int courseId;
  final bool isProf;

  const _MaterialsTab({required this.courseId, required this.isProf});

  @override
  ConsumerState<_MaterialsTab> createState() => _MaterialsTabState();
}

class _MaterialsTabState extends ConsumerState<_MaterialsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final courseId = widget.courseId;
    final isProf = widget.isProf;
    final materialsAsync = ref.watch(courseMaterialsProvider(courseId));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Course Lecture Materials',
                    style: GoogleFonts.dmSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Course lecture materials indexed for AI teaching assistant.',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: AppColors.inkSecondary,
                    ),
                  ),
                ],
              ),
              if (isProf)
                SecondaryButton(
                  label: '+ Upload Lecture File',
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pdf', 'pptx', 'docx', 'txt', 'md'],
                      withData: true,
                    );
                    final file = result?.files.single;
                    if (file == null || file.bytes == null) return;
                    try {
                      await CourseRepository().ingestCourseMaterial(
                        courseId,
                        file.bytes!.toList(),
                        file.name,
                      );
                      ref.invalidate(courseMaterialsProvider(courseId));
                      if (context.mounted) {
                        JournalToastManager.show(
                          context,
                          'Material uploaded and queued for AI indexing',
                          secondary: file.name,
                          status: ToastStatus.pass,
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        JournalToastManager.show(
                          context,
                          'Upload failed',
                          secondary: ErrorParser.parse(e),
                          status: ToastStatus.critical,
                        );
                      }
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: AppColors.rule, height: 1),
          const SizedBox(height: 16),

          materialsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Loading course materials…',
                    style: TextStyle(color: AppColors.inkGhost)),
              ),
            ),
            error: (e, _) => Center(
              child: Text(ErrorParser.parse(e),
                  style: const TextStyle(color: AppColors.statusCriticalInk)),
            ),
            data: (materials) {
              if (materials.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(40),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Text(
                        'No lecture materials uploaded yet.',
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          color: AppColors.inkSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isProf
                            ? 'Upload lecture PDFs or slides so students can review them and Course AI can answer from them.'
                            : 'Your instructor has not uploaded lecture documents yet.',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: AppColors.inkGhost,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: materials.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: AppColors.rule, height: 1),
                itemBuilder: (ctx, i) {
                  final mat = materials[i];
                  final filename = mat['filename']?.toString() ?? 'Document';
                  final fileType = mat['file_type']?.toString() ?? 'DOC';
                  final sizeBytes = mat['size_bytes'] as int? ?? 0;
                  final sizeMb = (sizeBytes / (1024 * 1024)).toStringAsFixed(1);
                  final chunksCount = mat['chunks_count'] as int? ?? 0;
                  final status = mat['status']?.toString() ?? 'indexed';

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      children: [
                        StampBadge(
                          label: fileType,
                          type: StampType.neutral,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                filename,
                                style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.inkPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    '$sizeMb MB',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 12,
                                      color: AppColors.inkGhost,
                                    ),
                                  ),
                                  if (chunksCount > 0) ...[
                                    const Text('  ·  ',
                                        style: TextStyle(color: AppColors.inkGhost)),
                                    Text(
                                      '$chunksCount AI Knowledge Chunks',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 12,
                                        color: AppColors.inkSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        StampBadge(
                          label: status == 'indexed' ? 'Indexed' : 'Indexing…',
                          type: status == 'indexed'
                              ? StampType.pass
                              : StampType.pending,
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
