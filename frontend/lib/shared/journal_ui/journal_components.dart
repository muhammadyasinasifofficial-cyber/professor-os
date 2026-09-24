import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

// ── 1. PRIMARY BUTTON (Fill ↔ Outline Hover Inversion) ─────────────────
class PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final String? loadingLabel;
  final double? width;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.loadingLabel,
    this.width,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bool disabled = widget.onPressed == null || widget.isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Fill stability on hover (no outline inversion; avoids false deactivation impression)
    Color bgColor;
    Color textColor;
    if (disabled) {
      bgColor = AppColors.surfaceMid;
      textColor = AppColors.inkGhost;
    } else if (isDark) {
      bgColor = _isHovered ? Colors.white : AppColors.inkPrimary;
      textColor = AppColors.canvas;
    } else {
      bgColor = _isHovered ? const Color(0xFF2E2E2A) : AppColorsLight.inkPrimary;
      textColor = _isHovered ? Colors.white : AppColorsLight.canvas;
    }

    final Border border = Border.all(
      color: _isHovered && !disabled ? AppColors.ruleStrong : AppColors.rule,
      width: 1,
    );

    return MouseRegion(
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) {
        if (!disabled) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (!disabled) setState(() => _isHovered = false);
      },
      child: GestureDetector(
        onTapDown: (_) {
          if (!disabled) setState(() => _isPressed = true);
        },
        onTapUp: (_) {
          if (!disabled) setState(() => _isPressed = false);
        },
        onTapCancel: () {
          if (!disabled) setState(() => _isPressed = false);
        },
        onTap: disabled ? null : widget.onPressed,
        child: AnimatedScale(
          scale: _isPressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 80),
          curve: Curves.easeOut,
          child: Transform.translate(
            offset: Offset(0, (_isHovered && !disabled) ? -1.0 : 0.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              constraints: const BoxConstraints(minHeight: 44),
              width: widget.width,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: bgColor,
                border: border,
                borderRadius: BorderRadius.circular(AppRadius.r4),
              ),
              alignment: Alignment.center,
              child: Text(
                widget.isLoading
                    ? (widget.loadingLabel ?? '${widget.label}…')
                    : widget.label,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: widget.isLoading ? AppColors.inkGhost : textColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 2. SECONDARY BUTTON (1px Rule border, hover tone shift) ───────────
class SecondaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final String? loadingLabel;
  final double? width;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.loadingLabel,
    this.width,
  });

  @override
  State<SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<SecondaryButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool disabled = widget.onPressed == null || widget.isLoading;

    final Color borderColor = _isHovered && !disabled
        ? AppColors.inkSecondary
        : AppColors.ruleStrong;
    final Color textColor = _isHovered && !disabled
        ? AppColors.inkSecondary
        : AppColors.inkPrimary;

    return MouseRegion(
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) {
        if (!disabled) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (!disabled) setState(() => _isHovered = false);
      },
      child: GestureDetector(
        onTap: disabled ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 40),
          width: widget.width,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(color: borderColor, width: 1),
            borderRadius: BorderRadius.circular(AppRadius.r4),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.isLoading
                ? (widget.loadingLabel ?? '${widget.label}…')
                : widget.label,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: widget.isLoading ? AppColors.inkGhost : textColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

// ── 3. GHOST BUTTON / TEXT HYPERLINK ──────────────────────────────────
class GhostButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isAccent;

  const GhostButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isAccent = false,
  });

  @override
  State<GhostButton> createState() => _GhostButtonState();
}

class _GhostButtonState extends State<GhostButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final Color defaultColor =
        widget.isAccent ? AppColors.inkAccent : AppColors.inkSecondary;
    final Color color = _isHovered ? AppColors.inkPrimary : defaultColor;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Text(
          widget.label,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ),
    );
  }
}

// ── 4. STAMP BADGE (Status Rubber Stamp) ──────────────────────────────
// ── 4. STAMP BADGE (Status Rubber Stamp with Dual-Coding & Laser Contrast) ──
enum StampType { pass, pending, critical, neutral }

class StampBadge extends StatelessWidget {
  final String label;
  final StampType type;

  const StampBadge({
    super.key,
    required this.label,
    this.type = StampType.neutral,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color ink;
    String symbol;

    switch (type) {
      case StampType.pass:
        bg = AppColors.statusPassBg;
        ink = AppColors.statusPassInk;
        symbol = '✓';
        break;
      case StampType.pending:
        bg = AppColors.statusPendingBg;
        ink = AppColors.statusPendingInk;
        symbol = '◷';
        break;
      case StampType.critical:
        bg = AppColors.statusCriticalBg;
        ink = AppColors.statusCriticalInk;
        symbol = '!';
        break;
      case StampType.neutral:
        bg = AppColors.surfaceMid;
        ink = AppColors.inkSecondary;
        symbol = '•';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.r2),
        border: Border.all(color: ink.withOpacity(0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            symbol,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: ink,
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ink,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 5. SCORE INPUT (Bounded Container, JetBrains Mono, Explicit AI Pill) ──
class JournalScoreInput extends StatefulWidget {
  final double? initialScore;
  final double maxMarks;
  final bool isAiSuggested;
  final ValueChanged<double?> onChanged;
  final FocusNode? focusNode;

  const JournalScoreInput({
    super.key,
    this.initialScore,
    required this.maxMarks,
    this.isAiSuggested = false,
    required this.onChanged,
    this.focusNode,
  });

  @override
  State<JournalScoreInput> createState() => _JournalScoreInputState();
}

class _JournalScoreInputState extends State<JournalScoreInput> {
  late TextEditingController _ctrl;
  bool _isAccepted = false;
  String _previousManualText = '';
  bool _isFocused = false;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _isAccepted = false;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
    _ctrl = TextEditingController(
      text: widget.initialScore != null && !widget.isAiSuggested
          ? widget.initialScore!.toStringAsFixed(1).replaceAll('.0', '')
          : '',
    );
  }

  void _onFocusChange() {
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  @override
  void didUpdateWidget(JournalScoreInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialScore != oldWidget.initialScore || widget.isAiSuggested != oldWidget.isAiSuggested) {
      if (!widget.isAiSuggested && widget.initialScore != null) {
        _ctrl.text = widget.initialScore!.toStringAsFixed(1).replaceAll('.0', '');
        _isAccepted = false;
      }
    }
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_onFocusChange);
    }
    _ctrl.dispose();
    super.dispose();
  }

  void _acceptSuggestion() {
    if (widget.initialScore != null) {
      setState(() {
        _isAccepted = true;
        _previousManualText = _ctrl.text;
        _ctrl.text = widget.initialScore!.toStringAsFixed(1).replaceAll('.0', '');
      });
      widget.onChanged(widget.initialScore);
    }
  }

  void _undoSuggestion() {
    setState(() {
      _isAccepted = false;
      _ctrl.text = _previousManualText;
    });
    final parsed = double.tryParse(_previousManualText.trim());
    widget.onChanged(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final hasAi = widget.isAiSuggested && widget.initialScore != null;
    final suggestedValStr = widget.initialScore != null
        ? widget.initialScore!.toStringAsFixed(1).replaceAll('.0', '')
        : '';

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Explicit AI Suggestion Pill / Undo Chip
          if (hasAi) ...[
            if (!_isAccepted)
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _acceptSuggestion,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: AppColors.statusPassBg,
                      borderRadius: BorderRadius.circular(AppRadius.r2),
                      border: Border.all(color: AppColors.statusPassInk.withOpacity(0.4), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'AI Suggestion: [ $suggestedValStr ]',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.statusPassInk,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '• Tap to apply',
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            color: AppColors.statusPassInk.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _undoSuggestion,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMid,
                      borderRadius: BorderRadius.circular(AppRadius.r2),
                      border: Border.all(color: AppColors.ruleStrong, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('✨', style: TextStyle(fontSize: 10)),
                        const SizedBox(width: 4),
                        Text(
                          'AI $suggestedValStr • Undo',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],

          // Bounded 4-sided Surface Container Input
          Container(
            width: 104,
            constraints: const BoxConstraints(minHeight: 42),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceMid,
              borderRadius: BorderRadius.circular(AppRadius.r4),
              border: Border.all(
                color: _isFocused ? AppColors.inkAccent : AppColors.ruleStrong,
                width: _isFocused ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focusNode,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.right,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.inkPrimary,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: '—',
                      hintStyle: GoogleFonts.jetBrainsMono(color: AppColors.inkGhost),
                    ),
                    onChanged: (val) {
                      if (_isAccepted) {
                        setState(() => _isAccepted = false);
                      }
                      final parsed = double.tryParse(val.trim());
                      widget.onChanged(parsed);
                    },
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '/${widget.maxMarks.toStringAsFixed(0)}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.inkSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 6. JOURNAL TOAST (Top-Right, 3px Left Status Rule) ────────────────
enum ToastStatus { pass, pending, critical }

class JournalToastManager {
  static OverlayEntry? _currentEntry;

  static void show(
    BuildContext context,
    String message, {
    String? secondary,
    ToastStatus status = ToastStatus.pass,
  }) {
    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.of(context, rootOverlay: true);

    Color leftRuleColor;
    switch (status) {
      case ToastStatus.pass:
        leftRuleColor = AppColors.statusPassInk;
        break;
      case ToastStatus.pending:
        leftRuleColor = AppColors.statusPendingInk;
        break;
      case ToastStatus.critical:
        leftRuleColor = AppColors.statusCriticalInk;
        break;
    }

    final entry = OverlayEntry(
      builder: (ctx) => _ToastWidget(
        message: message,
        secondary: secondary,
        leftRuleColor: leftRuleColor,
        onDismiss: () {
          _currentEntry?.remove();
          _currentEntry = null;
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final String? secondary;
  final Color leftRuleColor;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    this.secondary,
    required this.leftRuleColor,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 250),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0.2, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));

    _anim.forward();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _anim.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 24,
      right: 24,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 280,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.r2),
                border: const Border(
                  top: BorderSide(color: AppColors.rule, width: 1),
                  right: BorderSide(color: AppColors.rule, width: 1),
                  bottom: BorderSide(color: AppColors.rule, width: 1),
                  left: BorderSide.none,
                ),
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      color: widget.leftRuleColor,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.message,
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.inkPrimary,
                              ),
                            ),
                            if (widget.secondary != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                widget.secondary!,
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: AppColors.inkSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
