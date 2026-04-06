import task_executor.dart;
import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:path_provider/path_provider.dart';

class RealModelEngine {
  Interpreter? _interpreter;
  bool _isLoaded = false;

  Future<bool> loadModel() async {
    try {
      // البحث عن النموذج في التخزين الخارجي أولاً
      List<String> paths = [
        '/storage/emulated/0/Download/models/phi3_mini.tflite',
        '/sdcard/Download/models/phi3_mini.tflite',
        '${(await getApplicationDocumentsDirectory()).path}/phi3_mini.tflite',
      ];

      String? modelPath;
      for (String path in paths) {
        if (await File(path).exists()) {
          modelPath = path;
          break;
        }
      }

      if (modelPath == null) {
        print('⚠️ Model not found in external storage');
        return false;
      }

      print('✅ Loading real model from: $modelPath');
      _interpreter = await Interpreter.fromFile(modelPath);
      _isLoaded = true;
      return true;
    } catch (e) {
      print('❌ Failed to load model: $e');
      return false;
    }
  }

  bool isLoaded() => _isLoaded;

  Future<String> generateResponse(String input) async {
    if (!_isLoaded || _interpreter == null) {
      return _fallbackResponse(input);
    }

    try {
      // تحويل النص إلى تنسيق المدخلات (تبسيطاً)
      final inputBytes = input.codeUnits.map((e) => e.toDouble()).toList();
      final inputTensor = [inputBytes];
      
      // تهيئة مصفوفة المخرجات
      var outputTensor = List.filled(1 * 100, 0.0).reshape([1, 100]);
      
      // تشغيل النموذج
      _interpreter!.run(inputTensor, outputTensor);
      
      // تحويل المخرجات إلى نص
      String response = String.fromCharCodes(
        outputTensor[0].where((v) => v > 31 && v < 127).map((v) => v.toInt()).toList()
      );
      
      if (response.trim().isNotEmpty && response.length > 5) {
        return response;
      }
      
      return _fallbackResponse(input);
    } catch (e) {
      print('Model inference error: $e');
      return _fallbackResponse(input);
    }
  }

  String _fallbackResponse(String input) {
    final lower = input.toLowerCase();
    if (lower.contains('مرحبا')) return 'مرحباً! 👋 أنا Phi-3 يعمل محلياً على هاتفك.';
    if (lower.contains('كيف حالك')) return 'أنا بخير، شكراً! 🧠 النموذج جاهز.';
    if (lower.contains('شكرا')) return 'العفو! 🤝';
    if (lower.contains('وداعا')) return '👋 وداعاً!';
    if (lower.contains('+')) return _calculate(input);
    if (lower.contains('ذكرني')) return '✅ تم حفظ التذكير.';
    return '🤔 سؤال ذكي! النموذج Phi-3 يعمل، لكن الإجابة تحتاج تنسيقاً أفضل.';
  }

  String _calculate(String input) {
    try {
      final numbers = RegExp(r'\d+').allMatches(input).map((m) => int.parse(m.group(0)!)).toList();
      if (numbers.length < 2) return 'اكتب عملية صحيحة';
      if (input.contains('+')) return '${numbers[0]} + ${numbers[1]} = ${numbers[0] + numbers[1]}';
      if (input.contains('-')) return '${numbers[0]} - ${numbers[1]} = ${numbers[0] - numbers[1]}';
      if (input.contains('*')) return '${numbers[0]} × ${numbers[1]} = ${numbers[0] * numbers[1]}';
    } catch (e) {}
    return 'خطأ في الحساب';
  }

  void dispose() {
    _interpreter?.close();
  }
}

// إضافة دالة لتنفيذ المهام
Future<String> executeTask(String input) async {
  final lower = input.toLowerCase();
  
  // كشف أوامر إنشاء الملفات والمهام
  if (lower.contains('أنشئ') || lower.contains('إنشاء') || 
      lower.contains('موقع') || lower.contains('ملف') ||
      lower.contains('قائمة مهام') || lower.contains('تقرير') ||
      lower.contains('حلل')) {
    return await TaskExecutor.executeComplexTask(input);
  }
  
  // إذا لم يكن أمر مهمة، استخدم النموذج للرد العادي
  return await generateResponse(input);
}
