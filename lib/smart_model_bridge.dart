import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

class SmartModelBridge {
  static final SmartModelBridge _instance = SmartModelBridge._internal();
  factory SmartModelBridge() => _instance;
  SmartModelBridge._internal();
  
  Map<String, dynamic>? _vocab;
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _learnedPatterns = [];
  Database? _userDatabase;
  List<Map<String, dynamic>> _conversationHistory = [];
  
  Future<void> initialize() async {
    await _loadModelFiles();
    await _initUserDatabase();
    print('🧠 Smart Model Bridge Initialized!');
  }
  
  Future<void> _loadModelFiles() async {
    try {
      // تحميل القاموس الذكي
      final vocabJson = await rootBundle.loadString('assets/models/smart_vocab.json');
      _vocab = json.decode(vocabJson);
      
      // تحميل الإحصائيات
      final statsJson = await rootBundle.loadString('assets/models/model_stats.json');
      _stats = json.decode(statsJson);
      
      // تحميل الأنماط المتعلمة
      final patternsJson = await rootBundle.loadString('assets/models/learned_patterns.json');
      _learnedPatterns = List<Map<String, dynamic>>.from(json.decode(patternsJson));
      
      print('✅ Model loaded: ${_vocab?.length} words, ${_stats?['total_interactions']} interactions');
    } catch (e) {
      print('⚠️ Could not load model files: $e');
      _vocab = {};
    }
  }
  
  Future<void> _initUserDatabase() async {
    _userDatabase = await openDatabase(
      'user_agent_data.db',
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE interactions (
            id INTEGER PRIMARY KEY,
            user_input TEXT,
            agent_response TEXT,
            intent TEXT,
            confidence REAL,
            timestamp INTEGER,
            feedback INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE user_preferences (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
      },
    );
  }
  
  String detectIntent(String text) {
    final lower = text.toLowerCase();
    
    if (lower.contains('مرحبا') || lower.contains('السلام') || lower.contains('اهلا')) {
      return 'greeting';
    }
    if (lower.contains('كيف') || lower.contains('ما') || lower.contains('لماذا')) {
      return 'question';
    }
    if (lower.contains('+') || lower.contains('-') || lower.contains('*') || 
        lower.contains('/') || lower.contains('جمع') || lower.contains('طرح')) {
      return 'calculation';
    }
    if (lower.contains('ذكرني') || lower.contains('تذكير')) {
      return 'reminder';
    }
    if (lower.contains('احفظ') || lower.contains('تذكر') || lower.contains('تعلم')) {
      return 'memory';
    }
    if (lower.contains('حلل') || lower.contains('اقترح') || lower.contains('خطة')) {
      return 'analysis';
    }
    if (lower.contains('وداعا') || lower.contains('باي')) {
      return 'farewell';
    }
    return 'chat';
  }
  
  double calculateConfidence(String text, String intent) {
    final words = text.split(' ');
    int total = 0;
    int matched = 0;
    
    for (var word in words) {
      if (_vocab != null && _vocab!.containsKey(word)) {
        total++;
        final wordData = _vocab![word];
        if (wordData is Map && wordData['type'] == intent) {
          matched++;
        }
      }
    }
    
    if (total == 0) return 0.5;
    return (matched / total).clamp(0.3, 0.95);
  }
  
  String calculate(String expression) {
    try {
      // استخراج الأرقام
      final numbers = RegExp(r'\d+(?:\.\d+)?').allMatches(expression).map((m) => double.parse(m.group(0)!)).toList();
      if (numbers.length < 2) return 'الرجاء كتابة عملية حسابية صحيحة';
      
      if (expression.contains('+')) {
        return '${numbers[0]} + ${numbers[1]} = ${numbers[0] + numbers[1]}';
      } else if (expression.contains('-')) {
        return '${numbers[0]} - ${numbers[1]} = ${numbers[0] - numbers[1]}';
      } else if (expression.contains('*') || expression.contains('×')) {
        return '${numbers[0]} × ${numbers[1]} = ${numbers[0] * numbers[1]}';
      } else if (expression.contains('/') || expression.contains('÷')) {
        if (numbers[1] == 0) return '⚠️ لا يمكن القسمة على صفر';
        return '${numbers[0]} ÷ ${numbers[1]} = ${numbers[0] / numbers[1]}';
      }
    } catch (e) {
      return '❌ خطأ في العملية الحسابية';
    }
    return '❓ لم أفهم العملية الحسابية';
  }
  
  Future<String> generateResponse(String userInput, String intent, double confidence) async {
    final random = Random();
    
    switch (intent) {
      case 'greeting':
        final greetings = [
          'مرحباً بك! 🌟 أنا وكيلك الذكي. كيف أخدمك اليوم؟',
          'أهلاً وسهلاً! 🧠 جاهز لمساعدتك في أي وقت.',
          'السلام عليكم! 💡 لدي ${_vocab?.length ?? 0} كلمة في قاموسي الذكي.'
        ];
        return greetings[random.nextInt(greetings.length)];
      
      case 'question':
        final questions = [
          'سؤال ذكي! 🤔 دعني أفكر...',
          '📚 حسب معرفتي، هذا مثير للاهتمام.',
          '💡 تحليل سؤالك يظهر أموراً مهمة.'
        ];
        return questions[random.nextInt(questions.length)];
      
      case 'calculation':
        return '🧮 **النتيجة**:\n${calculate(userInput)}';
      
      case 'reminder':
        final reminderText = userInput.replaceAll(RegExp(r'ذكرني|تذكير'), '').trim();
        await _saveToDatabase(userInput, 'تم حفظ التذكير', intent, confidence);
        return '✅ **تم حفظ التذكير**\n📝 "${reminderText.isEmpty ? 'تذكير غير محدد' : reminderText}"\n\nسأذكرك في الوقت المناسب!';
      
      case 'memory':
        final memoryText = userInput.replaceAll(RegExp(r'احفظ|تذكر|تعلم'), '').trim();
        await _saveToDatabase(userInput, memoryText, intent, confidence);
        return '💾 **تم الحفظ في الذاكرة**\n"${memoryText.isEmpty ? 'معلومة جديدة' : memoryText}"\n\nسأتذكر هذا دائماً! 🧠';
      
      case 'analysis':
        return '🔍 **تحليل عميق**:\n• تم تحليل مدخلاتك بنجاح\n• مستوى الثقة: ${(confidence * 100).toStringAsFixed(0)}%\n• أقترح متابعة هذا الموضوع';
      
      case 'farewell':
        return '👋 وداعاً! سأكون هنا عندما تحتاجني.\nتذكر أنني أتعلم من كل محادثة!';
      
      default:
        final chatResponses = [
          '🤔 مثير للاهتمام! أخبرني المزيد.',
          '💭 فهمت. كيف يمكنني مساعدتك بشكل أفضل؟',
          '🧠 أنا هنا للاستماع والمساعدة. تفضل!',
          '📚 لدي معرفة في هذا المجال. هل تريد التفاصيل؟'
        ];
        
        var response = chatResponses[random.nextInt(chatResponses.length)];
        
        // إضافة اقتراحات ذكية للمحادثات الطويلة
        if (_conversationHistory.length > 10) {
          response += '\n\n💡 **اقتراح ذكي**: لاحظت أن لدينا محادثة طويلة، هل تريد حفظ ملخصها؟';
        }
        
        return response;
    }
  }
  
  Future<void> _saveToDatabase(String input, String response, String intent, double confidence) async {
    await _userDatabase?.insert('interactions', {
      'user_input': input,
      'agent_response': response,
      'intent': intent,
      'confidence': confidence,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'feedback': 0,
    });
  }
  
  Future<String> process(String userInput) async {
    // حفظ في التاريخ
    _conversationHistory.add({'role': 'user', 'content': userInput, 'time': DateTime.now()});
    
    // تحليل النية
    final intent = detectIntent(userInput);
    final confidence = calculateConfidence(userInput, intent);
    
    // توليد الرد
    final response = await generateResponse(userInput, intent, confidence);
    
    // حفظ الرد
    _conversationHistory.add({'role': 'agent', 'content': response, 'time': DateTime.now()});
    
    // حفظ في قاعدة البيانات
    await _saveToDatabase(userInput, response, intent, confidence);
    
    return response;
  }
  
  Future<List<Map<String, dynamic>>> getHistory() async {
    return await _userDatabase?.query('interactions', orderBy: 'timestamp DESC', limit: 20) ?? [];
  }
  
  Future<void> giveFeedback(int interactionId, int score) async {
    await _userDatabase?.update(
      'interactions',
      {'feedback': score},
      where: 'id = ?',
      whereArgs: [interactionId],
    );
  }
  
  void dispose() {
    _userDatabase?.close();
  }
}
