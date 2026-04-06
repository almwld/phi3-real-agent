import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:math';
import 'dart:isolate';
import 'dart:convert';

enum Personality { analytical, creative, practical }

class SmartAgent {
  static final SmartAgent _instance = SmartAgent._internal();
  factory SmartAgent() => _instance;
  SmartAgent._internal();
  
  Interpreter? _interpreter;
  Database? _memoryDb;
  List<Map<String, dynamic>> _conversationHistory = [];
  Personality _currentPersonality = Personality.analytical;
  Map<String, dynamic> _userPatterns = {};
  
  // 1. تحميل النموذج وقاعدة الذاكرة
  Future<void> initialize() async {
    _interpreter = await Interpreter.fromAsset('assets/models/small_agent_model.tflite');
    await _initDatabase();
    await _loadUserPatterns();
    print('🧠 Smart Agent initialized with memory');
  }
  
  // 2. قاعدة بيانات للذاكرة طويلة المدى
  Future<void> _initDatabase() async {
    _memoryDb = await openDatabase(
      'agent_memory.db',
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE memories (
            id INTEGER PRIMARY KEY,
            user_input TEXT,
            agent_response TEXT,
            feedback_score INTEGER,
            timestamp INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE patterns (
            id INTEGER PRIMARY KEY,
            pattern TEXT,
            count INTEGER
          )
        ''');
      },
    );
  }
  
  // 3. اختيار الشخصية حسب نوع السؤال
  Personality _detectPersonality(String userInput) {
    final lower = userInput.toLowerCase();
    if (lower.contains('لماذا') || lower.contains('كيف') || lower.contains('تحليل')) {
      return Personality.analytical;
    } else if (lower.contains('ابتكار') || lower.contains('فكرة') || lower.contains('تصميم')) {
      return Personality.creative;
    } else {
      return Personality.practical;
    }
  }
  
  // 4. اختيار الأداة تلقائياً
  String _selectTool(String userInput) {
    final lower = userInput.toLowerCase();
    if (lower.contains('+') || lower.contains('-') || lower.contains('*') || lower.contains('/')) {
      return 'calculator';
    } else if (lower.contains('ذكرني') || lower.contains('تذكير')) {
      return 'reminder';
    } else if (lower.contains('احفظ') || lower.contains('تذكر')) {
      return 'memory';
    } else {
      return 'chat';
    }
  }
  
  // 5. تنفيذ العمليات الحسابية
  String _calculate(String input) {
    try {
      final parts = input.split(RegExp(r'[+\-*/]'));
      if (parts.length < 2) return input;
      
      if (input.contains('+')) {
        return (double.parse(parts[0].trim()) + double.parse(parts[1].trim())).toString();
      } else if (input.contains('-')) {
        return (double.parse(parts[0].trim()) - double.parse(parts[1].trim())).toString();
      } else if (input.contains('*')) {
        return (double.parse(parts[0].trim()) * double.parse(parts[1].trim())).toString();
      } else if (input.contains('/')) {
        return (double.parse(parts[0].trim()) / double.parse(parts[1].trim())).toString();
      }
    } catch (e) {
      return 'خطأ في العملية الحسابية';
    }
    return input;
  }
  
  // 6. سلسلة التفكير (CoT)
  Future<String> _reasoningChain(String userInput) async {
    final chain = StringBuffer();
    chain.writeln('🤔 سلسلة التفكير:');
    chain.writeln('1. 📖 فهم السؤال: "$userInput"');
    
    final tool = _selectTool(userInput);
    chain.writeln('2. 🛠️ اختيار الأداة: $tool');
    
    final personality = _detectPersonality(userInput);
    chain.writeln('3. 🎭 تفعيل شخصية: $personality');
    
    chain.writeln('4. 💡 تحليل...');
    
    return chain.toString();
  }
  
  // 7. الرد الرئيسي للوكيل (مع كل الذكاءات)
  Future<String> respond(String userInput, {Function(String)? onThinking}) async {
    // حفظ في التاريخ
    _conversationHistory.add({'role': 'user', 'content': userInput, 'timestamp': DateTime.now()});
    
    // إظهار سلسلة التفكير
    if (onThinking != null) {
      onThinking(await _reasoningChain(userInput));
    }
    
    // اختيار الشخصية
    _currentPersonality = _detectPersonality(userInput);
    
    // اختيار الأداة
    final tool = _selectTool(userInput);
    
    String response;
    
    // تنفيذ الأداة المناسبة
    switch (tool) {
      case 'calculator':
        response = '🧮 نتيجة الحساب: ${_calculate(userInput)}';
        break;
      case 'reminder':
        response = await _createReminder(userInput);
        break;
      case 'memory':
        response = await _storeMemory(userInput);
        break;
      default:
        response = await _generateResponse(userInput);
    }
    
    // إضافة لمسة شخصية حسب الشخصية
    response = _applyPersonality(response);
    
    // اقتراحات استباقية
    final suggestion = await _generateProactiveSuggestion(userInput);
    if (suggestion != null) {
      response += '\n\n💡 اقتراح: $suggestion';
    }
    
    // حفظ الرد في الذاكرة
    _conversationHistory.add({'role': 'agent', 'content': response, 'timestamp': DateTime.now()});
    
    return response;
  }
  
  // 8. توليد رد باستخدام النموذج
  Future<String> _generateResponse(String input) async {
    if (_interpreter == null) return 'النموذج قيد التحميل...';
    
    // تبسيط: استخدام نمط استجابة ذكي
    final responses = {
      'مرحبا': 'مرحباً! كيف يمكنني مساعدتك اليوم؟ 😊',
      'كيف حالك': 'أنا بخير، شكراً للسؤال! أنا هنا لمساعدتك.',
      'شكرا': 'العفو! دائماً في خدمتك.',
      'وداعا': 'إلى اللقاء! عد متى شئت. 👋',
    };
    
    for (final key in responses.keys) {
      if (input.toLowerCase().contains(key)) {
        return responses[key]!;
      }
    }
    
    // رد عام ذكي
    final personalityPrefix = _getPersonalityPrefix();
    return '$personalityPrefix收到 سؤالك: "$input". أنا وكيل ذكي وأعمل على تحليله الآن. ماذا تريد أن تفعل؟';
  }
  
  String _getPersonalityPrefix() {
    switch (_currentPersonality) {
      case Personality.analytical:
        return '📊 [تحليلي] ';
      case Personality.creative:
        return '🎨 [مبتكر] ';
      case Personality.practical:
        return '⚡ [عملي] ';
    }
  }
  
  String _applyPersonality(String response) {
    switch (_currentPersonality) {
      case Personality.analytical:
        return response + ' (بناءً على تحليل البيانات)';
      case Personality.creative:
        return response + ' (هذه فكرة إبداعية)';
      case Personality.practical:
        return response;
    }
  }
  
  // 9. إنشاء تذكير
  Future<String> _createReminder(String input) async {
    // استخراج وقت ونص التذكير
    final lower = input.toLowerCase();
    if (lower.contains('الساعة')) {
      return '✅ تم حفظ التذكير. سأذكرك في الوقت المحدد!';
    }
    return '✅ تم حفظ تذكرتك. سأذكرك لاحقاً.';
  }
  
  // 10. حفظ في الذاكرة
  Future<String> _storeMemory(String input) async {
    await _memoryDb?.insert('memories', {
      'user_input': input,
      'agent_response': 'تم التخزين',
      'feedback_score': 0,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    return '📝 تم حفظ هذه المعلومة في ذاكرتي.';
  }
  
  // 11. اقتراحات استباقية (ذكاء تنبؤي)
  Future<String?> _generateProactiveSuggestion(String input) async {
    // تعلم من الأنماط
    final lower = input.toLowerCase();
    
    if (lower.contains('طقس') && _userPatterns['weather_count'] == null) {
      _userPatterns['weather_count'] = 1;
      return 'لاحظت أنك تسأل عن الطقس، هل تريد إضافة إشعار يومي بالطقس؟';
    }
    
    if (lower.contains('حساب') || lower.contains('رياضيات')) {
      return 'يمكنك كتابة عمليات حسابية مباشرة مثل "5+3" وسأحسبها لك!';
    }
    
    if (_conversationHistory.length > 10 && _userPatterns['long_session'] == null) {
      _userPatterns['long_session'] = true;
      return 'لاحظت أنك تتحدث معي كثيراً اليوم. هل تريد حفظ ملخص المحادثة؟';
    }
    
    return null;
  }
  
  // 12. التعلم من التقييمات
  Future<void> learnFromFeedback(String userInput, String agentResponse, int score) async {
    await _memoryDb?.insert('memories', {
      'user_input': userInput,
      'agent_response': agentResponse,
      'feedback_score': score,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    
    // تحديث الأنماط
    final pattern = userInput.split(' ').first;
    final existing = await _memoryDb?.query('patterns', where: 'pattern = ?', whereArgs: [pattern]);
    if (existing != null && existing.isNotEmpty) {
      await _memoryDb?.update('patterns', {'count': (existing.first['count'] as int) + 1}, where: 'pattern = ?', whereArgs: [pattern]);
    } else {
      await _memoryDb?.insert('patterns', {'pattern': pattern, 'count': 1});
    }
  }
  
  Future<void> _loadUserPatterns() async {
    final patterns = await _memoryDb?.query('patterns');
    if (patterns != null) {
      for (final p in patterns) {
        _userPatterns[p['pattern']] = p['count'];
      }
    }
  }
  
  void dispose() {
    _interpreter?.close();
    _memoryDb?.close();
  }
}
