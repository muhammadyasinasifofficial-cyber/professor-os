/// ProfessorOS – Course providers.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/course_repository.dart';

final courseRepositoryProvider = Provider((ref) => CourseRepository());

/// List of all courses for the current user.
final courseListProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final authState = ref.watch(authProvider);
  final user = authState.valueOrNull;
  if (user == null) {
    return {'courses': <dynamic>[], 'total': 0};
  }
  final repo = ref.read(courseRepositoryProvider);
  return await repo.listCourses();
});

final studentDashboardProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final authState = ref.watch(authProvider);
  final user = authState.valueOrNull;
  if (user == null) {
    return {
      'courses': <dynamic>[],
      'stats': <String, dynamic>{},
      'upcoming': <dynamic>[],
      'feedback': <dynamic>[],
    };
  }
  final repo = ref.read(courseRepositoryProvider);
  return await repo.getStudentDashboard();
});

/// Single course detail.
final courseDetailProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, courseId) async {
  final authState = ref.watch(authProvider);
  if (authState.valueOrNull == null) {
    return <String, dynamic>{};
  }
  final repo = ref.read(courseRepositoryProvider);
  return await repo.getCourse(courseId);
});

/// Assignments for a course.
final assignmentListProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, courseId) async {
  final authState = ref.watch(authProvider);
  if (authState.valueOrNull == null) {
    return {'assignments': <dynamic>[], 'total': 0};
  }
  final repo = ref.read(courseRepositoryProvider);
  return await repo.listAssignments(courseId);
});

/// Enrolled students for a course.
final courseEnrollmentsProvider = FutureProvider.family<List<dynamic>, int>((ref, courseId) async {
  final repo = ref.read(courseRepositoryProvider);
  return await repo.listEnrollments(courseId);
});

/// CLOs for a course.
final courseClosProvider = FutureProvider.family<List<dynamic>, int>((ref, courseId) async {
  final repo = ref.read(courseRepositoryProvider);
  return await repo.listClos(courseId);
});

/// Uploaded lecture materials for a course (PDF/PPTX/DOCX for RAG).
final courseMaterialsProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, courseId) async {
  final repo = ref.read(courseRepositoryProvider);
  return await repo.getCourseMaterials(courseId);
});
