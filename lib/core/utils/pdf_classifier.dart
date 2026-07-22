class PdfClassificationResult {
  final String? course;
  final String? semester;
  final String? title;
  final String? subject;
  final String? type; // 'Notes' or 'Paper'
  final String? year;

  PdfClassificationResult({
    this.course,
    this.semester,
    this.title,
    this.subject,
    this.type,
    this.year,
  });
}

class PdfClassifier {
  /// Extracts the course, semester, title, subject, type, and year from a filename using heuristics.
  static PdfClassificationResult classifyFromFilename(String filename) {
    String? course;
    String? semester;
    String? title;
    String? subject;
    String? type;
    String? year;

    // Remove extension
    String nameWithoutExt = filename.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    
    // Split into tokens
    List<String> tokens = nameWithoutExt.split(RegExp(r'[_\-\s]+'));
    List<String> unusedTokens = [];

    final lowerName = filename.toLowerCase();

    // 1. Detect Course
    if (lowerName.contains('bca')) course = 'BCA';
    else if (lowerName.contains('bcs') || lowerName.contains('bsc')) course = 'BSc'; 
    else if (lowerName.contains('mca')) course = 'MCA';
    else if (lowerName.contains('mcs')) course = 'MCS';
    else if (lowerName.contains('bba')) course = 'BBA';
    else if (lowerName.contains('bcom') || lowerName.contains('b.com')) course = 'BCom';
    else if (lowerName.contains('upsc')) course = 'UPSC';
    else if (lowerName.contains('mpsc')) course = 'MPSC';
    else if (lowerName.contains('eng') || lowerName.contains('engineering')) course = 'Engineering';

    // 2. Detect Semester
    final semRegex = RegExp(r'sem(ester)?\s*[_.-]?\s*(\d)', caseSensitive: false);
    final semMatch = semRegex.firstMatch(lowerName);
    if (semMatch != null) {
      final semNumber = int.tryParse(semMatch.group(2) ?? '');
      if (semNumber != null && semNumber > 0 && semNumber <= 8) {
        semester = 'Semester $semNumber';
      }
    }

    // 3. Detect Type (Notes vs PYQ)
    if (lowerName.contains('pyq') || lowerName.contains('paper') || lowerName.contains('question') || lowerName.contains('exam')) {
      type = 'Paper';
    } else if (lowerName.contains('notes') || lowerName.contains('note') || lowerName.contains('study')) {
      type = 'Notes';
    }

    // 4. Detect Year
    final yearRegex = RegExp(r'(20\d{2})');
    final yearMatch = yearRegex.firstMatch(lowerName);
    if (yearMatch != null) {
      year = yearMatch.group(1);
    }

    // 5. Extract Subject (Process tokens)
    for (var token in tokens) {
      final lowerToken = token.toLowerCase();
      
      // Skip known tokens
      if (['bca', 'bcs', 'bsc', 'mca', 'mcs', 'bba', 'bcom', 'upsc', 'mpsc', 'eng', 'engineering'].contains(lowerToken)) continue;
      if (lowerToken.startsWith('sem')) continue; // Very basic check
      if (['pyq', 'paper', 'notes', 'note', 'question', 'exam', 'study'].contains(lowerToken)) continue;
      if (RegExp(r'^20\d{2}$').hasMatch(lowerToken)) continue;
      
      // Handle known abbreviations
      if (lowerToken == 'os') {
        unusedTokens.add('Operating System');
        continue;
      }
      if (lowerToken == 'dbms') {
        unusedTokens.add('DBMS');
        continue;
      }
      if (lowerToken == 'java') {
        unusedTokens.add('Java');
        continue;
      }
      if (lowerToken == 'history') {
        unusedTokens.add('History');
        continue;
      }
      if (lowerToken == 'marketing') {
        unusedTokens.add('Marketing');
        continue;
      }
      
      unusedTokens.add(token);
    }

    if (unusedTokens.isNotEmpty) {
      subject = unusedTokens.join(' ');
      
      // Clean up subject format
      subject = subject!.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '').trim();
    }

    // 6. Generate Title
    if (type == 'Notes') {
      if (subject != null && subject!.isNotEmpty) {
        title = '$subject Notes';
      } else {
        title = 'Study Notes';
      }
    } else if (type == 'Paper') {
      if (subject != null && year != null) {
        title = '$subject $year PYQ';
      } else if (subject != null) {
        title = '$subject PYQ';
      } else {
        title = 'Question Paper';
      }
    }

    return PdfClassificationResult(
      course: course,
      semester: semester,
      title: title,
      subject: subject,
      type: type,
      year: year,
    );
  }
}
