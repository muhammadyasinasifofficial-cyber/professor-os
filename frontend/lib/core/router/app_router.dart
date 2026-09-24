import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/verify_email_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/auth/providers/auth_provider.dart';

import '../../features/courses/presentation/course_list_screen.dart';
import '../../features/courses/presentation/student_dashboard_screen.dart';
import '../../features/courses/presentation/create_course_screen.dart';
import '../../features/courses/presentation/course_detail_screen.dart';
import '../../features/courses/presentation/assignment_creation_wizard.dart';
import '../../features/courses/presentation/assignment_detail_screen.dart';
import '../../features/courses/presentation/exam_screen.dart';
import '../../features/courses/presentation/quiz_attempt_screen.dart';

import '../../features/analytics/presentation/analytics_dashboard_screen.dart';
import '../../features/courses/presentation/ta_dashboard_screen.dart';

import '../../features/profile/presentation/profile_screen.dart';
import '../../features/admin/presentation/admin_dashboard_screen.dart';

import '../theme/app_theme.dart';
import 'responsive_navigation.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/auth/login',
    refreshListenable: _RouterNotifier(ref),
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      if (authState.isLoading) return null;

      final isAuth = authState.valueOrNull != null;
      final isAuthRoute = state.uri.path.startsWith('/auth');

      if (!isAuth && !isAuthRoute) return '/auth/login';

      if (state.uri.path == '/') {
        if (!isAuth) return '/auth/login';
        if (authState.valueOrNull?['role'] == 'admin') return '/admin';
        return '/courses';
      }

      if (isAuth &&
          isAuthRoute &&
          !state.uri.path.contains('verify-email') &&
          !state.uri.path.contains('reset-password')) {
        if (authState.valueOrNull?['role'] == 'admin') {
          return '/admin';
        }
        return '/courses';
      }

      // Restrict /courses/new to admin and professor
      if (isAuth && state.uri.path == '/courses/new') {
        final role = authState.valueOrNull?['role'] as String?;
        if (role != 'admin' && role != 'professor') return '/courses';
      }

      return null;
    },
    routes: [
      GoRoute(
          path: '/auth/login',
          builder: (context, state) => const LoginScreen()),
      GoRoute(
          path: '/auth/register',
          builder: (context, state) => const RegisterScreen()),
      GoRoute(
        path: '/auth/verify-email',
        builder: (context, state) => VerifyEmailScreen(
          token: state.uri.queryParameters['token'],
          email: state.uri.queryParameters['email'],
        ),
      ),
      GoRoute(
          path: '/auth/forgot-password',
          builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/auth/reset-password',
        builder: (context, state) => ResetPasswordScreen(
          token: state.uri.queryParameters['token'],
        ),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = shouldUseMobileNavigation(constraints.maxWidth);
              if (isMobile) {
                return MobileNavigationShell(
                  currentPath: state.uri.path,
                  child: child,
                );
              }

              return Scaffold(
                backgroundColor: AppColors.bgPage,
                body: Row(
                  children: [
                    _buildLedgerRail(context, state.uri.path, ref),
                    Expanded(child: child),
                  ],
                ),
              );
            },
          );
        },
        routes: [
          GoRoute(
              path: '/dashboard',
              builder: (context, state) => const StudentDashboardScreen()),
          GoRoute(
              path: '/ta-dashboard',
              builder: (context, state) => const TADashboardScreen()),
          GoRoute(
            path: '/courses',
            builder: (context, state) => const CourseListScreen(),
            routes: [
              GoRoute(
                  path: 'new',
                  builder: (context, state) => const CreateCourseScreen()),
              GoRoute(
                path: ':id',
                builder: (context, state) => CourseDetailScreen(
                    courseId: int.parse(state.pathParameters['id']!)),
                routes: [
                  GoRoute(
                      path: 'edit',
                      builder: (context, state) => CreateCourseScreen(
                          courseId: state.pathParameters['id']!)),
                  GoRoute(
                      path: 'analytics',
                      builder: (context, state) => AnalyticsDashboardScreen(
                          courseId: int.parse(state.pathParameters['id']!))),
                  GoRoute(
                      path: 'assignments/new',
                      builder: (context, state) => AssignmentCreationWizard(
                          courseId: int.parse(state.pathParameters['id']!))),
                  GoRoute(
                    path: 'assignments/:aid',
                    builder: (context, state) => AssignmentDetailScreen(
                      courseId: int.parse(state.pathParameters['id']!),
                      assignmentId: int.parse(state.pathParameters['aid']!),
                    ),
                  ),
                  GoRoute(
                    path: 'assignments/:aid/exam',
                    builder: (context, state) {
                      final extra = state.extra as Map<String, dynamic>?;
                      return ExamScreen(
                        courseId: int.parse(state.pathParameters['id']!),
                        assignmentId: int.parse(state.pathParameters['aid']!),
                        assignmentTitle: extra?['title'] ?? 'Exam',
                        assignmentType: extra?['type'] ?? 'text',
                        description: extra?['description'],
                        maxMarks: (extra?['max_marks'] as num?)?.toDouble() ?? 100.0,
                        timeLimitMinutes: extra?['time_limit_minutes'] as int?,
                        randomizeQuestions: extra?['randomize_questions'] as bool? ?? false,
                        showResultsAfter: extra?['show_results_after'] as bool? ?? true,
                      );
                    },
                  ),
                  GoRoute(
                    path: 'quizzes/:qid/attempt',
                    builder: (context, state) {
                      final extra = state.extra as Map<String, dynamic>?;
                      return QuizAttemptScreen(
                        quizId: state.pathParameters['qid']!,
                        quizTitle: extra?['title'] ?? 'AI Assessment Quiz',
                        proctorSessionId: extra?['proctor_session_id'],
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen()),
          GoRoute(
              path: '/admin',
              builder: (context, state) => const AdminDashboardScreen()),
        ],
      ),
    ],
  );
});

Widget _buildLedgerRail(BuildContext context, String currentPath, Ref ref) {
  final user = ref.watch(authProvider).valueOrNull;
  final role = user?['role'] as String? ?? 'student';
  final isAdmin = role == 'admin';
  final isStudent = role == 'student';
  final isTA = role == 'ta';

  return Container(
    width: 72,
    decoration: const BoxDecoration(
      color: AppColors.bgMargin,
      border: Border(right: BorderSide(color: AppColors.marginRule, width: 1)),
    ),
    child: Column(
      children: [
        const SizedBox(height: 24),
        // App icon at the top
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.signal,
            borderRadius: BorderRadius.circular(8),
          ),
          child:
              const Icon(Icons.school_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 32),

        if (isStudent)
          _RailItem(
              icon: Icons.dashboard_rounded,
              path: '/dashboard',
              currentPath: currentPath),
        if (isTA)
          _RailItem(
              icon: Icons.grading_rounded,
              path: '/ta-dashboard',
              currentPath: currentPath),
        _RailItem(
            icon: Icons.menu_book_rounded,
            path: '/courses',
            currentPath: currentPath),
        if (isAdmin)
          _RailItem(
              icon: Icons.admin_panel_settings_rounded,
              path: '/admin',
              currentPath: currentPath),
        _RailItem(
            icon: Icons.person_rounded,
            path: '/profile',
            currentPath: currentPath),

        const Spacer(),

        IconButton(
          icon: const Icon(Icons.logout_rounded, color: AppColors.inkSecondary),
          tooltip: 'Sign Out',
          onPressed: () => ref.read(authProvider.notifier).logout(),
        ),
        const SizedBox(height: 24),
      ],
    ),
  );
}

class _RailItem extends StatelessWidget {
  final IconData icon;
  final String path;
  final String currentPath;

  const _RailItem(
      {required this.icon, required this.path, required this.currentPath});

  @override
  Widget build(BuildContext context) {
    final selected = currentPath.startsWith(path);
    return Tooltip(
      message: path.replaceAll('/', '').toUpperCase(),
      child: GestureDetector(
        onTap: () => context.go(path),
        child: Container(
          width: 72,
          height: 56,
          decoration: BoxDecoration(
            color: selected ? AppColors.bgActive : Colors.transparent,
            border: Border(
                left: BorderSide(
                    color: selected ? AppColors.signal : Colors.transparent,
                    width: 3)),
          ),
          child: Icon(
            icon,
            color: selected ? AppColors.signal : AppColors.inkSecondary,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}
