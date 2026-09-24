import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class ProfCard extends StatefulWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final bool leadingStripe;

  const ProfCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.onTap,
    this.leadingStripe = false,
  });

  @override
  State<ProfCard> createState() => _ProfCardState();
}

class _ProfCardState extends State<ProfCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isClickable = widget.onTap != null;
    final bgColor = _isHovered && isClickable ? AppColors.bgHover : AppColors.bgCard;
    final borderColor = _isHovered && isClickable ? AppColors.borderStrong : AppColors.marginRule;

    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.r6),
        border: Border(
          top: BorderSide(color: borderColor, width: 1),
          right: BorderSide(color: borderColor, width: 1),
          bottom: BorderSide(color: borderColor, width: 1),
          left: BorderSide(
            color: widget.leadingStripe ? AppColors.signal : borderColor,
            width: widget.leadingStripe ? 4 : 1,
          ),
        ),
        boxShadow: AppShadows.card,
      ),
      child: Padding(
        padding: widget.padding,
        child: widget.child,
      ),
    );

    if (isClickable) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: card,
        ),
      );
    }
    
    return card;
  }
}
