import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/providers/auth_provider.dart';

class JournalScaffold extends ConsumerWidget {
  final String currentPath;
  final Widget workspace;
  final Widget? annotationColumn;
  final bool showAnnotation;

  const JournalScaffold({
    super.key,
    required this.currentPath,
    required this.workspace,
    this.annotationColumn,
    this.showAnnotation = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 768;
        final bool showAnnotationPanel =
            showAnnotation && constraints.maxWidth >= 1024 && annotationColumn != null;

        if (isMobile) {
          return Scaffold(
            backgroundColor: AppColors.canvas,
            appBar: AppBar(
              backgroundColor: AppColors.canvas,
              elevation: 0,
              title: Text(
                'ProfessorOS',
                style: GoogleFonts.dmSerifDisplay(
                  fontSize: 18,
                  color: AppColors.inkPrimary,
                ),
              ),
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(1),
                child: Divider(height: 1, color: AppColors.rule),
              ),
            ),
            drawer: _buildMobileDrawer(context, ref),
            body: workspace,
          );
        }

        return Scaffold(
          backgroundColor: AppColors.canvas,
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── COL 1–2: Navigation Column (~180px) ───────────────────
              SizedBox(
                width: constraints.maxWidth >= 1280 ? 200 : 160,
                child: _JournalNavColumn(currentPath: currentPath),
              ),

              // Divider between Nav and Workspace
              Container(width: 1, color: AppColors.rule),

              // ── COL 3–8: Primary Workspace ────────────────────────────
              Expanded(
                child: workspace,
              ),

              // ── COL 9: 1px Rule Column & COL 10–12: Annotation Column ─
              if (showAnnotationPanel) ...[
                Container(
                  width: 1.0,
                  color: AppColors.ruleStrong,
                ),
                SizedBox(
                  width: 240,
                  child: Container(
                    color: AppColors.surface,
                    child: annotationColumn!,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileDrawer(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    final role = user?['role'] as String? ?? 'student';

    return Drawer(
      backgroundColor: AppColors.canvas,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'ProfessorOS',
                style: GoogleFonts.dmSerifDisplay(
                  fontSize: 22,
                  color: AppColors.inkPrimary,
                ),
              ),
            ),
            const Divider(color: AppColors.rule, height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  if (role == 'student')
                    _MobileDrawerItem(
                      label: 'Dashboard',
                      path: '/dashboard',
                      currentPath: currentPath,
                    ),
                  if (role == 'ta')
                    _MobileDrawerItem(
                      label: 'Grading Queue',
                      path: '/ta-dashboard',
                      currentPath: currentPath,
                    ),
                  _MobileDrawerItem(
                    label: 'Courses',
                    path: '/courses',
                    currentPath: currentPath,
                  ),
                  if (role == 'admin')
                    _MobileDrawerItem(
                      label: 'Admin Panel',
                      path: '/admin',
                      currentPath: currentPath,
                    ),
                  _MobileDrawerItem(
                    label: 'Profile & Settings',
                    path: '/profile',
                    currentPath: currentPath,
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.rule, height: 1),
            ListTile(
              title: Text(
                'Sign out',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: AppColors.statusCriticalInk,
                ),
              ),
              onTap: () => ref.read(authProvider.notifier).logout(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileDrawerItem extends StatelessWidget {
  final String label;
  final String path;
  final String currentPath;

  const _MobileDrawerItem({
    required this.label,
    required this.path,
    required this.currentPath,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = currentPath.startsWith(path);
    return ListTile(
      title: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          color: isSelected ? AppColors.inkAccent : AppColors.inkPrimary,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        context.go(path);
      },
    );
  }
}

// ── NAVIGATION COLUMN IMPLEMENTATION (Col 1–2) ────────────────────────
class _JournalNavColumn extends ConsumerWidget {
  final String currentPath;

  const _JournalNavColumn({required this.currentPath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    final role = user?['role'] as String? ?? 'student';
    final name = user?['full_name'] as String? ?? 'User';
    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join().toUpperCase()
        : 'OS';

    return Container(
      color: AppColors.canvas,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Term Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Spring 2027'.toUpperCase(),
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: AppColors.inkGhost,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Wordmark
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'ProfessorOS',
              style: GoogleFonts.dmSerifDisplay(
                fontSize: 16,
                color: AppColors.inkPrimary,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Section 1: Navigation
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'NAVIGATION',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: AppColors.inkGhost,
              ),
            ),
          ),
          const SizedBox(height: 8),

          if (role == 'student')
            _JournalNavItem(
              label: 'Dashboard',
              path: '/dashboard',
              currentPath: currentPath,
            ),
          if (role == 'ta')
            _JournalNavItem(
              label: 'Grading Queue',
              path: '/ta-dashboard',
              currentPath: currentPath,
            ),
          _JournalNavItem(
            label: 'Courses',
            path: '/courses',
            currentPath: currentPath,
          ),
          if (role == 'admin')
            _JournalNavItem(
              label: 'Admin Panel',
              path: '/admin',
              currentPath: currentPath,
            ),
          _JournalNavItem(
            label: 'Profile & Settings',
            path: '/profile',
            currentPath: currentPath,
          ),

          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(color: AppColors.rule, height: 1),
          ),
          const SizedBox(height: 16),

          // Section 2: TODAY Queue
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'STATUS',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: AppColors.inkGhost,
              ),
            ),
          ),
          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.statusPassInk,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI Services Online',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.inkSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Bottom User Profile & Sign Out
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(color: AppColors.rule, height: 1),
          ),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(AppRadius.r4),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.inkSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.inkPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        role.toUpperCase(),
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkGhost,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => ref.read(authProvider.notifier).logout(),
                child: Text(
                  'Sign out',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.inkGhost,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JournalNavItem extends StatelessWidget {
  final String label;
  final String path;
  final String currentPath;

  const _JournalNavItem({
    required this.label,
    required this.path,
    required this.currentPath,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSelected = currentPath.startsWith(path);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go(path),
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surfaceMid : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: isSelected ? AppColors.inkPrimary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isSelected ? AppColors.inkPrimary : AppColors.inkSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
