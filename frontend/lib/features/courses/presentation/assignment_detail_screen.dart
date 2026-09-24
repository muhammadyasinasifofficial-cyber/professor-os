/// ProfessorOS – Assignment Detail Screen.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_parser.dart';
import '../../../shared/journal_ui/journal_components.dart';
import '../../../shared/widgets/prof_badge.dart';
import '../../../shared/widgets/prof_card.dart';
import '../../../shared/widgets/prof_shimmer.dart';
import '../../../shared/widgets/prof_stat_card.dart';
import '../../../shared/widgets/marginalia_strip.dart';
import '../data/course_repository.dart';
import '../../auth/providers/auth_provider.dart';
import 'exam_screen.dart';
import '../utils/mcq_parser.dart';

final rubricProvider =
    FutureProvider.family<Map<String, dynamic>?, int>((ref, aid) async {
  return await CourseRepository().getRubric(aid);
});

class AssignmentDetailScreen extends ConsumerStatefulWidget {
  final int courseId;
  final int assignmentId;
  const AssignmentDetailScreen(
      {super.key, required this.courseId, required this.assignmentId});

  @override
  ConsumerState<AssignmentDetailScreen> createState() =>
      _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState
    extends ConsumerState<AssignmentDetailScreen> {
  Map<String, dynamic>? _assignment;
  bool _loading = true;
  String? _error;

  // ── Submission state ──────────────────────────────────
  // For student view: their own submission (null = not submitted)
  Map<String, dynamic>? _mySubmission;
  bool _submissionLoading = false;

  // For prof/TA view: full list of all submissions
  List<Map<String, dynamic>> _submissions = [];
  bool _submissionsLoading = false;
  int _pendingCount = 0;
  int _gradedCount = 0;
  bool _batchGrading = false;
  final Set<int> _gradingSubmissionIds = {};

  // Submission form state
  String? _selectedFileName;
  List<int>? _selectedFileBytes;
  final _textSubmissionCtrl = TextEditingController();
  final _codeSubmissionCtrl = TextEditingController();
  int? _mcqSelectedValue;

  Future<void> _runBatchAiGrading() async {
    final pending = _submissions.where((s) => s['status'] == 'pending').length;
    if (pending == 0) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.auto_awesome, color: AppColors.signal),
            SizedBox(width: 8),
            Text('Batch AI Grading'),
          ],
        ),
        content: Text(
          'DeepSeek-R1 will evaluate all $pending pending submissions against the course rubric and compute grades with diagnostic feedback.\n\nProceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.signal),
            icon: const Icon(Icons.bolt, size: 16),
            label: const Text('Start AI Batch'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _batchGrading = true);
    try {
      final res = await CourseRepository()
          .batchAiGrade(widget.courseId, widget.assignmentId);
      final count = res['graded_count'] ?? 0;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('✓ Successfully AI-graded $count submissions against rubric.'),
          backgroundColor: AppColors.successGreen,
        ));
        await _loadSubmissions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Batch AI grading failed: ${ErrorParser.parse(e)}'),
          backgroundColor: AppColors.dangerRose,
        ));
      }
    } finally {
      if (mounted) setState(() => _batchGrading = false);
    }
  }

  Future<void> _aiGradeSingleSubmission(Map<String, dynamic> sub) async {
    final sid = sub['id'] as int;
    setState(() => _gradingSubmissionIds.add(sid));
    try {
      final result =
          await CourseRepository().aiGradeSubmission(sid, sync: true);
      if (!mounted) return;
      final score = result['score'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '✓ AI grading complete for ${sub['student_name']}: $score pts awarded.'),
          backgroundColor: AppColors.successGreen,
        ),
      );
      await _loadSubmissions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI grading error: ${ErrorParser.parse(e)}'),
          backgroundColor: AppColors.dangerRose,
        ),
      );
    } finally {
      if (mounted) setState(() => _gradingSubmissionIds.remove(sid));
    }
  }

  void _openGradingDialog(Map<String, dynamic> sub) {
    final scoreCtrl =
        TextEditingController(text: sub['score']?.toString() ?? '');
    final feedbackCtrl = TextEditingController(text: sub['feedback'] ?? '');
    final formKey = GlobalKey<FormState>();
    bool saving = false;
    bool aiGrading = false;
    String? aiStatusMessage;
    Map<String, dynamic>? aiEvaluation;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Expanded(
                child: Text('Grade: ${sub['student_name'] ?? 'Student'}',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
              ),
              ProfBadge(
                label: sub['status'] == 'graded' ? 'Graded' : 'Pending',
                color: sub['status'] == 'graded'
                    ? AppColors.successGreen
                    : AppColors.pending,
              ),
            ],
          ),
          content: SizedBox(
            width: 600,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Submitted Work:',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColors.textMuted)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.bgPage,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: sub['submission_type'] == 'programming'
                          ? Text(
                              sub['content'] ?? '',
                              style: GoogleFonts.jetBrainsMono(
                                  fontSize: 12, color: AppColors.inkPrimary),
                            )
                          : sub['submission_type'] == 'file'
                              ? Row(
                                  children: [
                                    const Icon(Icons.insert_drive_file,
                                        color: AppColors.signal, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                          sub['file_name'] ??
                                              sub['content'] ??
                                              'Uploaded file',
                                          style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                  ],
                                )
                              : Text(
                                  sub['content'] ?? '',
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                      height: 1.4),
                                ),
                    ),
                    const SizedBox(height: 16),
                    // AI Evaluation Action Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryIndigo.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.primaryIndigo.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.auto_awesome,
                                  color: AppColors.signal, size: 18),
                              const SizedBox(width: 8),
                              Text('AI Rubric Evaluation',
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: AppColors.inkPrimary)),
                              const Spacer(),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.signal,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                ),
                                icon: aiGrading
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                    : const Icon(Icons.bolt, size: 15),
                                label: Text(aiGrading
                                    ? 'Grading...'
                                    : 'Auto-Grade with AI'),
                                onPressed: (saving || aiGrading)
                                    ? null
                                    : () async {
                                        setDialogState(() {
                                          aiGrading = true;
                                          aiStatusMessage =
                                              'Analyzing submission with DeepSeek-R1 against rubric...';
                                        });
                                        try {
                                          final res = await CourseRepository()
                                              .aiGradeSubmission(
                                                  sub['id'] as int,
                                                  sync: true);
                                          final score =
                                              (res['score'] as num?)?.toDouble();
                                          final feedback =
                                              res['feedback']?.toString() ??
                                                  res['diagnostic_reasoning']
                                                      ?.toString();
                                          setDialogState(() {
                                            if (score != null) {
                                              scoreCtrl.text =
                                                  score.toStringAsFixed(1);
                                            }
                                            if (feedback != null &&
                                                feedback.isNotEmpty) {
                                              feedbackCtrl.text = feedback;
                                            }
                                            aiEvaluation = res;
                                            aiGrading = false;
                                            aiStatusMessage =
                                                '✓ AI evaluated: ${res['percentage']?.toStringAsFixed(1) ?? score}% score awarded.';
                                          });
                                        } catch (e) {
                                          setDialogState(() {
                                            aiGrading = false;
                                            aiStatusMessage =
                                                'AI grading failed: ${ErrorParser.parse(e)}';
                                          });
                                        }
                                      },
                              ),
                            ],
                          ),
                          if (aiStatusMessage != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              aiStatusMessage!,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: aiStatusMessage!.startsWith('✓')
                                    ? AppColors.successGreen
                                    : aiStatusMessage!.contains('failed')
                                        ? AppColors.dangerRose
                                        : AppColors.signal,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          if (aiEvaluation != null &&
                              aiEvaluation!['criteria'] is List) ...[
                            const SizedBox(height: 10),
                            const Divider(height: 1),
                            const SizedBox(height: 8),
                            Text('Rubric Criteria Breakdown:',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            ...((aiEvaluation!['criteria'] as List)
                                .map((crit) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 6),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.check_circle_outline,
                                              size: 14,
                                              color: AppColors.successGreen),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              '${crit['criterion_name']}: ${crit['score_awarded']}/${crit['max_score']} pts - ${crit['rationale'] ?? ''}',
                                              style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  color:
                                                      AppColors.textSecondary),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ))),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: scoreCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        labelText:
                            'Score / Points (max ${_assignment?['max_marks']?.toStringAsFixed(0) ?? '100'})',
                        hintText: 'e.g. 85.5',
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Score is required';
                        final val = double.tryParse(v);
                        final max =
                            (_assignment?['max_marks'] as num?)?.toDouble() ??
                                100.0;
                        if (val == null || val < 0 || val > max) {
                          return 'Must be between 0 and $max';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: feedbackCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Qualitative Feedback',
                        hintText: 'Enter student-facing qualitative feedback...',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => saving = true);
                      try {
                        final sid = sub['id'] as int;
                        final score = double.parse(scoreCtrl.text);
                        final feedback = feedbackCtrl.text.trim().isEmpty
                            ? null
                            : feedbackCtrl.text.trim();
                        await CourseRepository()
                            .gradeSubmission(sid, score, feedback);
                        if (mounted) {
                          Navigator.pop(ctx);
                          await _loadSubmissions();
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                            content:
                                Text('✓ Grade and feedback saved successfully.'),
                            backgroundColor: AppColors.successGreen,
                          ));
                        }
                      } catch (e) {
                        setDialogState(() => saving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(ErrorParser.parse(e)),
                            backgroundColor: AppColors.dangerRose,
                          ));
                        }
                      }
                    },
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.signal),
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save Grade'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _assignment = await CourseRepository()
          .getAssignment(widget.courseId, widget.assignmentId);
      // Load submissions in parallel after assignment loads
      await _loadSubmissions();
    } catch (e) {
      _error = ErrorParser.parse(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSubmissions() async {
    final role =
        ref.read(authProvider).valueOrNull?['role'] as String? ?? 'student';
    final isProf = role == 'professor' || role == 'admin' || role == 'ta';
    try {
      if (isProf) {
        setState(() => _submissionsLoading = true);
        final res = await CourseRepository()
            .listSubmissions(widget.courseId, widget.assignmentId);
        if (mounted) {
          setState(() {
            _submissions = (res['submissions'] as List<dynamic>)
                .cast<Map<String, dynamic>>();
            _pendingCount = res['pending_count'] as int? ?? 0;
            _gradedCount = res['graded_count'] as int? ?? 0;
            _submissionsLoading = false;
          });
        }
      } else {
        // Student: fetch own submission
        setState(() => _submissionLoading = true);
        final mySub = await CourseRepository()
            .getMySubmission(widget.courseId, widget.assignmentId);
        if (mounted)
          setState(() {
            _mySubmission = mySub;
            _submissionLoading = false;
          });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _submissionsLoading = false;
          _submissionLoading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null)
      return Scaffold(appBar: AppBar(), body: Center(child: Text(_error!)));
    if (_assignment == null) return const SizedBox.shrink();

    final a = _assignment!;
    final isProf =
        ref.watch(authProvider).valueOrNull?['role'] == 'professor' ||
            ref.watch(authProvider).valueOrNull?['role'] == 'admin';

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: Text(a['title'],
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        actions: [
          if (isProf && a['status'] == 'draft')
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    await CourseRepository().publishAssignment(
                        widget.courseId, widget.assignmentId);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Assignment published successfully!'),
                        backgroundColor: AppColors.successGreen,
                      ));
                      _load();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Publishing failed: ${e.toString()}'),
                        backgroundColor: AppColors.dangerRose,
                      ));
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.successGreen,
                    foregroundColor: Colors.white),
                child: const Text('Publish'),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Meta Row
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ProfBadge(
                    label: a['type'].toString().toUpperCase(),
                    color: AppColors.inkPrimary),
                ProfBadge(
                    label: a['status'].toString().toUpperCase(),
                    color: a['status'] == 'published'
                        ? AppColors.successGreen
                        : AppColors.accentAmber),
                Text('Max Marks: ${a['max_marks']}',
                    style: GoogleFonts.inter(
                        fontSize: 14, color: AppColors.textSecondary)),
                if (a['clo_ids'] != null &&
                    (a['clo_ids'] as List).isNotEmpty) ...[
                  ProfBadge(
                      label: 'CLOs: ${(a['clo_ids'] as List).join(", ")}',
                      color: AppColors.primaryIndigo),
                ],
              ],
            ),
            const SizedBox(height: 24),
            // Stats Row
            if (isProf) ...[
              Builder(
                builder: (context) {
                  final totalCount = _submissions.length;
                  final pendingCount = _submissions
                      .where((s) => s['status'] == 'pending')
                      .length;
                  final gradedCount =
                      _submissions.where((s) => s['status'] == 'graded').length;
                  final gradedScores = _submissions
                      .where(
                          (s) => s['status'] == 'graded' && s['score'] != null)
                      .map((s) => s['score'] as double)
                      .toList();
                  final avgScoreStr = gradedScores.isNotEmpty
                      ? '${(gradedScores.reduce((a, b) => a + b) / gradedScores.length).toStringAsFixed(1)}%'
                      : '0.0%';

                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                          width: 200,
                          child: ProfStatCard(
                              value: '$totalCount/180', label: 'Submissions')),
                      SizedBox(
                          width: 200,
                          child: ProfStatCard(
                              value: '$pendingCount', label: 'Pending Review')),
                      SizedBox(
                          width: 200,
                          child: ProfStatCard(
                              value: '$gradedCount', label: 'Graded')),
                      SizedBox(
                          width: 200,
                          child: ProfStatCard(
                              value: avgScoreStr, label: 'Average Score')),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
            ],

            // Submissions & Rubric (Side by Side on desktop)
            LayoutBuilder(
              builder: (ctx, constraints) {
                final studentEmail =
                    ref.watch(authProvider).valueOrNull?['email'] ?? '';
                final submissionWidget = isProf
                    ? _buildSubmissionsList()
                    : _buildStudentSubmissionView(studentEmail);

                if (constraints.maxWidth > 800) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: submissionWidget),
                      const SizedBox(width: 24),
                      Expanded(flex: 2, child: _buildRubric(a['has_rubric'])),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRubric(a['has_rubric']),
                    const SizedBox(height: 24),
                    submissionWidget,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRubric(bool hasRubric) {
    if (!hasRubric) {
      return ProfCard(child: const Text('No rubric defined.'));
    }
    final rubricAsync = ref.watch(rubricProvider(widget.assignmentId));
    return ProfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rubric Summary',
              style: GoogleFonts.outfit(
                  fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          rubricAsync.when(
            loading: () => ProfShimmer.lines(count: 3),
            error: (e, _) => Text(ErrorParser.parse(e)),
            data: (r) {
              if (r == null) return const Text('No rubric found.');
              final criteria = r['criteria'] as List<dynamic>;
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: criteria.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final c = criteria[i];
                  return ExpansionTile(
                    title: Row(
                      children: [
                        Expanded(
                            child: Text(c['name'],
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600))),
                        ProfBadge(
                            label: '${c['weight']}%',
                            color: AppColors.inkPrimary),
                      ],
                    ),
                    childrenPadding: const EdgeInsets.all(16),
                    children: [
                      ...((c['levels'] as List<dynamic>).map((l) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                    width: 80,
                                    child: Text(
                                        l['level'].toString().toUpperCase(),
                                        style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600))),
                                Expanded(
                                    child: Text(l['description'] ?? '',
                                        style: GoogleFonts.inter(
                                            fontSize: 13,
                                            color: AppColors.textSecondary))),
                              ],
                            ),
                          ))),
                    ],
                  );
                },
              );
            },
          )
        ],
      ),
    );
  }

  Widget _buildSubmissionsList() {
    final pendingCount =
        _submissions.where((s) => s['status'] == 'pending').length;
    return ProfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Submissions (${_submissions.length})',
                  style: GoogleFonts.outfit(
                      fontSize: 20, fontWeight: FontWeight.w600)),
              if (pendingCount > 0)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.signal,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  icon: _batchGrading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.auto_awesome, size: 16),
                  label: Text(_batchGrading
                      ? 'AI Batch Grading...'
                      : 'Batch AI Grade ($pendingCount Pending)'),
                  onPressed: _batchGrading ? null : _runBatchAiGrading,
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_submissions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No submissions yet for this assignment.',
                  style: GoogleFonts.inter(color: AppColors.textMuted),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _submissions.length,
              itemBuilder: (context, index) {
                final sub = _submissions[index];
                final isGraded = sub['status'] == 'graded';
                final sid = sub['id'] as int;
                final isAiGrading = _gradingSubmissionIds.contains(sid);

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => SpeedGraderScreen(
                          submissions: _submissions,
                          initialIndex: index,
                          assignmentId: widget.assignmentId,
                          onSave: (idx, updatedSub) {
                            setState(() {
                              _submissions[idx] = updatedSub;
                            });
                          },
                        ),
                      ));
                    },
                    child: IntrinsicHeight(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            top: index == 0
                                ? const BorderSide(
                                    color: AppColors.marginRule, width: 1)
                                : BorderSide.none,
                            bottom: const BorderSide(
                                color: AppColors.marginRule, width: 1),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16, horizontal: 16),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: AppColors.bgSurface,
                                      child: Text(
                                        (sub['student_name'] ?? 'S')
                                            .toString()
                                            .split(' ')
                                            .map((n) =>
                                                n.isNotEmpty ? n[0] : '')
                                            .join(),
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.inkPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                              sub['student_name'] ??
                                                  'Student',
                                              style: GoogleFonts.inter(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.inkPrimary)),
                                          Text(sub['student_email'] ?? '',
                                              style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color:
                                                      AppColors.inkSecondary)),
                                        ],
                                      ),
                                    ),
                                    Text(sub['submitted_at'] ?? '',
                                        style: GoogleFonts.jetBrainsMono(
                                            fontSize: 12,
                                            color: AppColors.inkSecondary)),
                                    const SizedBox(width: 8),
                                    // Manual Grade Dialog Trigger
                                    IconButton(
                                      tooltip: 'Review & Grade with Rubric',
                                      icon: const Icon(
                                          Icons.rate_review_outlined,
                                          color: AppColors.inkPrimary,
                                          size: 20),
                                      onPressed: () =>
                                          _openGradingDialog(sub),
                                    ),
                                    // AI Auto-Grade Button
                                    IconButton(
                                      tooltip:
                                          'Auto-grade with AI (DeepSeek-R1)',
                                      icon: isAiGrading
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child:
                                                  CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: AppColors.signal))
                                          : const Icon(Icons.auto_awesome,
                                              color: AppColors.signal,
                                              size: 20),
                                      onPressed: isAiGrading
                                          ? null
                                          : () =>
                                              _aiGradeSingleSubmission(sub),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            MarginaliaStrip(
                              statusLabel: isGraded ? 'Graded' : 'Pending',
                              statusColor: isGraded
                                  ? AppColors.feedbackRed
                                  : AppColors.pending,
                              score: sub['score'] != null
                                  ? '${sub['score']}'
                                  : '--',
                              grader: isGraded ? 'System' : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStudentSubmissionView(String studentEmail) {
    final sub = _mySubmission ?? <String, dynamic>{};

    final hasSubmitted = sub.isNotEmpty;
    final isGraded = hasSubmitted && sub['status'] == 'graded';
    final assignmentType =
        _assignment?['type']?.toString().toLowerCase() ?? 'text';
    final timeLimitMinutes = _assignment?['time_limit_minutes'] as int?;
    final isQuizOrExam = assignmentType == 'quiz' ||
        assignmentType == 'exam' ||
        (timeLimitMinutes != null && timeLimitMinutes > 0);

    if (!hasSubmitted && isQuizOrExam) {
      final isQuiz = assignmentType == 'quiz';
      return ProfCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isQuiz ? 'Quiz Assessment' : 'Timed Examination',
                style: GoogleFonts.dmSans(
                    fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.inkPrimary)),
            const SizedBox(height: 8),
            Text(
              isQuiz
                  ? 'This is an academic quiz assessment with structured questions. Click below to begin your attempt.'
                  : 'This is a timed examination (${timeLimitMinutes ?? 60} minutes). Once you start, the assessment begins and fullscreen focus mode is active.',
              style: GoogleFonts.dmSans(
                  color: AppColors.inkSecondary, height: 1.5),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: isQuiz ? 'Start Quiz Assessment' : 'Start Exam (${timeLimitMinutes ?? 60} min)',
              onPressed: () {
                Navigator.of(context)
                    .push(MaterialPageRoute(
                      builder: (_) => ExamScreen(
                        courseId: widget.courseId,
                        assignmentId: widget.assignmentId,
                        assignmentTitle: _assignment!['title'] ?? 'Assessment',
                        assignmentType: isQuiz ? 'mcq' : (_assignment!['type'] ?? 'text'),
                        description: _assignment!['description'],
                        maxMarks:
                            (_assignment!['max_marks'] as num?)?.toDouble() ??
                                100.0,
                        timeLimitMinutes: timeLimitMinutes ?? (isQuiz ? 30 : 60),
                        randomizeQuestions:
                            _assignment!['randomize_questions'] as bool? ??
                                false,
                        showResultsAfter:
                            _assignment!['show_results_after'] as bool? ?? true,
                      ),
                    ))
                    .then((_) => _loadSubmissions());
              },
            ),
          ],
        ),
      );
    }

    return ProfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('My Submission',
              style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          if (hasSubmitted) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgPage,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Wrap(
                        spacing: 8,
                        children: [
                          ProfBadge(
                            label: isGraded ? 'Graded' : 'Submitted (Latest)',
                            color: isGraded
                                ? AppColors.successGreen
                                : AppColors.accentAmber,
                          ),
                          if (sub['score'] != null)
                            ProfBadge(
                              label: '${sub['score']} pts',
                              color: AppColors.primaryIndigo,
                            ),
                        ],
                      ),
                      Text(
                        'Submitted ${sub['submitted_at']}',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Submitted Content:',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.textMuted)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: sub['submission_type'] == 'file'
                        ? Row(
                            children: [
                              const Icon(Icons.insert_drive_file,
                                  color: AppColors.primaryIndigo, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(sub['content'] ?? '',
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary)),
                              ),
                            ],
                          )
                        : sub['submission_type'] == 'programming'
                            ? Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  sub['content'] ?? '',
                                  style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                      color: Colors.black87),
                                ),
                              )
                            : Text(
                                sub['content'] ?? '',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    height: 1.4),
                              ),
                  ),
                  if (isGraded &&
                      sub['feedback'] != null &&
                      sub['feedback'].toString().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    Text(
                      'Instructor Feedback',
                      style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryIndigo.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        sub['feedback'],
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            height: 1.5,
                            fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _mySubmission = null;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'Re-opened submission form. Upload your updated work below.'),
                      ));
                    },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Resubmit Assignment'),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.bgPage,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (assignmentType == 'file') ...[
                    Text('Upload PDF/ZIP Submission File',
                        style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: [
                            'pdf',
                            'zip',
                            'docx',
                            'doc',
                            'txt',
                            'png',
                            'jpg',
                            'jpeg'
                          ],
                          withData: true,
                        );
                        if (result != null &&
                            result.files.single.bytes != null) {
                          final file = result.files.single;
                          const maxBytes = 25 * 1024 * 1024; // 25 MB
                          if (file.size > maxBytes) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'File too large. Maximum allowed size is 25 MB.'),
                                  backgroundColor: Colors.red),
                            );
                            return;
                          }
                          setState(() {
                            _selectedFileName = file.name;
                            _selectedFileBytes = file.bytes!.toList();
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 24, horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.primaryIndigo.withOpacity(0.3),
                              style: BorderStyle.solid),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.cloud_upload_outlined,
                                size: 36, color: AppColors.primaryIndigo),
                            const SizedBox(height: 8),
                            Text(
                              _selectedFileName ?? 'Click to choose file...',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: _selectedFileName != null
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: _selectedFileName != null
                                    ? AppColors.textPrimary
                                    : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: (_selectedFileName == null ||
                              _selectedFileBytes == null ||
                              _submissionLoading)
                          ? null
                          : () async {
                              setState(() => _submissionLoading = true);
                              try {
                                await CourseRepository().submitFile(
                                  widget.courseId,
                                  widget.assignmentId,
                                  _selectedFileBytes!,
                                  _selectedFileName!,
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(
                                    content:
                                        Text('File submitted successfully!'),
                                    backgroundColor: Colors.green,
                                  ));
                                  setState(() {
                                    _selectedFileName = null;
                                    _selectedFileBytes = null;
                                  });
                                  await _loadSubmissions();
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: Text(ErrorParser.parse(e)),
                                    backgroundColor: Colors.red,
                                  ));
                                }
                              } finally {
                                if (mounted)
                                  setState(() => _submissionLoading = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryIndigo,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Submit Assignment'),
                    ),
                  ] else if (assignmentType == 'programming') ...[
                    Text('Paste Source Code Submission',
                        style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _codeSubmissionCtrl,
                      maxLines: 8,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'e.g. def my_solution():\n    return True',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _submissionLoading
                          ? null
                          : () async {
                              final code = _codeSubmissionCtrl.text.trim();
                              if (code.isEmpty) return;
                              setState(() => _submissionLoading = true);
                              try {
                                await CourseRepository().submitAssignment(
                                  widget.courseId,
                                  widget.assignmentId,
                                  {
                                    'submission_type': 'programming',
                                    'content': code
                                  },
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(
                                    content:
                                        Text('Code submitted successfully!'),
                                    backgroundColor: Colors.green,
                                  ));
                                  _codeSubmissionCtrl.clear();
                                  await _loadSubmissions();
                                }
                              } catch (e) {
                                if (mounted)
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: Text(ErrorParser.parse(e)),
                                    backgroundColor: Colors.red,
                                  ));
                              } finally {
                                if (mounted)
                                  setState(() => _submissionLoading = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryIndigo,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Submit Code'),
                    ),
                  ] else if (assignmentType == 'mcq') ...[
                    Builder(builder: (context) {
                      final questions = parseMcqDescription(
                          _assignment?['description']?.toString());
                      if (questions.isEmpty) {
                        return const Text(
                            'This quiz has no configured questions yet.');
                      }
                      final question = questions.first;
                      final options = (question['options'] as List?)
                              ?.map((option) => option.toString())
                              .toList() ??
                          const <String>[];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Complete Multiple Choice Quiz',
                              style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.bgSurface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Question: ${question['question']}',
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary)),
                                const SizedBox(height: 12),
                                ...List.generate(
                                    options.length,
                                    (index) => RadioListTile<int>(
                                          title: Text(options[index],
                                              style: const TextStyle(
                                                  fontSize: 13)),
                                          value: index + 1,
                                          groupValue: _mcqSelectedValue,
                                          contentPadding: EdgeInsets.zero,
                                          onChanged: (val) => setState(
                                              () => _mcqSelectedValue = val),
                                        )),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: (_mcqSelectedValue == null ||
                              _submissionLoading)
                          ? null
                          : () async {
                              setState(() => _submissionLoading = true);
                              final optionLetter = [
                                'A',
                                'B',
                                'C',
                                'D',
                                'E'
                              ][(_mcqSelectedValue! - 1).clamp(0, 4)];
                              final content = 'Option $optionLetter';
                              try {
                                await CourseRepository().submitAssignment(
                                  widget.courseId,
                                  widget.assignmentId,
                                  {
                                    'submission_type': 'mcq',
                                    'content': content
                                  },
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(
                                    content: Text('Quiz answer submitted!'),
                                    backgroundColor: Colors.green,
                                  ));
                                  setState(() => _mcqSelectedValue = null);
                                  await _loadSubmissions();
                                }
                              } catch (e) {
                                if (mounted)
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: Text(ErrorParser.parse(e)),
                                    backgroundColor: Colors.red,
                                  ));
                              } finally {
                                if (mounted)
                                  setState(() => _submissionLoading = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryIndigo,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Submit Quiz'),
                    ),
                  ] else ...[
                    Text('Write Q&A Response Submission',
                        style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _textSubmissionCtrl,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        hintText: 'Enter your written answer response here...',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _submissionLoading
                          ? null
                          : () async {
                              final text = _textSubmissionCtrl.text.trim();
                              if (text.isEmpty) return;
                              setState(() => _submissionLoading = true);
                              try {
                                await CourseRepository().submitAssignment(
                                  widget.courseId,
                                  widget.assignmentId,
                                  {'submission_type': 'text', 'content': text},
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(
                                    content:
                                        Text('Answer submitted successfully!'),
                                    backgroundColor: Colors.green,
                                  ));
                                  _textSubmissionCtrl.clear();
                                  await _loadSubmissions();
                                }
                              } catch (e) {
                                if (mounted)
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: Text(ErrorParser.parse(e)),
                                    backgroundColor: Colors.red,
                                  ));
                              } finally {
                                if (mounted)
                                  setState(() => _submissionLoading = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryIndigo,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Submit Answer'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SpeedGraderScreen extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> submissions;
  final int initialIndex;
  final int assignmentId;
  final Function(int index, Map<String, dynamic> updatedSub) onSave;

  const SpeedGraderScreen({
    super.key,
    required this.submissions,
    required this.initialIndex,
    required this.assignmentId,
    required this.onSave,
  });

  @override
  ConsumerState<SpeedGraderScreen> createState() => _SpeedGraderScreenState();
}

class _SpeedGraderScreenState extends ConsumerState<SpeedGraderScreen> {
  late int _currentIndex;
  final _scoreCtrl = TextEditingController();
  final _feedbackCtrl = TextEditingController();
  final Map<String, String> _selectedLevels = {}; // criteria_name -> level

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _loadSubmission();
  }

  void _loadSubmission() {
    final sub = widget.submissions[_currentIndex];
    _scoreCtrl.text = sub['score']?.toString() ?? '';
    _feedbackCtrl.text = sub['feedback'] ?? '';
    _selectedLevels.clear();
  }

  void _onSaveCurrent() {
    final score = double.tryParse(_scoreCtrl.text);
    final feedback = _feedbackCtrl.text;
    final updated =
        Map<String, dynamic>.from(widget.submissions[_currentIndex]);
    updated['score'] = score;
    updated['feedback'] = feedback;
    updated['status'] = 'graded';

    widget.onSave(_currentIndex, updated);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Grade and feedback saved successfully!'),
      backgroundColor: AppColors.successGreen,
    ));
  }

  bool _aiGrading = false;

  Future<void> _runAiGrade() async {
    final sub = widget.submissions[_currentIndex];
    setState(() => _aiGrading = true);
    try {
      final res = await CourseRepository()
          .aiGradeSubmission(sub['id'] as int, sync: true);
      final score = (res['score'] as num?)?.toDouble();
      final feedback = res['feedback']?.toString() ??
          res['diagnostic_reasoning']?.toString();
      setState(() {
        if (score != null) _scoreCtrl.text = score.toStringAsFixed(1);
        if (feedback != null && feedback.isNotEmpty) {
          _feedbackCtrl.text = feedback;
        }
        _aiGrading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '✓ AI evaluated: ${score?.toStringAsFixed(1) ?? ''} pts awarded.'),
          backgroundColor: AppColors.successGreen,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _aiGrading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('AI grading failed: ${ErrorParser.parse(e)}'),
          backgroundColor: AppColors.dangerRose,
        ));
      }
    }
  }

  Widget _buildCodeViewer(String code) {
    final lines = code.split('\n');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        itemCount: lines.length,
        itemBuilder: (context, i) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 8),
                  decoration: const BoxDecoration(
                    border: Border(right: BorderSide(color: AppColors.border)),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 11, color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(
                      lines[i],
                      style: GoogleFonts.jetBrainsMono(
                          fontSize: 12, color: AppColors.inkPrimary),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.submissions[_currentIndex];
    final rubricAsync = ref.watch(rubricProvider(widget.assignmentId));

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text('SpeedGrader',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w500, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Carousel Nav Header
          Container(
            decoration: const BoxDecoration(
              color: AppColors.bgSurface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  onPressed: _currentIndex > 0
                      ? () {
                          setState(() {
                            _currentIndex--;
                            _loadSubmission();
                          });
                        }
                      : null,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(sub['student_name'],
                          style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      Text(sub['student_email'],
                          style: GoogleFonts.inter(
                              fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded),
                  onPressed: _currentIndex < widget.submissions.length - 1
                      ? () {
                          setState(() {
                            _currentIndex++;
                            _loadSubmission();
                          });
                        }
                      : null,
                ),
              ],
            ),
          ),

          // Split Pane Body
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final useVertical = constraints.maxWidth < 900;

                final leftPane = SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Submitted Work Preview',
                          style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: sub['submission_type'] == 'file'
                            ? Column(
                                children: [
                                  const Icon(Icons.insert_drive_file,
                                      size: 64, color: AppColors.primaryIndigo),
                                  const SizedBox(height: 12),
                                  Text(sub['content'] ?? '',
                                      style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary)),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () {},
                                    icon: const Icon(Icons.download),
                                    label:
                                        const Text('Download Submission File'),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            AppColors.primaryIndigo),
                                  ),
                                ],
                              )
                            : sub['submission_type'] == 'programming'
                                ? _buildCodeViewer(sub['content'] ?? '')
                                : Text(
                                    sub['content'] ?? '',
                                    style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: AppColors.textSecondary,
                                        height: 1.5),
                                  ),
                      ),
                    ],
                  ),
                );

                final rightPane = SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Grade & Feedback Card',
                          style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 16),

                      // Clickable Rubric Evaluator
                      rubricAsync.when(
                        data: (r) {
                          if (r == null) return const SizedBox.shrink();
                          final criteria = r['criteria'] as List<dynamic>;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Rubric Grading Checklist',
                                  style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary)),
                              const SizedBox(height: 10),
                              ...criteria.map((c) {
                                final critName = c['name'] as String;
                                final weight = c['weight'] as int;
                                final levels = c['levels'] as List<dynamic>;
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('$critName ($weight%)',
                                            style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: levels.map((l) {
                                            final levelName =
                                                l['level'] as String;
                                            final isSelected =
                                                _selectedLevels[critName] ==
                                                    levelName;
                                            return ChoiceChip(
                                              label: Text(
                                                  levelName.toUpperCase(),
                                                  style: const TextStyle(
                                                      fontSize: 11)),
                                              selected: isSelected,
                                              onSelected: (selected) {
                                                setState(() {
                                                  _selectedLevels[critName] =
                                                      levelName;

                                                  // Auto calculate total score based on rubric clicks
                                                  double calculatedTotal = 0;
                                                  _selectedLevels
                                                      .forEach((key, val) {
                                                    final matchCrit = criteria
                                                        .firstWhere((element) =>
                                                            element['name'] ==
                                                            key);
                                                    final matchWeight =
                                                        matchCrit['weight']
                                                            as int;
                                                    double factor = 1.0;
                                                    if (val == 'good')
                                                      factor = 0.75;
                                                    if (val == 'poor')
                                                      factor = 0.40;
                                                    calculatedTotal +=
                                                        matchWeight * factor;
                                                  });
                                                  _scoreCtrl.text =
                                                      calculatedTotal
                                                          .toStringAsFixed(1);
                                                });
                                              },
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                              const Divider(),
                              const SizedBox(height: 12),
                            ],
                          );
                        },
                        loading: () => const CircularProgressIndicator(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),

                      TextField(
                        controller: _scoreCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Points / Score',
                          hintText: 'e.g. 85.5',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _feedbackCtrl,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Qualitative Feedback',
                          hintText: 'Great work! Solid structure...',
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _aiGrading ? null : _runAiGrade,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.signal,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 46),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _aiGrading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.auto_awesome, size: 16),
                        label: Text(_aiGrading
                            ? 'AI Evaluating with Rubric...'
                            : 'Auto-Grade with AI (DeepSeek-R1)'),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _onSaveCurrent,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.successGreen,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Save Grade & Comments'),
                      ),
                    ],
                  ),
                );

                if (useVertical) {
                  return ListView(
                    children: [
                      leftPane,
                      rightPane,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: leftPane),
                    const VerticalDivider(width: 1),
                    Expanded(flex: 2, child: rightPane),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
