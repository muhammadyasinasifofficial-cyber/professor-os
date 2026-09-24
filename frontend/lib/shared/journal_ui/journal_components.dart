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

    // Hover inverts: fill ↔ outline (Print design pattern)
    final Color bgColor = _isHovered && !disabled
        ? Colors.transparent
        : AppColors.inkPrimary;
    final Color textColor = _isHovered && !disabled
        ? AppColors.inkPrimary
        : AppColors.canvas;
    final Border border = Border.all(
      color: _isHovered && !disabled ? AppColors.inkPrimary : Colors.transparent,
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
          scale: _isPressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 80),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            height: 38,
            width: widget.width,
            padding: const EdgeInsets.symmetric(horizontal: 18),
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
                fontWeight: FontWeight.w500,
                color: widget.isLoading ? AppColors.inkGhost : textColor,
              ),
              overflow: TextOverflow.ellipsis,
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
          height: 38,
          width: widget.width,
          padding: const EdgeInsets.symmetric(horizontal: 18),
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

    switch (type) {
      case StampType.pass:
        bg = AppColors.statusPassBg;
        ink = AppColors.statusPassInk;
        break;
      case StampType.pending:
        bg = AppColors.statusPendingBg;
        ink = AppColors.statusPendingInk;
        break;
      case StampType.critical:
        bg = AppColors.statusCriticalBg;
        ink = AppColors.statusCriticalInk;
        break;
      case StampType.neutral:
        bg = AppColors.surfaceMid;
        ink = AppColors.inkSecondary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.r2),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: ink,
          height: 1.1,
        ),
      ),
    );
  }
}

// ── 5. SCORE INPUT (Underline-only, JetBrains Mono, AI pre-fill) ───────
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
  late bool _suggested;

  @override
  void initState() {
    super.initState();
    _suggested = widget.isAiSuggested;
    _ctrl = TextEditingController(
      text: widget.initialScore != null ? widget.initialScore!.toStringAsFixed(1).replaceAll('.0', '') : '',
    );
  }

  @override
  void didUpdateWidget(JournalScoreInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialScore != oldWidget.initialScore) {
      _ctrl.text = widget.initialScore != null ? widget.initialScore!.toStringAsFixed(1).replaceAll('.0', '') : '';
      _suggested = widget.isAiSuggested;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: TextField(
        controller: _ctrl,
        focusNode: widget.focusNode,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.right,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: _suggested ? AppColors.inkGhost : AppColors.inkPrimary,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          border: InputBorder.none,
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.rule, width: 1),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.inkAccent, width: 1.5),
          ),
          hintText: '—',
          hintStyle: GoogleFonts.jetBrainsMono(color: AppColors.inkGhost),
        ),
        onChanged: (val) {
          if (_suggested) {
            setState(() => _suggested = false);
          }
          final parsed = double.tryParse(val.trim());
          widget.onChanged(parsed);
        },
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
