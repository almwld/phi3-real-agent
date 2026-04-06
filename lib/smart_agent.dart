import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'model_path_manager.dart';

class SmartAgent {
  static final SmartAgent _instance = SmartAgent._internal();
  factory SmartAgent() => _instance;
  SmartAgent._internal();

  Database? _db;
  List<Map<String, dynamic>> _history = [];
  bool _suggestedSummary = false; // منع تكرار الاقتراح

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _db = await openDatabase(
      '${dir.path}/agent_memory.db',
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages (
            id INTEGER PRIMARY KEY,
            role TEXT,
            content TEXT,
            timestamp INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE summary_saved (
            id INTEGER PRIMARY KEY,
            saved INTEGER
          )
        ''');
      },
    );
    await _loadHistory();
  }

  Future<void> _loadHistory() async {
    final result = await _db?.query('messages', orderBy: 'timestamp ASC');
    if (result != null) {
      _history = result;
    }
  }

  Future<void> addMessage(String role, String content) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db?.insert('messages', {
      'role': role,
      'content': content,
      'timestamp': now,
    });
    _history.add({'role': role, 'content': content, 'timestamp': now});
  }

  Future<String> respond(String userInput) async {
    await addMessage('user', userInput);

    String response;
    final lower = userInput.toLowerCase();

    if (lower.contains('مرحبا') || lower.contains('السلام')) {
      response = 'مرحباً! 👋 أنا وكيل Phi-3 الذكي. كيف أخدمك اليوم؟';
    } else if (lower.contains('+') || lower.contains('-') || lower.contains('*') || lower.contains('/')) {
      response = _calculate(userInput);
    } else if (lower.contains('احفظ الملخص')) {
      response = await _saveSummary();
    } else if (lower.contains('تذكر') || lower.contains('احفظ')) {
      response = await _remember(userInput);
    } else {
      response = _smartChat(userInput);
    }

    await addMessage('agent', response);
    return response;
  }

  String _calculate(String input) {
    try {
      final numbers = RegExp(r'\d+(?:\.\d+)?').allMatches(input).map((m) => double.parse(m.group(0)!)).toList();
      if (numbers.length < 2) return 'الرجاء كتابة عملية حسابية صحيحة';
      if (input.contains('+')) return '🧮 ${numbers[0]} + ${numbers[1]} = ${numbers[0] + numbers[1]}';
      if (input.contains('-')) return '🧮 ${numbers[0]} - ${numbers[1]} = ${numbers[0] - numbers[1]}';
      if (input.contains('*')) return '🧮 ${numbers[0]} × ${numbers[1]} = ${numbers[0] * numbers[1]}';
      if (input.contains('/')) {
        if (numbers[1] == 0) return '⚠️ لا يمكن القسمة على صفر';
        return '🧮 ${numbers[0]} ÷ ${numbers[1]} = ${numbers[0] / numbers[1]}';
      }
    } catch (e) {
      return '❌ خطأ في العملية الحسابية';
    }
    return '❓ لم أفهم العملية';
  }

  Future<String> _saveSummary() async {
    final count = _history.length;
    if (count < 4) {
      return 'لا يوجد محادثة كافية لحفظ ملخص. تحدث معي قليلاً ثم اطلب الحفظ.';
    }
    // توليد ملخص بسيط (أول 3 رسائل)
    final summary = _history.take(3).map((m) => '${m['role']}: ${m['content']}').join('\n');
    await _db?.insert('summary_saved', {'saved': 1});
    _suggestedSummary = true;
    return '✅ تم حفظ ملخص المحادثة:\n$summary\n\nيمكنك الرجوع إليه لاحقاً.';
  }

  Future<String> _remember(String input) async {
    final text = input.replaceAll(RegExp(r'تذكر|احفظ'), '').trim();
    await _db?.insert('messages', {
      'role': 'system',
      'content': 'معلومة محفوظة: $text',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    return '📝 تم تذكر: "$text"';
  }

  String _smartChat(String input) {
    final randomResponses = [
      '🤔 مثير للاهتمام! أخبرني المزيد.',
      '💭 فهمت. كيف يمكنني مساعدتك بشكل أفضل؟',
      '🧠 أنا هنا للاستماع والمساعدة. تفضل!',
      '📚 لدي معرفة في هذا المجال. هل تريد التفاصيل؟'
    ];
    int index = _history.length % randomResponses.length;
    return randomResponses[index];
  }

  Future<bool> shouldSuggestSummary() async {
    if (_suggestedSummary) return false;
    final count = _history.where((m) => m['role'] == 'user').length;
    return count >= 5; // اقتراح بعد 5 رسائل
  }

  void dispose() {
    _db?.close();
  }
}
