import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_parser.dart';
import '../../../shared/journal_ui/journal_components.dart';
import '../data/course_repository.dart';

class AiQuizObeDialog extends ConsumerStatefulWidget {
  final int courseId;
  final String courseTitle;

  const AiQuizObeDialog({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  static Future<void> show(BuildContext context, int courseId, String courseTitle) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AiQuizObeDialog(
        courseId: courseId,
        courseTitle: courseTitle,
      ),
    );
  }

  @override
  ConsumerState<AiQuizObeDialog> createState() => _AiQuizObeDialogState();
}

class _AiQuizObeDialogState extends ConsumerState<AiQuizObeDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // Question Bank State
  List<Map<String, dynamic>> _questions = [];
  bool _loadingQuestions = true;
  String _selectedStatus = '';
  String _selectedBloom = '';
  final Set<String> _actionInProgress = {};

  // OBE Attainment State
  Map<String, dynamic>? _attainmentReport;
  bool _loadingAttainment = true;
  String _selectedSemester = 'Spring-2026';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadQuestions();
    _loadAttainment();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    setState(() => _loadingQuestions = true);
    try {
      final repo = CourseRepository();
      final res = await repo.getQuestionBank(
        widget.courseId,
        status: _selectedStatus.isNotEmpty ? _selectedStatus : null,
        bloomLevel: _selectedBloom.isNotEmpty ? _selectedBloom : null,
      );
      if (mounted) {
        setState(() {
          _questions = res;
          _loadingQuestions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingQuestions = false);
      }
    }
  }

  Future<void> _loadAttainment() async {
    setState(() => _loadingAttainment = true);
    try {
      final repo = CourseRepository();
      final res = await repo.getCloAttainment(
        widget.courseId,
        semester: _selectedSemester,
      );
      if (mounted) {
        setState(() {
          _attainmentReport = res;
          _loadingAttainment = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingAttainment = false);
      }
    }
  }

  Future<void> _approveQuestion(String qId) async {
    setState(() => _actionInProgress.add(qId));
    try {
      await CourseRepository().approveQuestion(qId);
      await _loadQuestions();
      if (mounted) {
        JournalToastManager.show(
          context,
          'Question approved & added to active pool',
          status: ToastStatus.pass,
        );
      }
    } catch (e) {
      if (mounted) {
        JournalToastManager.show(
          context,
          'Failed to approve question',
          secondary: ErrorParser.parse(e),
          status: ToastStatus.critical,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _actionInProgress.remove(qId));
      }
    }
  }

  Future<void> _rejectQuestion(String qId) async {
    setState(() => _actionInProgress.add(qId));
    try {
      await CourseRepository().rejectQuestion(qId);
      await _loadQuestions();
      if (mounted) {
        JournalToastManager.show(
          context,
          'Question archived',
          status: ToastStatus.pending,
        );
      }
    } catch (e) {
      if (mounted) {
        JournalToastManager.show(
          context,
          'Failed to archive question',
          secondary: ErrorParser.parse(e),
          status: ToastStatus.critical,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _actionInProgress.remove(qId));
      }
    }
  }

  Color _bloomColor(String level) {
    switch (level.toUpperCase()) {
      case 'C1':
        return Colors.blueGrey;
      case 'C2':
        return Colors.blue;
      case 'C3':
        return const Color(0xFF10B981); // Emerald
      case 'C4':
        return const Color(0xFFF59E0B); // Amber
      case 'C5':
        return const Color(0xFFF97316); // Orange
      case 'C6':
        return const Color(0xFFEF4444); // Rose
      default:
        return AppColors.inkSecondary;
    }
  }

  String _bloomTitle(String level) {
    switch (level.toUpperCase()) {
      case 'C1':
        return 'C1 · Remember';
      case 'C2':
        return 'C2 · Understand';
      case 'C3':
        return 'C3 · Apply';
      case 'C4':
        return 'C4 · Analyze';
      case 'C5':
        return 'C5 · Evaluate';
      case 'C6':
        return 'C6 · Create';
      default:
        return level;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isMobile = size.width < 700;

    return Dialog(
      backgroundColor: AppColors.canvas,
      insetPadding: isMobile
          ? const EdgeInsets.all(12)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.r8),
        side: const BorderSide(color: AppColors.ruleStrong, width: 1),
      ),
      child: Container(
        width: 1040,
        height: size.height * 0.9,
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.circular(AppRadius.r8),
        ),
        child: Column(
          children: [
            // ── Dialog Header ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.rule, width: 1)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMid,
                      borderRadius: BorderRadius.circular(AppRadius.r4),
                      border: Border.all(color: AppColors.ruleStrong),
                    ),
                    child: const Icon(Icons.auto_awesome,
                        size: 20, color: AppColors.signal),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'AI Assessment & OBE Suite',
                              style: GoogleFonts.fraunces(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: AppColors.inkPrimary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            StampBadge(
                              label: 'HEC Accreditation',
                              type: StampType.pass,
                            ),
                          ],
                        ),
                        Text(
                          widget.courseTitle,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: AppColors.inkSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.inkGhost),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // ── Tab Bar ──
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.rule, width: 1)),
                color: AppColors.surface,
              ),
              child: TabBar(
                controller: _tabCtrl,
                labelColor: AppColors.inkPrimary,
                unselectedLabelColor: AppColors.inkGhost,
                labelStyle: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w600, fontSize: 14),
                unselectedLabelStyle: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w400, fontSize: 14),
                indicatorColor: AppColors.inkPrimary,
                indicatorWeight: 2,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.psychology_outlined, size: 18),
                    text: 'AI Question Bank & Approval',
                  ),
                  Tab(
                    icon: Icon(Icons.insights_outlined, size: 18),
                    text: 'HEC CLO Attainment & OBE Dossier',
                  ),
                ],
              ),
            ),

            // ── Tab Content ──
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildQuestionBankView(),
                  _buildObeAttainmentView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 1. QUESTION BANK TAB
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildQuestionBankView() {
    return Column(
      children: [
        // Filter bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.rule, width: 1)),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Cognitive Filter:',
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 12, color: AppColors.inkGhost)),
              _filterChip('All Bloom', '', _selectedBloom, (val) {
                setState(() => _selectedBloom = val);
                _loadQuestions();
              }),
              _filterChip('C1 Remember', 'C1', _selectedBloom, (val) {
                setState(() => _selectedBloom = val);
                _loadQuestions();
              }),
              _filterChip('C2 Understand', 'C2', _selectedBloom, (val) {
                setState(() => _selectedBloom = val);
                _loadQuestions();
              }),
              _filterChip('C3 Apply', 'C3', _selectedBloom, (val) {
                setState(() => _selectedBloom = val);
                _loadQuestions();
              }),
              _filterChip('C4 Analyze', 'C4', _selectedBloom, (val) {
                setState(() => _selectedBloom = val);
                _loadQuestions();
              }),
              const SizedBox(width: 12),
              Text('Status:',
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 12, color: AppColors.inkGhost)),
              _filterChip('All Status', '', _selectedStatus, (val) {
                setState(() => _selectedStatus = val);
                _loadQuestions();
              }),
              _filterChip('Approved', 'APPROVED', _selectedStatus, (val) {
                setState(() => _selectedStatus = val);
                _loadQuestions();
              }),
              _filterChip('Draft / Pending', 'DRAFT', _selectedStatus, (val) {
                setState(() => _selectedStatus = val);
                _loadQuestions();
              }),
            ],
          ),
        ),

        // Questions List
        Expanded(
          child: _loadingQuestions
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.inkPrimary),
                )
              : _questions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.quiz_outlined,
                              size: 48, color: AppColors.inkGhost),
                          const SizedBox(height: 12),
                          Text(
                            'No questions found matching criteria.',
                            style: GoogleFonts.fraunces(
                              fontSize: 18,
                              color: AppColors.inkPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Upload lecture materials in Course Materials to generate questions.',
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: AppColors.inkSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: _questions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (ctx, i) => _buildQuestionCard(_questions[i]),
                    ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> q) {
    final qId = q['question_id']?.toString() ?? '';
    final text = q['question_text']?.toString() ?? '';
    final bloom = q['bloom_level']?.toString() ?? 'C1';
    final status = (q['status']?.toString() ?? 'DRAFT').toUpperCase();
    final rationale = q['pedagogical_rationale']?.toString() ?? '';
    final options = (q['options'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final answer = q['correct_answer']?.toString() ?? '';
    final isWorking = _actionInProgress.contains(qId);

    final bloomColor = _bloomColor(bloom);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r4),
        border: Border.all(color: AppColors.rule, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header with Bloom Tag and Status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: bloomColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppRadius.r4),
                  border: Border.all(color: bloomColor.withOpacity(0.4)),
                ),
                child: Text(
                  _bloomTitle(bloom),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: bloomColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StampBadge(
                label: status,
                type: status == 'APPROVED'
                    ? StampType.pass
                    : status == 'ARCHIVED'
                        ? StampType.neutral
                        : StampType.pending,
              ),
              const Spacer(),
              if (status != 'APPROVED')
                TextButton.icon(
                  onPressed: isWorking ? null : () => _approveQuestion(qId),
                  icon: const Icon(Icons.check_circle_outline,
                      size: 16, color: AppColors.successGreen),
                  label: Text('Approve',
                      style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.successGreen)),
                ),
              if (status != 'ARCHIVED')
                TextButton.icon(
                  onPressed: isWorking ? null : () => _rejectQuestion(qId),
                  icon: const Icon(Icons.archive_outlined,
                      size: 16, color: AppColors.inkGhost),
                  label: Text('Archive',
                      style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.inkGhost)),
                ),
            ],
          ),

          const SizedBox(height: 12),
          // Question text
          SelectableText(
            text,
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.inkPrimary,
              height: 1.4,
            ),
          ),

          // Options
          if (options.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...options.asMap().entries.map((entry) {
              final idx = entry.key;
              final opt = entry.value;
              final letter = String.fromCharCode(65 + idx);
              final isCorrect = (opt == answer) || (answer.toUpperCase() == letter);

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isCorrect
                      ? AppColors.successGreen.withOpacity(0.08)
                      : AppColors.surfaceMid,
                  borderRadius: BorderRadius.circular(AppRadius.r4),
                  border: Border.all(
                    color: isCorrect
                        ? AppColors.successGreen.withOpacity(0.4)
                        : AppColors.rule,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '$letter. ',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isCorrect
                            ? AppColors.successGreen
                            : AppColors.inkSecondary,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        opt,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: AppColors.inkPrimary,
                        ),
                      ),
                    ),
                    if (isCorrect)
                      const Icon(Icons.check_rounded,
                          size: 16, color: AppColors.successGreen),
                  ],
                ),
              );
            }),
          ],

          // Pedagogical rationale
          if (rationale.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceMid,
                borderRadius: BorderRadius.circular(AppRadius.r4),
                border: Border.all(color: AppColors.rule),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline_rounded,
                      size: 16, color: AppColors.signal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI Pedagogical Rationale: $rationale',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: AppColors.inkSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 2. HEC OBE ATTAINMENT TAB
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildObeAttainmentView() {
    if (_loadingAttainment) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.inkPrimary),
      );
    }

    final report = _attainmentReport ?? {};
    final clos = (report['clos'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header summary cards
          Row(
            children: [
              Expanded(
                child: _attainmentStatCard(
                  'Tracked CLOs',
                  '${clos.length}',
                  Icons.checklist_rounded,
                  AppColors.inkPrimary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _attainmentStatCard(
                  'HEC Target Threshold',
                  '60.0%',
                  Icons.flag_outlined,
                  AppColors.signal,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _attainmentStatCard(
                  'Accreditation Status',
                  'Compliant',
                  Icons.verified_outlined,
                  AppColors.successGreen,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          Text(
            'Outcome-Based Education (OBE) Attainment Matrix',
            style: GoogleFonts.fraunces(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.inkPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Calculated dynamically from graded quizzes, assignments, and exams based on National Computing Education Accreditation Council (NCEAC) standards.',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppColors.inkSecondary,
            ),
          ),
          const SizedBox(height: 16),

          if (clos.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.r4),
                border: Border.all(color: AppColors.rule),
              ),
              child: Text(
                'No student assessment submissions recorded yet for $widget.courseTitle. Publish an assignment and evaluate submissions to compute attainment.',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: AppColors.inkSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...clos.map((clo) {
              final code = clo['clo_code']?.toString() ?? 'CLO';
              final desc = clo['clo_description']?.toString() ?? 'Course Objective';
              final pct = (clo['attainment_pct'] as num?)?.toDouble() ?? 0.0;
              final target = (clo['target_pct'] as num?)?.toDouble() ?? 60.0;
              final isAttained = pct >= target;

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.r4),
                  border: Border.all(color: AppColors.rule),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          code,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        StampBadge(
                          label: isAttained ? 'Target Met' : 'Under Threshold',
                          type: isAttained ? StampType.pass : StampType.critical,
                        ),
                        const Spacer(),
                        Text(
                          '${pct.toStringAsFixed(1)}%',
                          style: GoogleFonts.fraunces(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: isAttained
                                ? AppColors.successGreen
                                : AppColors.statusCriticalInk,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      desc,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: AppColors.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: (pct / 100.0).clamp(0.0, 1.0),
                      backgroundColor: AppColors.surfaceMid,
                      color: isAttained
                          ? AppColors.successGreen
                          : AppColors.statusCriticalInk,
                      minHeight: 6,
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _attainmentStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r4),
        border: Border.all(color: AppColors.rule),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 11, color: AppColors.inkGhost)),
              const SizedBox(height: 4),
              Text(value,
                  style: GoogleFonts.fraunces(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkPrimary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(
      String label, String value, String current, ValueChanged<String> onSelect) {
    final isSelected = current == value;
    return InkWell(
      onTap: () => onSelect(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.inkPrimary : AppColors.surfaceMid,
          borderRadius: BorderRadius.circular(AppRadius.r4),
          border: Border.all(
            color: isSelected ? AppColors.inkPrimary : AppColors.rule,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? AppColors.canvas : AppColors.inkPrimary,
          ),
        ),
      ),
    );
  }
}
