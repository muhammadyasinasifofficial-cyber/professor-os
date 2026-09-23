import 'dart:convert';

List<Map<String, dynamic>> parseMcqDescription(String? description) {
  if (description == null || description.trim().isEmpty) return [];
  try {
    final decoded = jsonDecode(description);
    if (decoded is! Map || decoded['type'] != 'mcq') return [];
    final rawQuestions = decoded['questions'];
    if (rawQuestions is! List) return [];
    return rawQuestions
        .whereType<Map>()
        .map((question) => Map<String, dynamic>.from(question))
        .where((question) =>
            question['question']?.toString().trim().isNotEmpty == true)
        .toList();
  } catch (_) {
    return [];
  }
}
