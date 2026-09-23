import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:professor_os/features/courses/utils/mcq_parser.dart';

void main() {
  test('parses quiz-builder MCQ JSON into student questions', () {
    final questions = parseMcqDescription(jsonEncode({
      'type': 'mcq',
      'questions': [
        {
          'question': 'What is OBE?',
          'options': ['Outcome based education', 'Online backup engine'],
          'correctAnswer': 0,
        },
      ],
    }));

    expect(questions, hasLength(1));
    expect(questions.single['question'], 'What is OBE?');
    expect(questions.single['options'],
        ['Outcome based education', 'Online backup engine']);
    expect(questions.single['correctAnswer'], 0);
  });

  test('returns no questions for ordinary assignment text', () {
    expect(parseMcqDescription('Write a short answer.'), isEmpty);
  });
}
