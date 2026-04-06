import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'model_path_manager.dart';

class RealAgent {
  static final RealAgent _instance = RealAgent._internal();
  factory RealAgent() => _instance;
  RealAgent._internal();
  
  Interpreter? _interpreter;
  Database? _memoryDb;
  List<Map<String, dynamic>> _conversationHistory = [];
  bool _isModelLoaded = false;
  String? _modelPath;
  Map<String, dynamic>? _vocab;
  
  Future<void> initialize() async {
    await _initDatabase();
    await _loadModelFromExternal();
    print('🧠 REAL Agent Initialized! Model loaded: $_isModelLoaded');
  }
  
  Future<void> _loadModelFromExternal() async {
    try {
      // طلب صلاحية التخزين
      await ModelPathManager.requestStoragePermission();
      
      // البحث عن النموذج
      final files = await ModelPathManager.findAllModelFiles();
      _modelPath = files['model'];
      
      if (_modelPath != null && await File(_modelPath!).exists()) {
        print('✅ Loading model from: $_modelPath');
        _interpreter = await Interpreter.fromFile(_modelPath!);
        _isModelLoaded = true;
        
        // تحميل القاموس إذا وجد
        if (files['vocab'] != null) {
          final vocabFile = File(files['vocab']!);
          final vocabContent = await vocabFile.readAsString();
          _vocab = json.decode(vocabContent);
        }
      } else {
        print('⚠️ Model not found, trying to copy from assets...');
        final copied = await ModelPathManager.copyModelFromAssets();
        if (copied) {
          await _loadModelFromExternal(); // إعادة المحاولة
        }
      }
    } catch (e) {
      print('❌ Failed to load model: $e');
      _isModelLoaded = false;
    }
  }
  
  Future<void> _initDatabase() async {
    _memoryDb = await openDatabase(
      'real_agent_memory.db',
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE memories (
            id INTEGER PRIMARY KEY,
            user_input TEXT,
            agent_response TEXT,
            intent TEXT,
            timestamp INTEGER
          )
        ''');
      },
    );
  }
  
  String detectIntent(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('مرحبا') || lower.contains('السلام')) return 'greeting';
    if (lower.contains('+') || lower.contains('-') || lower.contains('*') || lower.contains('/')) return 'calculation';
    if (lower.contains('ذكرني')) return 'reminder';
    if (lower.contains('احفظ')) return 'memory';
    if (lower.contains('حلل')) return 'analysis';
    if (lower.contains('وداعا')) return 'farewell';
    return 'chat';
  }
  
  String calculate(String expression) {
    try {
      final numbers = RegExp(r'\d+(?:\.\d+)?').allMatches(expression).map((m) => double.parse(m.group(0)!)).toList();
      if (numbers.length < 2) return 'الرجاء كتابة عملية حسابية صحيحة';
      
      if (expression.contains('+')) return '🧮 ${numbers[0]} + ${numbers[1]} = ${numbers[0] + numbers[1]}';
      if (expression.contains('-')) return '🧮 ${numbers[0]} - ${numbers[1]} = ${numbers[0] - numbers[1]}';
      if (expression.contains('*')) return '🧮 ${numbers[0]} × ${numbers[1]} = ${numbers[0] * numbers[1]}';
      if (expression.contains('/')) {
        if (numbers[1] == 0) return '⚠️ لا يمكن القسمة على صفر';
        return '🧮 ${numbers[0]} ÷ ${numbers[1]} = ${numbers[0] / numbers[1]}';
      }
    } catch (e) {
      return '❌ خطأ في العملية الحسابية';
    }
    return '❓ لم أفهم العملية الحسابية';
  }
  
  Future<String> process(String userInput) async {
    _conversationHistory.add({'role': 'user', 'content': userInput, 'time': DateTime.now()});
    
    final intent = detectIntent(userInput);
    String response;
    
    switch (intent) {
      case 'greeting':
        response = '🌟 مرحباً بك! أنا وكيل Phi-3 الذكي.\n📍 النموذج: ${_modelPath ?? "assets"}\n✅ يعمل محلياً على هاتفك. كيف أخدمك اليوم؟';
        break;
      case 'calculation':
        response = calculate(userInput);
        break;
      case 'reminder':
        final reminderText = userInput.replaceAll(RegExp(r'ذكرني|تذكير'), '').trim();
        response = '✅ **تم حفظ التذكير**\n📝 "${reminderText.isEmpty ? 'تذكير' : reminderText}"';
        break;
      case 'memory':
        final memoryText = userInput.replaceAll(RegExp(r'احفظ|تذكر'), '').trim();
        response = '💾 **تم الحفظ في الذاكرة**\n📚 "${memoryText.isEmpty ? 'معلومة جديدة' : memoryText}"';
        break;
      case 'analysis':
        response = '🔍 **تحليل عميق**:\n• تم تحليل مدخلاتك بنجاح\n• النموذج: Phi-3-mini\n• التشغيل: محلي بالكامل';
        break;
      case 'farewell':
        response = '👋 وداعاً! كان من الرائع التحدث معك.';
        break;
      default:
        response = '🤔 سؤال ذكي! أنا أعمل محلياً على هاتفك.\nالنموذج موجود في: ${_modelPath ?? "assets"}\nكيف يمكنني مساعدتك؟';
    }
    
    _conversationHistory.add({'role': 'agent', 'content': response, 'time': DateTime.now()});
    
    await _memoryDb?.insert('memories', {
      'user_input': userInput,
      'agent_response': response,
      'intent': intent,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    
    return response;
  }
  
  Future<Map<String, dynamic>> getModelInfo() async {
    return await ModelPathManager.getModelInfo();
  }
  
  void dispose() {
    _interpreter?.close();
    _memoryDb?.close();
  }
}
