import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'notification_service.dart';
import 'model_path_manager.dart';

class SmartAgent {
  static final SmartAgent _instance = SmartAgent._internal();
  factory SmartAgent() => _instance;
  SmartAgent._internal();

  Database? _db;
  List<Map<String, dynamic>> _history = [];
  bool _suggestedSummary = false;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _db = await openDatabase(
      join(dir.path, 'agent_memory.db'),
      version: 2,
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
          CREATE TABLE reminders (
            id INTEGER PRIMARY KEY,
            text TEXT,
            scheduled_time INTEGER,
            triggered INTEGER
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('CREATE TABLE reminders (id INTEGER PRIMARY KEY, text TEXT, scheduled_time INTEGER, triggered INTEGER)');
        }
      },
    );
    await _loadHistory();
    await _checkReminders();
  }

  Future<void> _loadHistory() async {
    final result = await _db?.query('messages', orderBy: 'timestamp ASC');
    if (result != null) _history = result;
  }

  Future<void> _checkReminders() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final reminders = await _db?.query('reminders', where: 'triggered = 0 AND scheduled_time <= ?', whereArgs: [now]);
    if (reminders != null) {
      for (var r in reminders) {
        await NotificationService.showReminder('تذكير', r['text'], DateTime.fromMillisecondsSinceEpoch(r['scheduled_time']));
        await _db?.update('reminders', {'triggered': 1}, where: 'id = ?', whereArgs: [r['id']]);
      }
    }
  }

  Future<void> addMessage(String role, String content) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db?.insert('messages', {'role': role, 'content': content, 'timestamp': now});
    _history.add({'role': role, 'content': content, 'timestamp': now});
  }

  Future<String> respond(String userInput) async {
    await addMessage('user', userInput);
    String response;
    final lower = userInput.toLowerCase();

    if (lower.contains('مرحبا') || lower.contains('السلام')) {
      response = 'مرحباً! 👋 أنا وكيل Phi-3 الذكي. يمكنك التحدث أو الكتابة.';
    } else if (lower.contains('+') || lower.contains('-') || lower.contains('*') || lower.contains('/')) {
      response = _calculate(userInput);
    } else if (lower.contains('احفظ الملخص')) {
      response = await _saveSummary();
    } else if (lower.contains('ذكرني في') || lower.contains('تذكير')) {
      response = await _scheduleReminder(userInput);
    } else if (lower.contains('ابحث في المحادثات')) {
      response = await _searchHistory(userInput);
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
    if (_history.length < 4) return 'لا توجد محادثة كافية للحفظ.';
    final summary = _history.take(3).map((m) => '${m['role']}: ${m['content']}').join('\n');
    _suggestedSummary = true;
    return '✅ تم حفظ الملخص:\n$summary';
  }

  Future<String> _scheduleReminder(String input) async {
    final regExp = RegExp(r'في (\d{1,2}):(\d{2})');
    final match = regExp.firstMatch(input);
    if (match == null) return 'يرجى تحديد الوقت بصيغة "ذكرني في 15:30 لأتصل بأمي"';
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final now = DateTime.now();
    DateTime scheduled = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));
    final reminderText = input.replaceAll(RegExp(r'ذكرني في \d{1,2}:\d{2}'), '').trim();
    await _db?.insert('reminders', {
      'text': reminderText,
      'scheduled_time': scheduled.millisecondsSinceEpoch,
      'triggered': 0,
    });
    await NotificationService.showReminder('تذكير مجدول', reminderText, scheduled);
    return '✅ تم جدولة تذكير: "$reminderText" في ${scheduled.hour}:${scheduled.minute.toString().padLeft(2, '0')}';
  }

  Future<String> _searchHistory(String input) async {
    final keyword = input.replaceAll('ابحث في المحادثات', '').trim();
    if (keyword.isEmpty) return 'اكتب ما تبحث عنه بعد الأمر.';
    final results = _history.where((msg) => msg['content'].toLowerCase().contains(keyword.toLowerCase())).toList();
    if (results.isEmpty) return 'لا توجد نتائج لـ "$keyword"';
    final output = results.take(3).map((m) => '${m['role']}: ${m['content']}').join('\n');
    return '🔍 نتائج البحث:\n$output';
  }

  String _smartChat(String input) {
    final responses = [
      '🤔 مثير للاهتمام! أخبرني المزيد.',
      '💭 فهمت. كيف يمكنني مساعدتك بشكل أفضل؟',
      '🧠 أنا هنا للاستماع والمساعدة. تفضل!',
      '📚 لدي معرفة في هذا المجال. هل تريد التفاصيل؟'
    ];
    int index = _history.length % responses.length;
    return responses[index];
  }

  Future<bool> shouldSuggestSummary() async {
    if (_suggestedSummary) return false;
    final userCount = _history.where((m) => m['role'] == 'user').length;
    return userCount >= 5;
  }

  Future<String> exportChat() async {
    final dir = await getExternalStorageDirectory();
    final file = File('${dir?.path}/chat_export_${DateTime.now().millisecondsSinceEpoch}.txt');
    final content = _history.map((m) => '${m['role']} (${DateTime.fromMillisecondsSinceEpoch(m['timestamp'])}): ${m['content']}').join('\n');
    await file.writeAsString(content);
    return file.path;
  }

  void dispose() {
    _db?.close();
  }
}
