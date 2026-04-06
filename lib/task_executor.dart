import 'dart:io';
import 'package:path_provider/path_provider.dart';

class TaskExecutor {
  
  // 1. إنشاء ملف جديد
  static Future<String> createFile(String fileName, String content) async {
    try {
      final dir = await getExternalStorageDirectory();
      final file = File('${dir?.path}/$fileName');
      await file.writeAsString(content);
      return '✅ تم إنشاء الملف: ${file.path}\nالحجم: ${await file.length()} بايت';
    } catch (e) {
      return '❌ فشل إنشاء الملف: $e';
    }
  }

  // 2. إنشاء ملف HTML
  static Future<String> createHtmlPage(String title, String body) async {
    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$title</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 800px; margin: auto; background: white; padding: 20px; border-radius: 10px; }
        h1 { color: #6200EE; }
    </style>
</head>
<body>
    <div class="container">
        <h1>$title</h1>
        <p>$body</p>
        <hr>
        <small>تم إنشاؤه بواسطة Phi-3 Agent في ${DateTime.now()}</small>
    </div>
</body>
</html>
''';
    return await createFile('$title.html', htmlContent);
  }

  // 3. إنشاء قائمة مهام
  static Future<String> createTodoList(List<String> tasks) async {
    final todoContent = tasks.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n');
    final content = '''
📝 قائمة المهام
═══════════════════════════
$todoContent
═══════════════════════════
📅 التاريخ: ${DateTime.now()}
✅ إجمالي المهام: ${tasks.length}
''';
    return await createFile('todo_list_${DateTime.now().millisecondsSinceEpoch}.txt', content);
  }

  // 4. تحليل نص واستخراج معلومات
  static Map<String, dynamic> analyzeText(String text) {
    return {
      'length': text.length,
      'words': text.split(' ').length,
      'lines': text.split('\n').length,
      'has_numbers': RegExp(r'\d').hasMatch(text),
      'has_arabic': RegExp(r'[\u0600-\u06FF]').hasMatch(text),
    };
  }

  // 5. إنشاء تقرير تحليل
  static Future<String> createAnalysisReport(String inputText) async {
    final analysis = analyzeText(inputText);
    final report = '''
📊 تقرير التحليل
═══════════════════════════
📝 النص الأصلي: ${inputText.length > 50 ? inputText.substring(0, 50) + '...' : inputText}
📏 طول النص: ${analysis['length']} حرف
📖 عدد الكلمات: ${analysis['words']} كلمة
📐 عدد السطور: ${analysis['lines']} سطر
🔢 يحتوي على أرقام: ${analysis['has_numbers'] ? 'نعم' : 'لا'}
🌐 يحتوي على عربي: ${analysis['has_arabic'] ? 'نعم' : 'لا'}
═══════════════════════════
📅 التاريخ: ${DateTime.now()}
''';
    return await createFile('analysis_report_${DateTime.now().millisecondsSinceEpoch}.txt', report);
  }

  // 6. تنفيذ مهمة معقدة متعددة الخطوات
  static Future<String> executeComplexTask(String taskDescription) async {
    final lower = taskDescription.toLowerCase();
    
    if (lower.contains('موقع') && lower.contains('html')) {
      // استخراج عنوان من الوصف
      String title = 'صفحتي';
      String body = 'مرحباً! هذه صفحة تم إنشاؤها بواسطة Phi-3 Agent.';
      if (taskDescription.contains('عنوان')) {
        final match = RegExp(r'عنوان[\s:]*([^\n،.]+)').firstMatch(taskDescription);
        if (match != null) title = match.group(1)!;
      }
      return await createHtmlPage(title, body);
    }
    
    if (lower.contains('قائمة') && lower.contains('مهام')) {
      // استخراج المهام من الوصف
      final tasks = taskDescription.split(',').map((t) => t.trim()).toList();
      if (tasks.isEmpty) {
        return await createTodoList(['مهمة 1', 'مهمة 2', 'مهمة 3']);
      }
      return await createTodoList(tasks);
    }
    
    if (lower.contains('تحليل') || lower.contains('تقرير')) {
      final textToAnalyze = taskDescription.replaceAll(RegExp(r'حلل|تقرير عن'), '').trim();
      if (textToAnalyze.isEmpty) {
        return '📝 الرجاء كتابة النص الذي تريد تحليله بعد كلمة "حلل"';
      }
      return await createAnalysisReport(textToAnalyze);
    }
    
    if (lower.contains('ملف') && lower.contains('نصي')) {
      String fileName = 'ملف_نصي.txt';
      String content = 'تم إنشاء هذا الملف بواسطة Phi-3 Agent في ${DateTime.now()}';
      if (taskDescription.contains('اسم')) {
        final match = RegExp(r'اسم[\s:]*([^\n،.]+)').firstMatch(taskDescription);
        if (match != null) fileName = match.group(1)!;
      }
      if (taskDescription.contains('محتوى')) {
        final match = RegExp(r'محتوى[\s:]*([^\n]+)').firstMatch(taskDescription);
        if (match != null) content = match.group(1)!;
      }
      return await createFile(fileName, content);
    }
    
    return '''
📋 **المهام التي يمكنني تنفيذها:**

1. **إنشاء ملف HTML**: "أنشئ موقعاً باسم 'صفحتي'"
2. **قائمة مهام**: "أنشئ قائمة مهام: شراء حليب، دراسة، رياضة"
3. **تحليل نص**: "حلل هذا النص: ..."
4. **إنشاء ملف نصي**: "أنشئ ملف نصي باسم test.txt محتواه: مرحباً"
5. **تقرير**: "أنشئ تقريراً عن: ..."

✏️ **اكتب طلبك وسأنفذه فوراً!**
''';
  }
}
