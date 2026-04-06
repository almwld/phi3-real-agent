import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:convert';
import 'dart:math';

class TinyAgentLLM {
  static final TinyAgentLLM _instance = TinyAgentLLM._internal();
  factory TinyAgentLLM() => _instance;
  TinyAgentLLM._internal();
  
  Interpreter? _interpreter;
  Map<String, int>? _vocab;
  List<String>? _indexToToken;
  bool _isLoaded = false;
  
  Future<void> loadModel() async {
    if (_isLoaded) return;
    
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/small_agent_model.tflite');
      
      final tokenizerJson = await rootBundle.loadString('assets/models/tokenizer.json');
      final tokenizerMap = json.decode(tokenizerJson) as Map<String, dynamic>;
      _vocab = {};
      _indexToToken = [];
      
      tokenizerMap.forEach((key, value) {
        final idx = int.parse(key);
        _vocab![value] = idx;
        if (_indexToToken!.length <= idx) {
          _indexToToken!.length = idx + 1;
        }
        _indexToToken![idx] = value;
      });
      
      _isLoaded = true;
      print('✅ TinyAgentLLM loaded successfully');
    } catch (e) {
      print('❌ Failed to load model: $e');
      _isLoaded = false;
    }
  }
  
  List<int> tokenize(String text) {
    final words = text.toLowerCase().split(' ');
    final tokens = <int>[];
    for (final word in words) {
      if (_vocab!.containsKey(word)) {
        tokens.add(_vocab![word]!);
      } else {
        tokens.add(1);
      }
    }
    return tokens;
  }
  
  String detokenize(List<int> tokens) {
    final words = <String>[];
    for (final token in tokens) {
      if (token < _indexToToken!.length) {
        words.add(_indexToToken![token]);
      } else {
        words.add('<unk>');
      }
    }
    return words.join(' ');
  }
  
  Future<String> generate(String prompt, {int maxLength = 50}) async {
    await loadModel();
    if (!_isLoaded) return 'Model not loaded. Please train first.';
    
    final inputTokens = tokenize(prompt);
    final inputArray = List.filled(1 * 32, 0).reshape([1, 32]);
    
    for (var i = 0; i < min(inputTokens.length, 32); i++) {
      inputArray[0][i] = inputTokens[i];
    }
    
    final outputArray = List.filled(1 * 32 * 10000, 0.0).reshape([1, 32, 10000]);
    
    _interpreter!.run(inputArray, outputArray);
    
    final generatedTokens = <int>[];
    for (var i = 0; i < maxLength; i++) {
      final probs = outputArray[0][i % 32];
      final nextToken = _sampleFromDistribution(probs);
      if (nextToken == 0) break;
      generatedTokens.add(nextToken);
    }
    
    return detokenize(generatedTokens);
  }
  
  int _sampleFromDistribution(List<double> probs) {
    final random = Random();
    var maxProb = 0.0;
    var maxIndex = 1;
    for (var i = 0; i < probs.length; i++) {
      final prob = probs[i] + random.nextDouble() * 0.1;
      if (prob > maxProb) {
        maxProb = prob;
        maxIndex = i;
      }
    }
    return maxIndex;
  }
  
  void dispose() {
    _interpreter?.close();
  }
}
