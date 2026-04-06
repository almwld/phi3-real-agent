import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class ModelPathManager {
  static const String MODEL_FILENAME = 'phi3_mini.tflite';
  static const String VOCAB_FILENAME = 'smart_vocab.json';
  static const String TOKENIZER_FILENAME = 'tokenizer.json';

  static List<String> getSearchPaths() {
    return [
      '/storage/emulated/0/Download/models/',
      '/sdcard/Download/models/',
      '/storage/emulated/0/Phi3Model/',
    ];
  }

  static Future<String?> findModelFile() async {
    for (String path in getSearchPaths()) {
      final file = File('$path$MODEL_FILENAME');
      if (await file.exists()) {
        return file.path;
      }
    }
    try {
      await rootBundle.load('assets/models/$MODEL_FILENAME');
      return 'assets/models/$MODEL_FILENAME';
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, String?>> findAllModelFiles() async {
    final modelPath = await findModelFile();
    if (modelPath == null) return {'model': null, 'vocab': null, 'tokenizer': null};
    final dir = File(modelPath).parent.path;
    return {
      'model': modelPath,
      'vocab': '$dir/$VOCAB_FILENAME',
      'tokenizer': '$dir/$TOKENIZER_FILENAME',
    };
  }

  static Future<Map<String, dynamic>> getModelInfo() async {
    final path = await findModelFile();
    if (path == null) return {'status': 'not_found', 'message': 'النموذج غير موجود'};
    final file = File(path);
    final size = await file.length();
    return {
      'status': 'found',
      'path': path,
      'size_mb': (size / 1024 / 1024).toStringAsFixed(1),
    };
  }
}
