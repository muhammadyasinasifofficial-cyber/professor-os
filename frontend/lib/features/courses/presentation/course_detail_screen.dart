import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/prof_badge.dart';
import '../../../shared/widgets/prof_card.dart';
import '../../../shared/widgets/prof_shimmer.dart';
import '../../../shared/widgets/prof_empty_state.dart';
import '../../../shared/widgets/hec_weightage_widget.dart';
import '../../../shared/widgets/prof_confirm_sheet.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/error_parser.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/course_repository.dart';
import '../providers/course_providers.dart';

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
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _uploadCourseMaterial() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'pptx', 'docx', 'txt', 'md'],
      withData: true,
    );
    final file = result?.files.single;
    if (file == null || file.bytes == null) return;
    if (file.size > 25 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Material exceeds the 25 MB limit.'),
          backgroundColor: AppColors.dangerRose,
        ));
      }
      return;
    }
    try {
      final response = await CourseRepository().ingestCourseMaterial(
        widget.courseId,
        file.bytes!.toList(),
        file.name,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(response['message']?.toString() ??
              'Material queued for AI indexing.'),
          backgroundColor: AppColors.successGreen,
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

  Future<void> _openAIQuizAndOBE() async {
    final uri = Uri.parse('/static_assets/react/index.html?courseId=${widget.courseId}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Unable to launch AI Quiz & OBE portal.'),
            backgroundColor: AppColors.dangerRose,
          ));
        }
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

  Future<void> _showCourseChat() async {
    final controller = TextEditingController();
    var loading = false;
    var answer = '';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Ask Course AI'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: controller,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Question',
                    hintText: 'Ask about the uploaded course material...',
                  ),
                ),
                if (answer.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: AppColors.bgPage,
                    child: Text(answer),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      final message = controller.text.trim();
                      if (message.isEmpty) return;
                      setState(() => loading = true);
                      try {
                        final response = await CourseRepository()
                            .chatWithCourse(widget.courseId, message);
                        setState(() {
                          answer = response['response']?.toString() ??
                              'No answer returned.';
                          loading = false;
                        });
                      } catch (e) {
                        setState(() {
                          answer = ErrorParser.parse(e);
                          loading = false;
                        });
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Ask'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
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
                      style: GoogleFonts.fraunces(
                          fontWeight: FontWeight.w600,
                          fontSize: 24,
                          color: AppColors.inkPrimary))),
            ],
          ),
          loading: () => const ProfShimmer(width: 120, height: 20),
          error: (_, __) => const Text('Course Details'),
        ),
        actions: [
          IconButton(
            tooltip: 'Ask Course AI',
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            onPressed: _showCourseChat,
          ),
          if (isProf) ...[
            IconButton(
              tooltip: 'Upload course material',
              icon: const Icon(Icons.upload_file_rounded),
              onPressed: _uploadCourseMaterial,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: isNarrow
                    ? const SizedBox.shrink()
                    : const Text('AI Quiz & OBE'),
                onPressed: _openAIQuizAndOBE,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.signal,
                  foregroundColor: Colors.white,
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
                  foregroundColor: AppColors.inkPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  side: const BorderSide(color: AppColors.marginRule),
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
        bottom: isProf
            ? TabBar(
                controller: _tabCtrl,
                isScrollable: true,
                labelColor: AppColors.inkPrimary,
                unselectedLabelColor: AppColors.inkSecondary,
                indicatorSize: TabBarIndicatorSize.label,
                indicator: const UnderlineTabIndicator(
                  borderSide: BorderSide(color: AppColors.signal, width: 2),
                ),
                labelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, fontSize: 14),
                unselectedLabelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w500, fontSize: 14),
                tabs: const [
                  Tab(text: 'Assignments'),
                  Tab(text: 'Students Roster'),
                  Tab(text: 'Course Settings'),
                ],
              )
            : null,
      ),
      body: courseAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text(ErrorParser.parse(e),
                style: const TextStyle(color: AppColors.dangerRose))),
        data: (course) => isProf
            ? TabBarView(
                controller: _tabCtrl,
                children: [
                  _AssignmentsTab(courseId: widget.courseId, isProf: isProf),
                  _StudentsTab(courseId: widget.courseId, isProf: isProf),
                  _SettingsTab(course: course),
                ],
              )
            : _AssignmentsTab(courseId: widget.courseId, isProf: false),
      ),
      floatingActionButton: isProf
          ? FloatingActionButton.extended(
              onPressed: () =>
                  context.go('/courses/${widget.courseId}/assignments/new'),
              backgroundColor: AppColors.signal,
              elevation: 0,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text('New Assignment',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600, color: Colors.white)),
            )
          : null,
    );
  }
}

class _AssignmentsTab extends ConsumerWidget {
  final int courseId;
  final bool isProf;
  const _AssignmentsTab({required this.courseId, required this.isProf});

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

  Future<void> _showAssignTADialog(BuildContext context, WidgetRef ref,
      int assignmentId, String title) async {
    try {
      final repo = CourseRepository();
      final roster = await repo.listEnrollments(courseId);
      final tas = roster
          .where((e) => (e['role'] ?? '').toString().toLowerCase() == 'ta')
          .toList();
      final assigned = (await repo.listAssignmentTAs(courseId, assignmentId))
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
        await repo.assignTA(courseId, assignmentId, id);
      }
      for (final id in current.difference(selected)) {
        await repo.removeTA(courseId, assignmentId, id);
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
  Widget build(BuildContext context, WidgetRef ref) {
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
                          onPressed: () => _showAssignTADialog(context, ref,
                              a['id'] as int, a['title'] as String),
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

class _StudentsTabState extends ConsumerState<_StudentsTab> {
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
              ? '$created students enrolled successfully.'
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
