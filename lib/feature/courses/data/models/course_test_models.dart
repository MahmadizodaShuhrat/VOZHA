/// Data models for course test JSON parsing.
/// Mirrors Unity C# classes: TestData, TestSection, TestQuestion, TestOption.


class CourseTestData {
  final String testTitle;
  final String? workBookTitle;
  final String? language;
  final List<CourseTestSection> sections;
  final String currentPath;

  CourseTestData({
    required this.testTitle,
    this.workBookTitle,
    this.language,
    required this.sections,
    required this.currentPath,
  });

  factory CourseTestData.fromJson(
    Map<String, dynamic> json,
    String currentPath,
  ) {
    return CourseTestData(
      testTitle: json['test_title'] ?? '',
      workBookTitle: json['workbook_title'],
      language: json['language'],
      sections: (json['sections'] as List<dynamic>? ?? [])
          .map((s) => CourseTestSection.fromJson(s as Map<String, dynamic>))
          .toList(),
      currentPath: currentPath,
    );
  }
}

class CourseTestSection {
  final String id;
  final String title;
  final List<CourseTestQuestion> questions;

  CourseTestSection({
    required this.id,
    required this.title,
    required this.questions,
  });

  factory CourseTestSection.fromJson(Map<String, dynamic> json) {
    return CourseTestSection(
      id: (json['id'] ?? '').toString(),
      title: json['title'] ?? '',
      questions: (json['questions'] as List<dynamic>? ?? [])
          .map((q) => CourseTestQuestion.fromJson(q as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CourseTestQuestion {
  final String id;
  final String title;
  final String type;
  final String? parameter;
  final String? promptAdditional;
  final String? textFileName;
  final String? spriteName;
  final String? audioName;
  final List<CourseTestOption> dataSources;
  final List<String> wordBank;
  final List<String> phraseBank;

  CourseTestQuestion({
    required this.id,
    required this.title,
    required this.type,
    this.parameter,
    this.promptAdditional,
    this.textFileName,
    this.spriteName,
    this.audioName,
    required this.dataSources,
    required this.wordBank,
    required this.phraseBank,
  });

  factory CourseTestQuestion.fromJson(Map<String, dynamic> json) {
    return CourseTestQuestion(
      id: (json['id'] ?? '').toString(),
      title: json['title'] ?? '',
      type: json['type'] ?? '',
      parameter: json['paratemeter'],
      promptAdditional: json['prompt_additional'],
      textFileName: json['text_file_name'],
      spriteName: json['sprite'],
      audioName: json['audio'],
      dataSources: (json['data_source'] as List<dynamic>? ?? [])
          .map((o) => CourseTestOption.fromJson(o as Map<String, dynamic>))
          .toList(),
      wordBank: List<String>.from(json['word_bank'] ?? []),
      phraseBank: List<String>.from(json['phrase_bank'] ?? []),
    );
  }
}

class CourseTestOption {
  final String text;
  final int maxLength;
  final String? correctAnswer;
  final List<String> correctAnswers;
  final List<OptionBlank> blanks;
  final List<String> answers;
  final List<String> wordBank;
  final String? spriteName;
  final String? audioName;
  // Categorize game
  final String? category;
  final List<String> items;
  // Crossword
  final int? width;
  final int? height;
  final String? empty;
  final List<String> grid;
  final List<CrosswordWord> words;

  CourseTestOption({
    required this.text,
    this.maxLength = 0,
    this.correctAnswer,
    this.correctAnswers = const [],
    this.blanks = const [],
    this.answers = const [],
    this.wordBank = const [],
    this.spriteName,
    this.audioName,
    this.category,
    this.items = const [],
    this.width,
    this.height,
    this.empty,
    this.grid = const [],
    this.words = const [],
  });

  factory CourseTestOption.fromJson(Map<String, dynamic> json) {
    return CourseTestOption(
      text: json['text'] ?? '',
      maxLength: json['max_length'] ?? 0,
      correctAnswer: json['correct_answer'],
      correctAnswers: List<String>.from(json['correct_answers'] ?? []),
      blanks: (json['blanks'] as List<dynamic>? ?? [])
          .map((b) => OptionBlank.fromJson(b as Map<String, dynamic>))
          .toList(),
      answers: List<String>.from(json['answers'] ?? []),
      wordBank: List<String>.from(json['word_bank'] ?? []),
      spriteName: json['sprite'] ?? '',
      audioName: json['audio'] ?? '',
      category: json['category'],
      items: List<String>.from(json['items'] ?? []),
      width: json['width'],
      height: json['height'],
      empty: json['empty'],
      grid: List<String>.from(json['grid'] ?? []),
      words: (json['words'] as List<dynamic>? ?? [])
          .map((w) => CrosswordWord.fromJson(w as Map<String, dynamic>))
          .toList(),
    );
  }
}

class OptionBlank {
  final List<String> correctAnswers;
  final String? correctAnswer;

  OptionBlank({this.correctAnswers = const [], this.correctAnswer});

  factory OptionBlank.fromJson(Map<String, dynamic> json) {
    return OptionBlank(
      correctAnswers: List<String>.from(json['correct_answers'] ?? []),
      correctAnswer: json['correct_answer'],
    );
  }
}

class CrosswordWord {
  final String word;
  final String direction;
  final CrosswordPosition start;
  final List<CrosswordLetter> letters;
  final String? question;
  final String? sprite;

  CrosswordWord({
    required this.word,
    required this.direction,
    required this.start,
    required this.letters,
    this.question,
    this.sprite,
  });

  factory CrosswordWord.fromJson(Map<String, dynamic> json) {
    return CrosswordWord(
      word: json['word'] ?? '',
      direction: json['direction'] ?? '',
      start: CrosswordPosition.fromJson(
        json['start'] as Map<String, dynamic>? ?? {},
      ),
      letters: (json['letters'] as List<dynamic>? ?? [])
          .map((l) => CrosswordLetter.fromJson(l as Map<String, dynamic>))
          .toList(),
      question: json['question'],
      sprite: json['sprite'],
    );
  }
}

class CrosswordPosition {
  final int x;
  final int y;

  CrosswordPosition({this.x = 0, this.y = 0});

  factory CrosswordPosition.fromJson(Map<String, dynamic> json) {
    return CrosswordPosition(x: json['x'] ?? 0, y: json['y'] ?? 0);
  }
}

class CrosswordLetter {
  final String char;
  final int x;
  final int y;

  CrosswordLetter({required this.char, this.x = 0, this.y = 0});

  factory CrosswordLetter.fromJson(Map<String, dynamic> json) {
    return CrosswordLetter(
      char: json['char'] ?? '',
      x: json['x'] ?? 0,
      y: json['y'] ?? 0,
    );
  }
}
