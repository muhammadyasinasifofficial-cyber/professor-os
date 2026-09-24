import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_parser.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/prof_card.dart';
import '../../../shared/widgets/prof_weight_slider.dart';
import '../data/course_repository.dart';
import '../providers/course_providers.dart';

class AssignmentCreationWizard extends ConsumerStatefulWidget {
  final int courseId;
  const AssignmentCreationWizard({super.key, required this.courseId});

  @override
  ConsumerState<AssignmentCreationWizard> createState() => _WizardState();
}

class _WizardState extends ConsumerState<AssignmentCreationWizard> {
  int _step = 0;
  bool _loading = false;

  // Step 1: Type
  String _type =
      'text'; // 'text', 'qna', 'file', 'mcq', 'programming', 'hybrid'

  // Step 2: Details
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _marksCtrl = TextEditingController(text: '100');
  final _quillCtrl = quill.QuillController.basic();
  String _category =
      'assignments'; // 'quizzes', 'assignments', 'midterm', 'final', 'project'
  bool _allowLate = false;
  double _latePenalty = 10;
  double _maxPenaltyCap = 50;
  String? _selectedFileName;
  String? _selectedFileSizeStr;
  Uint8List? _selectedFileBytes;
  final Set<int> _selectedCloIds = {};

  // MCQ Questions (for MCQ type)
  final List<_McqQuestion> _mcqQuestions = [];

  // Step 3: Rubric Builder (Criteria list)
  final List<_RubricRow> _criteria = [
    _RubricRow(name: 'Technical Accuracy', weight: 40),
    _RubricRow(name: 'Structure & Quality', weight: 30),
    _RubricRow(name: 'Documentation', weight: 30),
  ];

  // ── Predefined level names for rubrics ─────────────
  static const List<String> _levelNames = [
    'excellent',
    'satisfactory',
    'developing',
    'insufficient'
  ];
  static const List<String> _levelLabels = [
    'Excellent',
    'Satisfactory',
    'Developing',
    'Insufficient'
  ];
  static const List<String> _levelDefaults = [
    'Exceptional quality with deep mastery',
    'Good quality showing solid understanding',
    'Basic quality with room for improvement',
    'Below expected standard, needs significant revision',
  ];

  // Step 4: TA Delegation
  String _taBatchPolicy = 'all'; // 'all', 'split_equal'

  // ── Step flow (dynamic based on type) ─────────────
  List<String> get _stepFlow {
    if (_type == 'mcq')
      return ['type', 'mcq', 'details', 'rubric', 'ta', 'review'];
    return ['type', 'details', 'rubric', 'ta', 'review'];
  }

  int get _totalSteps => _stepFlow.length;

  Future<void> _publish(bool asDraft) async {
    // If no CLO was selected manually, backend will automatically link the course CLO or seed CLO-1.

    setState(() => _loading = true);
    try {
      final repo = CourseRepository();
      // 1. Create Assignment
      // Map frontend types to backend-supported types
      String mappedType;
      switch (_type) {
        case 'qna':
        case 'hybrid':
        case 'text':
          mappedType = 'text';
          break;
        case 'file':
          mappedType = 'file';
          break;
        case 'mcq':
          mappedType = 'mcq';
          break;
        case 'programming':
          mappedType = 'programming';
          break;
        default:
          mappedType = 'text';
      }

      final assignData = {
        'title': _titleCtrl.text.trim(),
        'description': (_type == 'mcq' && _mcqQuestions.isNotEmpty)
            ? jsonEncode({
                'type': 'mcq',
                'questions': _mcqQuestions.map((q) => q.toJson()).toList(),
              })
            : '',
        'type': mappedType,
        'max_marks': double.parse(_marksCtrl.text),
        'allow_late': _allowLate,
        'late_penalty_per_day': _latePenalty,
        'max_penalty_cap': _maxPenaltyCap,
        'clo_ids': _selectedCloIds.toList(),
      };
      final created = await repo.createAssignment(widget.courseId, assignData);
      final aid = created['id'] as int;

      // 2. Create Rubric with level descriptions
      final rubricData = {
        'criteria': _criteria
            .map((c) => {
                  'name': c.nameCtrl.text.trim(),
                  'weight': c.weight,
                  'levels': c.levels
                      .map((l) => {
                            'level': l.levelName,
                            'description': l.descCtrl.text.trim(),
                          })
                      .toList(),
                })
            .toList()
      };
      await repo.saveRubric(aid, rubricData);

      // 3. Publish if requested
      if (!asDraft) {
        await repo.publishAssignment(widget.courseId, aid);
      }

      if (mounted) {
        // Invalidate assignment list to refresh on course detail screen
        ref.invalidate(assignmentListProvider(widget.courseId));
        // Navigate to the newly created assignment detail page
        context.go('/courses/${widget.courseId}/assignments/$aid');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ErrorParser.parse(e)),
        backgroundColor: AppColors.dangerRose,
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _marksCtrl.dispose();
    _quillCtrl.dispose();
    for (var c in _criteria) {
      c.dispose();
    }
    for (var q in _mcqQuestions) {
      q.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => context.pop()),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create Assignment',
                style: GoogleFonts.fraunces(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkPrimary)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStep1Type(),
                      const SizedBox(height: 48),
                      if (_type == 'mcq') ...[
                        _buildMcqQuestionsStep(),
                        const SizedBox(height: 48),
                      ],
                      _buildStep2Details(),
                      const SizedBox(height: 48),
                      _buildStep3Rubric(),
                      const SizedBox(height: 48),
                      _buildStep4TA(),
                      const SizedBox(height: 64),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.sizeOf(context).width < 500 ? 16 : 40,
              vertical: 20,
            ),
            decoration: const BoxDecoration(
              color: AppColors.bgSurface,
              border: Border(top: BorderSide(color: AppColors.marginRule)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final saveDraft = OutlinedButton(
                  onPressed: _loading ? null : () => _publish(true),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                  ),
                  child: const Text('Save Draft'),
                );
                final publish = ElevatedButton(
                  onPressed: _loading
                      ? null
                      : () {
                          if (!_formKey.currentState!.validate()) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Please fill all required details.'),
                                    backgroundColor: AppColors.dangerRose));
                            return;
                          }
                          final total = _criteria.fold<double>(
                              0, (sum, item) => sum + item.weight);
                          if (total != 100) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Rubric weights must sum to exactly 100%'),
                                    backgroundColor: AppColors.dangerRose));
                            return;
                          }
                          _publish(false);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.signal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text('Publish Assignment',
                          style:
                              GoogleFonts.inter(fontWeight: FontWeight.w600)),
                );

                if (constraints.maxWidth < 500) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [saveDraft, const SizedBox(height: 10), publish],
                  );
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    saveDraft,
                    const SizedBox(width: 16),
                    publish,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1Type() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 1: Select Assessment Type',
            style:
                GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700)),
        Text('Choose how students will submit their responses for evaluation.',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
        const SizedBox(height: 24),
        GridView.count(
          crossAxisCount: MediaQuery.of(context).size.width > 640 ? 2 : 1,
          shrinkWrap: true,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 2.4,
          children: [
            _typeCard('text', 'Text Essay', Icons.article_rounded,
                'Open-ended long text evaluated by LLM rubric engine.'),
            _typeCard('qna', 'Short Answer / Q&A', Icons.quiz_rounded,
                'Structured question & answer prompts with key phrases.'),
            _typeCard('file', 'File Upload', Icons.cloud_upload_rounded,
                'Submissions via PDF, DOCX, or ZIP with 25MB cap.'),
            _typeCard('mcq', 'MCQ Quiz', Icons.check_circle_outline_rounded,
                'Multiple choice question sets with instant grading.'),
            _typeCard('programming', 'Programming', Icons.terminal_rounded,
                'Source code submissions evaluated against unit tests.'),
            _typeCard('hybrid', 'Hybrid / Mixed', Icons.hub_rounded,
                'Combines MCQs, Q&A, and programming challenges.'),
          ],
        )
      ],
    );
  }

  Widget _typeCard(String type, String title, IconData icon, String desc) {
    final selected = _type == type;
    return InkWell(
      onTap: () => setState(() => _type = type),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryIndigo.withOpacity(0.06)
              : AppColors.bgSurface,
          border: Border.all(
              color: selected ? AppColors.primaryIndigo : AppColors.border,
              width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(16),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: AppColors.primaryIndigo.withOpacity(0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected ? AppColors.primaryIndigo : AppColors.bgPage,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  size: 24,
                  color: selected ? Colors.white : AppColors.textSecondary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title,
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(desc,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          height: 1.3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMcqQuestionsStep() {
    const optionLabels = ['A', 'B', 'C', 'D'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MCQ Questions',
            style:
                GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
            'Add multiple-choice questions. Students see all questions when they open the assignment.',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
        const SizedBox(height: 24),
        if (_mcqQuestions.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.quiz_outlined,
                      size: 44, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  Text('No questions yet.',
                      style: GoogleFonts.outfit(
                          fontSize: 16,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                      'Click "Add Question" below to start building your quiz.',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.textMuted)),
                ],
              ),
            ),
          ),
        ...List.generate(_mcqQuestions.length, (qi) {
          final q = _mcqQuestions[qi];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryIndigo.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Q${qi + 1}',
                          style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryIndigo)),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.dangerRose, size: 20),
                      onPressed: () =>
                          setState(() => _mcqQuestions.removeAt(qi)),
                      tooltip: 'Remove Question',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: q.questionCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Question',
                      hintText:
                          'e.g. What is the time complexity of binary search?'),
                  maxLines: 2,
                ),
                const SizedBox(height: 14),
                Text('Options — select the correct answer:',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                ...List.generate(
                    4,
                    (oi) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Radio<int>(
                                value: oi,
                                groupValue: q.correctIndex,
                                onChanged: (val) =>
                                    setState(() => q.correctIndex = val!),
                                activeColor: AppColors.successGreen,
                              ),
                              Container(
                                width: 28,
                                height: 28,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: q.correctIndex == oi
                                      ? AppColors.successGreen.withOpacity(0.1)
                                      : AppColors.bgPage,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: q.correctIndex == oi
                                        ? AppColors.successGreen
                                        : AppColors.border,
                                  ),
                                ),
                                child: Center(
                                  child: Text(optionLabels[oi],
                                      style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: q.correctIndex == oi
                                              ? AppColors.successGreen
                                              : AppColors.textSecondary)),
                                ),
                              ),
                              Expanded(
                                child: TextFormField(
                                  controller: q.optionCtrls[oi],
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText: 'Option ${optionLabels[oi]}',
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: q.correctIndex == oi
                                            ? AppColors.successGreen
                                            : AppColors.border,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: q.correctIndex == oi
                                            ? AppColors.successGreen
                                            : AppColors.primaryIndigo,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
              ],
            ),
          );
        }),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => setState(() => _mcqQuestions.add(_McqQuestion())),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add Question'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryIndigo,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2Details() {
    final extensions = _type == 'programming'
        ? '.zip, .py, .cpp, .java, .js, .cs'
        : _type == 'file'
            ? '.pdf, .docx, .zip, .png, .jpg'
            : '.pdf, .docx, .txt';

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Step 2: Assignment Specifications',
              style: GoogleFonts.outfit(
                  fontSize: 22, fontWeight: FontWeight.w700)),
          Text(
              'Configure basic metadata, HEC category, and reference materials.',
              style:
                  GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
          const SizedBox(height: 24),
          ProfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _titleCtrl,
                  validator: Validators.required,
                  decoration: const InputDecoration(
                      labelText: 'Assignment Title',
                      hintText: 'e.g. Midterm Lab Task 1 - Recursion'),
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final category = DropdownButtonFormField<String>(
                      value: _category,
                      decoration:
                          const InputDecoration(labelText: 'HEC Category'),
                      items: const [
                        DropdownMenuItem(
                            value: 'quizzes', child: Text('Quizzes Category')),
                        DropdownMenuItem(
                            value: 'assignments',
                            child: Text('Assignments Category')),
                        DropdownMenuItem(
                            value: 'midterm', child: Text('Midterm Category')),
                        DropdownMenuItem(
                            value: 'final', child: Text('Final Exam Category')),
                        DropdownMenuItem(
                            value: 'project',
                            child: Text('Course Project Category')),
                      ],
                      onChanged: (val) => setState(() => _category = val!),
                    );
                    final marks = TextFormField(
                      controller: _marksCtrl,
                      validator: Validators.required,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Max Marks', hintText: '100'),
                    );
                    if (constraints.maxWidth < 520)
                      return Column(children: [
                        category,
                        const SizedBox(height: 16),
                        marks
                      ]);
                    return Row(children: [
                      Expanded(child: category),
                      const SizedBox(width: 16),
                      Expanded(child: marks)
                    ]);
                  },
                ),
                /* Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _category,
                        decoration: const InputDecoration(labelText: 'HEC Category'),
                        items: const [
                          DropdownMenuItem(value: 'quizzes', child: Text('Quizzes Category')),
                          DropdownMenuItem(value: 'assignments', child: Text('Assignments Category')),
                          DropdownMenuItem(value: 'midterm', child: Text('Midterm Category')),
                          DropdownMenuItem(value: 'final', child: Text('Final Exam Category')),
                          DropdownMenuItem(value: 'project', child: Text('Course Project Category')),
                        ],
                        onChanged: (val) => setState(() => _category = val!),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _marksCtrl,
                        validator: Validators.required,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Max Marks', hintText: '100'),
                      ),
                    ),
                  ],
                ), */
                const SizedBox(height: 20),
                Text('Late Submission Policy',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Allow Late Submissions'),
                  subtitle: const Text(
                      'Students can submit after the deadline with a penalty.'),
                  value: _allowLate,
                  onChanged: (val) => setState(() => _allowLate = val),
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.primaryIndigo,
                ),
                if (_allowLate) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _latePenalty.toString(),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Late Penalty (%) per day',
                              hintText: '10.0'),
                          onChanged: (val) =>
                              _latePenalty = double.tryParse(val) ?? 10.0,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          initialValue: _maxPenaltyCap.toString(),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Max Penalty Cap (%)',
                              hintText: '50.0'),
                          onChanged: (val) =>
                              _maxPenaltyCap = double.tryParse(val) ?? 50.0,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                Text('Linked Course Learning Outcomes (CLOs)*',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                ref.watch(courseClosProvider(widget.courseId)).when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Error loading CLOs: $e',
                          style: const TextStyle(
                              color: AppColors.dangerRose, fontSize: 12)),
                      data: (clos) {
                        if (clos.isEmpty) {
                          return Row(
                            children: [
                              Text('No CLOs defined for this course yet.',
                                  style: GoogleFonts.inter(
                                      color: AppColors.textMuted,
                                      fontSize: 13)),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.add_rounded, size: 16),
                                label: const Text('Add Default CLO-1'),
                                onPressed: () async {
                                  final created = await CourseRepository()
                                      .createClo(widget.courseId, 'CLO-1',
                                          'Basic outcome objectives');
                                  setState(() {
                                    _selectedCloIds.add(created['id'] as int);
                                  });
                                  ref.invalidate(
                                      courseClosProvider(widget.courseId));
                                },
                              )
                            ],
                          );
                        }
                        if (_selectedCloIds.isEmpty && clos.isNotEmpty) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && _selectedCloIds.isEmpty) {
                              setState(() {
                                _selectedCloIds.add(clos.first['id'] as int);
                              });
                            }
                          });
                        }
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: clos.map<Widget>((clo) {
                            final id = clo['id'] as int;
                            final isSelected = _selectedCloIds.contains(id);
                            return FilterChip(
                              selected: isSelected,
                              label:
                                  Text('${clo['code']}: ${clo['description']}'),
                              selectedColor:
                                  AppColors.primaryIndigo.withOpacity(0.18),
                              checkmarkColor: AppColors.primaryIndigo,
                              onSelected: (val) {
                                setState(() {
                                  if (val) {
                                    _selectedCloIds.add(id);
                                  } else {
                                    _selectedCloIds.remove(id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        );
                      },
                    ),
                const SizedBox(height: 20),
                Text('Reference Materials / Starter Package',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                // Drag & Drop Zone
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.bgPage,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.primaryIndigo.withOpacity(0.3),
                        style: BorderStyle.solid),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.cloud_upload_outlined,
                          size: 36, color: AppColors.primaryIndigo),
                      const SizedBox(height: 10),
                      Text('Drag & drop prompt attachment, or browse files',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text(
                          'Max file size: 25 MB • Allowed formats: $extensions',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: AppColors.textMuted)),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['pdf', 'zip', 'docx', 'doc', 'txt', 'png', 'jpg', 'pptx', 'xlsx'],
                            withData: true,
                          );
                          if (result != null && result.files.isNotEmpty) {
                            final file = result.files.single;
                            const maxBytes = 25 * 1024 * 1024; // 25 MB
                            if (file.size > maxBytes) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('File too large. Maximum allowed size is 25 MB.'), backgroundColor: Colors.red),
                                );
                              }
                              return;
                            }
                            final bytes = file.bytes;
                            final sizeInKb =
                                (file.size / 1024).toStringAsFixed(1);
                            final sizeStr = file.size > 1024 * 1024
                                ? '${(file.size / (1024 * 1024)).toStringAsFixed(1)} MB'
                                : '$sizeInKb KB';
                            setState(() {
                              _selectedFileName = file.name;
                              _selectedFileSizeStr = sizeStr;
                              _selectedFileBytes = bytes;
                            });
                          }
                        },
                        icon: const Icon(Icons.folder_open_rounded, size: 16),
                        label: Text(_selectedFileName == null
                            ? 'Select Attachment File'
                            : 'Change File'),
                      ),
                      if (_selectedFileName != null) ...[
                        const SizedBox(height: 12),
                        Chip(
                          avatar: const Icon(Icons.insert_drive_file_rounded,
                              size: 16, color: AppColors.primaryIndigo),
                          label: Text(
                              '$_selectedFileName ($_selectedFileSizeStr)'),
                          onDeleted: () => setState(() {
                            _selectedFileName = null;
                            _selectedFileSizeStr = null;
                            _selectedFileBytes = null;
                          }),
                          deleteIcon: const Icon(Icons.close_rounded, size: 14),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3Rubric() {
    final total = _criteria.fold<double>(0, (sum, item) => sum + item.weight);
    final isValid = total == 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 3: Rubric Builder',
            style:
                GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700)),
        Text(
            'HEC policy requires at least 3 criteria, with weights summing to 100%.',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
        const SizedBox(height: 24),
        // Live Validation Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isValid
                ? AppColors.successGreen.withOpacity(0.08)
                : AppColors.dangerRose.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isValid
                    ? AppColors.successGreen.withOpacity(0.3)
                    : AppColors.dangerRose.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(
                  isValid
                      ? Icons.check_circle_rounded
                      : Icons.warning_amber_rounded,
                  color:
                      isValid ? AppColors.successGreen : AppColors.dangerRose,
                  size: 20),
              const SizedBox(width: 10),
              Text(
                'Rubric Total Weight: ${total.toInt()}%',
                style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isValid
                        ? AppColors.successGreen
                        : AppColors.dangerRose),
              ),
              const Spacer(),
              Text('Min 3 Criteria (${_criteria.length} added)',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _criteria.length,
          itemBuilder: (context, index) {
            final c = _criteria[index];
            return Container(
              key: ValueKey(c),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.drag_indicator_rounded,
                          color: AppColors.textMuted),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: c.nameCtrl,
                          decoration: const InputDecoration(
                              isDense: true, labelText: 'Criterion Name'),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 3,
                        child: ProfWeightSlider(
                          value: c.weight,
                          onChanged: (v) => setState(() => c.weight = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: AppColors.dangerRose),
                        onPressed: _criteria.length > 3
                            ? () => setState(() => _criteria.removeAt(index))
                            : null,
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text('Performance Levels',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  ...List.generate(
                      4,
                      (li) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 100,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: li == 0
                                          ? AppColors.successGreen
                                              .withOpacity(0.08)
                                          : li == 3
                                              ? AppColors.dangerRose
                                                  .withOpacity(0.08)
                                              : AppColors.bgPage,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(_levelLabels[li],
                                        style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: c.levels[li].descCtrl,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      hintText: _levelDefaults[li],
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                    ),
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          )),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        if (_criteria.length < 10)
          OutlinedButton.icon(
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Criterion'),
            onPressed: () => setState(() =>
                _criteria.add(_RubricRow(name: 'New Criterion', weight: 0))),
          ),
      ],
    );
  }

  Widget _buildStep4TA() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 4: TA Delegation',
            style:
                GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700)),
        Text(
            'Enroll TAs from the Students Roster, then assign them to this assignment after it is created.',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
        const SizedBox(height: 24),
        ProfCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: AppColors.accentAmber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.construction_rounded,
                        color: AppColors.accentAmber, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TA Grading Workflow',
                            style: GoogleFonts.outfit(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        Text(
                            'TA delegation is available from the assignment list after saving this assignment.',
                            style: GoogleFonts.inter(
                                fontSize: 13, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Text('Available workflow:',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              ...[
                'Enroll a TA by email in Students Roster',
                'Assign enrolled TAs to this assignment',
                'Open the SpeedGrader workload from the TA dashboard',
              ].map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline_rounded,
                            size: 16, color: AppColors.primaryIndigo),
                        const SizedBox(width: 10),
                        Text(f,
                            style: GoogleFonts.inter(
                                fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep5Review() {
    final totalWeight =
        _criteria.fold<double>(0, (sum, item) => sum + item.weight);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 5: Review & Publish',
            style:
                GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700)),
        Text(
            'Verify assignment configuration before releasing to enrolled students.',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
        const SizedBox(height: 24),
        ProfCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                      _titleCtrl.text.isEmpty
                          ? 'Untitled Assignment'
                          : _titleCtrl.text,
                      style: GoogleFonts.outfit(
                          fontSize: 20, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Chip(
                    label: Text(_type.toUpperCase()),
                    backgroundColor: AppColors.primaryIndigo.withOpacity(0.1),
                    labelStyle: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryIndigo),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _statItem('Max Marks', _marksCtrl.text),
                  _statItem('HEC Category', _category.toUpperCase()),
                  _statItem('Rubric Weight', '${totalWeight.toInt()}%'),
                  if (_type == 'mcq')
                    _statItem('Questions', '${_mcqQuestions.length} MCQs'),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 14),
              Text('Rubric Criteria (${_criteria.length} Items):',
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ..._criteria.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded,
                            size: 16, color: AppColors.primaryIndigo),
                        const SizedBox(width: 8),
                        Text(c.nameCtrl.text,
                            style: GoogleFonts.inter(
                                fontSize: 13, color: AppColors.textPrimary)),
                        const Spacer(),
                        Text('${c.weight.toInt()}%',
                            style: GoogleFonts.outfit(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statItem(String label, String val) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text(val,
              style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

// ── MCQ Question model ──────────────────────────────
class _McqQuestion {
  final TextEditingController questionCtrl;
  final List<TextEditingController> optionCtrls;
  int correctIndex;

  _McqQuestion()
      : questionCtrl = TextEditingController(),
        optionCtrls = List.generate(4, (_) => TextEditingController()),
        correctIndex = 0;

  void dispose() {
    questionCtrl.dispose();
    for (final c in optionCtrls) c.dispose();
  }

  Map<String, dynamic> toJson() => {
        'question': questionCtrl.text.trim(),
        'options': optionCtrls.map((c) => c.text.trim()).toList(),
        'correct': correctIndex,
      };
}

class _RubricLevel {
  final String levelName;
  final TextEditingController descCtrl;
  _RubricLevel({required this.levelName, String defaultDesc = ''})
      : descCtrl = TextEditingController(text: defaultDesc);
  void dispose() => descCtrl.dispose();
}

class _RubricRow {
  final TextEditingController nameCtrl;
  double weight;
  final List<_RubricLevel> levels;
  _RubricRow({required String name, required this.weight})
      : nameCtrl = TextEditingController(text: name),
        levels = List.generate(4, (i) {
          final levelNames = [
            'excellent',
            'satisfactory',
            'developing',
            'insufficient'
          ];
          final defaults = [
            'Exceptional quality with deep mastery',
            'Good quality showing solid understanding',
            'Basic quality with room for improvement',
            'Below expected standard, needs significant revision',
          ];
          return _RubricLevel(
              levelName: levelNames[i], defaultDesc: defaults[i]);
        });
  void dispose() {
    nameCtrl.dispose();
    for (var l in levels) {
      l.dispose();
    }
  }
}
