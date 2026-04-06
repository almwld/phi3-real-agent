import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class ModelPathManager {
  static const String MODEL_FILENAME = 'phi3_mini.tflite';
  static const String VOCAB_FILENAME = 'smart_vocab.json';
  static const String TOKENIZER_FILENAME = 'tokenizer.json';
  
  // مسارات البحث عن النموذج (مرتبة حسب الأولوية)
  static List<String> getSearchPaths() {
    return [
      '/sdcard/Download/models/',           // مجلد التحميلات
      '/sdcard/Android/data/com.example.phi3_real_agent/files/',  // بيانات التطبيق
      '/storage/emulated/0/Phi3Model/',     // مجلد مخصص
      '/data/local/tmp/',                    // مجلد مؤقت
    ];
  }
  
  // البحث عن النموذج في جميع المسارات
  static Future<String?> findModelFile() async {
    for (String path in getSearchPaths()) {
      final file = File('$path$MODEL_FILENAME');
      if (await file.exists()) {
        print('✅ Model found at: $path');
        return file.path;
      }
    }
    
    // محاولة الحصول على مسار التطبيق
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final appFile = File('${appDir.path}/$MODEL_FILENAME');
      if (await appFile.exists()) {
        print('✅ Model found in app directory');
        return appFile.path;
      }
    } catch (e) {}
    
    print('⚠️ Model not found in any search path');
    return null;
  }
  
  // البحث عن ملفات النموذج الأخرى
  static Future<Map<String, String?>> findAllModelFiles() async {
    final modelPath = await findModelFile();
    String? vocabPath;
    String? tokenizerPath;
    
    if (modelPath != null) {
      final baseDir = File(modelPath).parent.path;
      vocabPath = '$baseDir/$VOCAB_FILENAME';
      tokenizerPath = '$baseDir/$TOKENIZER_FILENAME';
      
      // التحقق من وجود الملفات
      if (!await File(vocabPath).exists()) vocabPath = null;
      if (!await File(tokenizerPath).exists()) tokenizerPath = null;
    }
    
    return {
      'model': modelPath,
      'vocab': vocabPath,
      'tokenizer': tokenizerPath,
    };
  }
  
  // طلب صلاحيات التخزين
  static Future<bool> requestStoragePermission() async {
    if (await Permission.storage.isGranted) {
      return true;
    }
    
    final status = await Permission.storage.request();
    return status.isGranted;
  }
  
  // نسخ النموذج من assets إلى التخزين (إذا لم يوجد)
  static Future<bool> copyModelFromAssets() async {
    try {
      final externalDir = Directory('/sdcard/Download/models/');
      if (!await externalDir.exists()) {
        await externalDir.create(recursive: true);
      }
      
      final modelFile = File('${externalDir.path}/$MODEL_FILENAME');
      if (!await modelFile.exists()) {
        print('📦 Copying model from assets...');
        
        // قراءة النموذج من assets
        final byteData = await rootBundle.load('assets/models/$MODEL_FILENAME');
        final bytes = byteData.buffer.asUint8List();
        
        // كتابة إلى التخزين
        await modelFile.writeAsBytes(bytes);
        
        // نسخ الملفات الأخرى
        final vocabData = await rootBundle.loadString('assets/models/$VOCAB_FILENAME');
        await File('${externalDir.path}/$VOCAB_FILENAME').writeAsString(vocabData);
        
        final tokenizerData = await rootBundle.loadString('assets/models/$TOKENIZER_FILENAME');
        await File('${externalDir.path}/$TOKENIZER_FILENAME').writeAsString(tokenizerData);
        
        print('✅ Model copied to: ${externalDir.path}');
        return true;
      }
    } catch (e) {
      print('⚠️ Could not copy model: $e');
    }
    return false;
  }
  
  // الحصول على إحصائيات النموذج
  static Future<Map<String, dynamic>> getModelInfo() async {
    final modelPath = await findModelFile();
    if (modelPath == null) {
      return {'status': 'not_found', 'message': 'النموذج غير موجود'};
    }
    
    final file = File(modelPath);
    final size = await file.length();
    final sizeMB = (size / 1024 / 1024).toStringAsFixed(1);
    
    return {
      'status': 'found',
      'path': modelPath,
      'size_mb': sizeMB,
      'size_bytes': size,
    };
  }
}
