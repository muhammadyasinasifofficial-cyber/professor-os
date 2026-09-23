/// ProfessorOS – Anti-Cheat Exam Screen.
/// Supports all assignment types with fullscreen lock, tab-switch detection,
/// countdown timer, biometric verification, and auto-submission.

import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_parser.dart';
import '../data/course_repository.dart';
import '../utils/mcq_parser.dart';

class ExamScreen extends ConsumerStatefulWidget {
  final int courseId;
  final int assignmentId;
  final String assignmentTitle;
  final String assignmentType; // 'text', 'programming', 'file', 'mcq'
  final String? description;
  final double maxMarks;
  final int? timeLimitMinutes;
  final bool randomizeQuestions;
  final bool showResultsAfter;

  const ExamScreen({
    super.key,
    required this.courseId,
    required this.assignmentId,
    required this.assignmentTitle,
    required this.assignmentType,
    this.description,
    required this.maxMarks,
    this.timeLimitMinutes,
    this.randomizeQuestions = false,
    this.showResultsAfter = true,
  });

  @override
  ConsumerState<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends ConsumerState<ExamScreen>
    with WidgetsBindingObserver {
  // ── State ────────────────────────────────────────────────────────────
  bool _biometricPassed = false;
  bool _examStarted = false;
  bool _submitted = false;
  bool _submitting = false;
  Map<String, dynamic>? _examResult;
  String? _error;

  // Timer
  Timer? _timer;
  int _remainingSeconds = 0;

  // Anti-cheat
  int _tabSwitchCount = 0;
  bool _isFlagged = false;
  bool _showingWarning = false;

  // Submission content
  final _textCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  int? _mcqSelected;
  String? _selectedFileName;
  List<int>? _selectedFileBytes;

  final _localAuth = LocalAuthentication();
  final _repo = CourseRepository();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enterFullscreen();
    _runBiometricAuth();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _textCtrl.dispose();
    _codeCtrl.dispose();
    _exitFullscreen();
    super.dispose();
  }

  void _enterFullscreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  void _exitFullscreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  // ── Biometric ────────────────────────────────────────────────────────
  Future<void> _runBiometricAuth() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (!canCheck && !isDeviceSupported) {
        // Device doesn’t support biometrics — skip and allow exam
        if (mounted) setState(() => _biometricPassed = true);
        return;
      }
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Verify your identity to start the exam',
        options: const AuthenticationOptions(biometricOnly: false),
      );
      if (mounted) setState(() => _biometricPassed = authenticated);
      if (!authenticated && mounted) {
        setState(
            () => _error = 'Identity verification failed. Please try again.');
      }
    } catch (_) {
      // local_auth not available (e.g., web) — skip
      if (mounted) setState(() => _biometricPassed = true);
    }
  }

  // ── Exam Start ──────────────────────────────────────────────────
  Future<void> _startExam() async {
    try {
      final result =
          await _repo.startExam(widget.courseId, widget.assignmentId);
      final timeLimit = result['time_limit_minutes'] as int?;
      setState(() {
        _examStarted = true;
        _remainingSeconds = (timeLimit ?? 0) * 60;
      });
      if (timeLimit != null && timeLimit > 0) {
        _startTimer();
      }
    } catch (e) {
      if (mounted) setState(() => _error = ErrorParser.parse(e));
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_remainingSeconds <= 1) {
        t.cancel();
        _autoSubmit();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  Future<void> _autoSubmit() async {
    if (_submitted || _submitting) return;
    // Fill in dummy content if empty so submission goes through
    await _submitExam(autoSubmitted: true);
  }

  // ── App lifecycle ── (Tab-switch detection) ──────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_examStarted || _submitted) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      _handleTabSwitch();
    }
  }

  Future<void> _handleTabSwitch() async {
    if (_showingWarning) return;
    setState(() {
      _tabSwitchCount++;
      _showingWarning = true;
    });

    // Report to backend
    try {
      final result =
          await _repo.flagExamSwitch(widget.courseId, widget.assignmentId);
      if (result['is_flagged'] == true) {
        setState(() => _isFlagged = true);
      }
    } catch (_) {}

    // Show warning overlay
    if (mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.bgSurface,
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.orange, size: 28),
              const SizedBox(width: 8),
              Text('Warning',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You left the exam screen.',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Tab switches detected: $_tabSwitchCount',
                style: GoogleFonts.inter(color: AppColors.textSecondary),
              ),
              if (_tabSwitchCount >= 3) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '⚠️ Your attempt has been flagged for review by your instructor.',
                    style: GoogleFonts.inter(color: Colors.red, fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryIndigo),
              onPressed: () {
                Navigator.pop(context);
                setState(() => _showingWarning = false);
                _enterFullscreen();
              },
              child: const Text('Return to Exam',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
    setState(() => _showingWarning = false);
  }

  // ── Submit ───────────────────────────────────────────────────────────
  Future<void> _submitExam({bool autoSubmitted = false}) async {
    if (_submitted || _submitting) return;
    setState(() => _submitting = true);
    _timer?.cancel();

    try {
      // Submit the actual answer content
      switch (widget.assignmentType) {
        case 'file':
          if (_selectedFileBytes != null && _selectedFileName != null) {
            await _repo.submitFile(
              widget.courseId,
              widget.assignmentId,
              _selectedFileBytes!,
              _selectedFileName!,
            );
          }
          break;
        case 'programming':
          final code = _codeCtrl.text.trim();
          if (code.isNotEmpty) {
            await _repo.submitAssignment(
              widget.courseId,
              widget.assignmentId,
              {'submission_type': 'programming', 'content': code},
            );
          }
          break;
        case 'mcq':
          if (_mcqSelected != null) {
            final optionLetter =
                ['A', 'B', 'C', 'D', 'E'][(_mcqSelected! - 1).clamp(0, 4)];
            await _repo.submitAssignment(
              widget.courseId,
              widget.assignmentId,
              {'submission_type': 'mcq', 'content': 'Option $optionLetter'},
            );
          }
          break;
        default: // text
          final text = _textCtrl.text.trim();
          if (text.isNotEmpty) {
            await _repo.submitAssignment(
              widget.courseId,
              widget.assignmentId,
              {'submission_type': 'text', 'content': text},
            );
          }
      }

      // Mark exam attempt as submitted
      await _repo.submitExam(widget.courseId, widget.assignmentId);

      if (mounted) {
        setState(() {
          _submitted = true;
          _submitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ErrorParser.parse(e)),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  // ── Timer display ─────────────────────────────────────────────────────
  String get _timerDisplay {
    if (widget.timeLimitMinutes == null) return '';
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Color get _timerColor {
    if (_remainingSeconds > 300) return AppColors.successGreen;
    if (_remainingSeconds > 60) return AppColors.accentAmber;
    return Colors.red;
  }

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // ─ Biometric gate ─
    if (!_biometricPassed) {
      return Scaffold(
        backgroundColor: AppColors.bgPage,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.fingerprint,
                    size: 72, color: AppColors.primaryIndigo),
                const SizedBox(height: 24),
                Text('Identity Verification Required',
                    style: GoogleFonts.outfit(
                        fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Text(
                  'Please verify your identity using biometrics or device PIN to start the exam.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: AppColors.textSecondary),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _runBiometricAuth,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Verify Identity'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryIndigo,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(200, 48),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ─ Pre-exam instructions ─
    if (!_examStarted) {
      return Scaffold(
        backgroundColor: AppColors.bgPage,
        appBar: AppBar(
          title: Text(widget.assignmentTitle,
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Before You Start',
                      style: GoogleFonts.outfit(
                          fontSize: 24, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  _instructionItem(
                      Icons.timer_outlined,
                      widget.timeLimitMinutes != null
                          ? 'Time limit: ${widget.timeLimitMinutes} minutes. The exam auto-submits when time runs out.'
                          : 'No time limit for this exam.'),
                  _instructionItem(Icons.fullscreen,
                      'The exam runs in fullscreen. Do not leave this screen.'),
                  _instructionItem(Icons.visibility,
                      'Leaving the app or switching tabs will be recorded and reported to your instructor.'),
                  _instructionItem(Icons.warning_amber_rounded,
                      'After 3 tab switches your attempt will be flagged for review.'),
                  _instructionItem(Icons.fingerprint,
                      'Your identity has been verified. Do not share your device.'),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _startExam,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryIndigo,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Start Exam',
                          style: GoogleFonts.outfit(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ─ Submitted / Result screen ─
    if (_submitted) {
      return Scaffold(
        backgroundColor: AppColors.bgPage,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline_rounded,
                    size: 80, color: AppColors.successGreen),
                const SizedBox(height: 24),
                Text('Exam Submitted!',
                    style: GoogleFonts.outfit(
                        fontSize: 26, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Text(
                  'Your answers have been recorded successfully. Your instructor will grade them shortly.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      color: AppColors.textSecondary, height: 1.5),
                ),
                if (_isFlagged) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.flag_rounded, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Note: Your attempt was flagged due to $_tabSwitchCount app switches. Your instructor has been notified.',
                            style: GoogleFonts.inter(
                                color: Colors.orange.shade800, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryIndigo,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(200, 48),
                  ),
                  child: const Text('Back to Assignment'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ─ Active exam ─
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Leave Exam?',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
            content: const Text(
                'Are you sure you want to leave? Your progress may be lost and this will be recorded.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Stay')),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Leave'),
              ),
            ],
          ),
        );
        if (shouldLeave == true && mounted) {
          _exitFullscreen();
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bgPage,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(widget.assignmentTitle,
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
          actions: [
            if (widget.timeLimitMinutes != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _timerColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _timerColor.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_outlined,
                            size: 16, color: _timerColor),
                        const SizedBox(width: 6),
                        Text(
                          _timerDisplay,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _timerColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_isFlagged)
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Tooltip(
                  message: 'Attempt flagged for review',
                  child: Icon(Icons.flag_rounded, color: Colors.orange),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ElevatedButton(
                onPressed: _submitting ? null : () => _confirmSubmit(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.successGreen,
                  foregroundColor: Colors.white,
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Submit Exam'),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Anti-cheat status bar
              if (_tabSwitchCount > 0)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (_isFlagged ? Colors.red : Colors.orange)
                        .withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: (_isFlagged ? Colors.red : Colors.orange)
                            .withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isFlagged
                            ? Icons.flag_rounded
                            : Icons.warning_amber_rounded,
                        color: _isFlagged ? Colors.red : Colors.orange,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isFlagged
                            ? 'Attempt flagged ( $_tabSwitchCount switches ) — instructor notified'
                            : 'Tab switches: $_tabSwitchCount / 3 before flagging',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: _isFlagged
                              ? Colors.red.shade700
                              : Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),

              // Question / Prompt
              if (widget.description != null && widget.description!.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Question / Prompt',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 10),
                      Text(
                        widget.description!,
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            color: AppColors.textPrimary,
                            height: 1.6),
                      ),
                    ],
                  ),
                ),

              // Answer section based on type
              _buildAnswerSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnswerSection() {
    switch (widget.assignmentType) {
      case 'file':
        return _buildFileSection();
      case 'programming':
        return _buildCodeSection();
      case 'mcq':
        return _buildMcqSection();
      default:
        return _buildTextSection();
    }
  }

  Widget _buildTextSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your Answer',
            style:
                GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        // Copy-paste disabled via ignoring selection gestures
        TextField(
          controller: _textCtrl,
          maxLines: 12,
          enableInteractiveSelection: false, // disables copy-paste
          decoration: InputDecoration(
            hintText: 'Write your answer here...',
            filled: true,
            fillColor: AppColors.bgSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
          style: GoogleFonts.inter(fontSize: 14, height: 1.6),
        ),
      ],
    );
  }

  Widget _buildCodeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your Code',
            style:
                GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        TextField(
          controller: _codeCtrl,
          maxLines: 16,
          enableInteractiveSelection: false,
          style: GoogleFonts.jetBrainsMono(
              fontSize: 13, color: AppColors.inkPrimary),
          decoration: InputDecoration(
            hintText: '// Write your code here...\n',
            hintStyle: GoogleFonts.jetBrainsMono(
                fontSize: 13, color: AppColors.textMuted),
            filled: true,
            fillColor: const Color(0xFF0F1117),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMcqSection() {
    final desc = widget.description ?? '';
    final structuredQuestions = parseMcqDescription(desc);
    if (structuredQuestions.isNotEmpty) {
      final question = structuredQuestions.first;
      final options = (question['options'] as List?)
              ?.map((option) => option.toString())
              .toList() ??
          const <String>[];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question['question'].toString(),
              style: GoogleFonts.outfit(
                  fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _mcqOptions(options),
        ],
      );
    }

    // Backward-compatible parsing for legacy plain-text MCQs.
    final lines = desc.split('\n');
    final questionLines = <String>[];
    final optionLines = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (RegExp(r'^[A-Ea-e][).]').hasMatch(trimmed)) {
        optionLines.add(trimmed);
      } else {
        questionLines.add(trimmed);
      }
    }
    // If no structured options found, show as free-response radio (generic)
    if (optionLines.isEmpty) {
      optionLines
          .addAll(['A) Option A', 'B) Option B', 'C) Option C', 'D) Option D']);
    }

    return _mcqOptions(optionLines);
  }

  Widget _mcqOptions(List<String> optionLines) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Your Answer',
            style:
                GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: optionLines.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.border),
            itemBuilder: (_, i) {
              final optionText = optionLines[i];
              final optionValue = i + 1;
              return RadioListTile<int>(
                value: optionValue,
                groupValue: _mcqSelected,
                onChanged: (v) => setState(() => _mcqSelected = v),
                title: Text(optionText,
                    style: GoogleFonts.inter(
                        fontSize: 14, color: AppColors.textPrimary)),
                activeColor: AppColors.primaryIndigo,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFileSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Upload Your File',
            style:
                GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('Allowed: PDF, ZIP, DOCX, TXT • Max: 25 MB',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['pdf', 'zip', 'docx', 'doc', 'txt'],
              withData: true,
            );
            if (result != null && result.files.single.bytes != null) {
              final file = result.files.single;
              const maxBytes = 25 * 1024 * 1024;
              if (file.size > maxBytes) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('File too large. Max 25 MB allowed.'),
                    backgroundColor: Colors.red,
                  ));
                }
                return;
              }
              setState(() {
                _selectedFileName = file.name;
                _selectedFileBytes = file.bytes!.toList();
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primaryIndigo.withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  _selectedFileName != null
                      ? Icons.insert_drive_file_rounded
                      : Icons.cloud_upload_outlined,
                  size: 40,
                  color: AppColors.primaryIndigo,
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedFileName ?? 'Click to choose file',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: _selectedFileName != null
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: _selectedFileName != null
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _instructionItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primaryIndigo),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: GoogleFonts.inter(
                    fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSubmit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Submit Exam?',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        content: const Text(
            'Are you sure you want to submit? You cannot make changes after submission.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Review Answers')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.successGreen,
                foregroundColor: Colors.white),
            child: const Text('Submit Now'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _submitExam();
  }
}
