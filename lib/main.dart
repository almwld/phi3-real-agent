import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:share_plus/share_plus.dart';
import 'smart_agent.dart';
import 'model_path_manager.dart';
import 'notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  await SmartAgent().init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Phi-3 Smart Agent',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(primaryColor: Colors.deepPurple),
      darkTheme: ThemeData.dark().copyWith(primaryColor: Colors.deepPurple),
      themeMode: _themeMode,
      home: ChatScreen(toggleTheme: toggleTheme),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  const ChatScreen({super.key, required this.toggleTheme});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  String _modelStatus = 'جاري التحقق...';
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;

  final List<String> quickSuggestions = [
    'مرحبا',
    'ما هو الذكاء الاصطناعي؟',
    'احسب 15+27',
    'ذكرني في 18:00 بأخذ دواء',
    'ابحث في المحادثات عن مرحبا',
    'احفظ الملخص',
    'تصدير المحادثة'
  ];

  @override
  void initState() {
    super.initState();
    _checkModel();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    await _speech.initialize();
  }

  Future<void> _checkModel() async {
    final info = await ModelPathManager.getModelInfo();
    setState(() {
      if (info['status'] == 'found') {
        _modelStatus = '✅ النموذج موجود (${info['size_mb']} MB)';
      } else {
        _modelStatus = '⚠️ ضع phi3_mini.tflite في /sdcard/Download/models/';
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add({'isUser': true, 'content': text, 'time': DateTime.now()});
      _isLoading = true;
    });
    _scrollToBottom();

    final agent = SmartAgent();
    String response;
    if (text == 'تصدير المحادثة') {
      final path = await agent.exportChat();
      response = '✅ تم تصدير المحادثة إلى: $path';
      await Share.shareFiles([path], text: 'نسخة من محادثتي مع الوكيل الذكي');
    } else {
      response = await agent.respond(text);
    }

    setState(() {
      _messages.add({'isUser': false, 'content': response, 'time': DateTime.now()});
      _isLoading = false;
    });
    _scrollToBottom();

    if (await agent.shouldSuggestSummary() && text != 'احفظ الملخص') {
      Future.delayed(const Duration(milliseconds: 500), () {
        setState(() {
          _messages.add({
            'isUser': false,
            'content': '💡 **اقتراح ذكي**: لاحظت محادثة طويلة، اكتب "احفظ الملخص" لحفظ ملخصها.',
            'time': DateTime.now(),
            'isSuggestion': true,
          });
        });
        _scrollToBottom();
      });
    }
  }

  void _startListening() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          setState(() {
            _controller.text = result.recognizedWords;
            _isListening = false;
          });
          _sendMessage(_controller.text);
          _controller.clear();
        },
      );
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧠 Phi-3 Smart Agent'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.brightness_6),
            onPressed: widget.toggleTheme,
            tooltip: 'تبديل المظهر',
          ),
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () => _sendMessage('تصدير المحادثة'),
            tooltip: 'تصدير المحادثة',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            alignment: Alignment.center,
            child: Text(_modelStatus, style: const TextStyle(fontSize: 12)),
          ),
        ),
      ),
      body: Column(
        children: [
          // الأزرار السريعة
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: quickSuggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return ActionChip(
                  label: Text(quickSuggestions[index]),
                  onPressed: () => _sendMessage(quickSuggestions[index]),
                  backgroundColor: Colors.deepPurple.shade100,
                );
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['isUser'] as bool;
                final isSuggestion = msg['isSuggestion'] == true;
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? Colors.deepPurple
                          : (isSuggestion ? Colors.orange : Colors.grey.shade800),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(msg['content'], style: const TextStyle(color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(
                          '${(msg['time'] as DateTime).hour}:${(msg['time'] as DateTime).minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 10, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Theme.of(context).cardColor),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                  onPressed: _startListening,
                  tooltip: 'إدخال صوتي',
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'اكتب أو تحدث...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(30))),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    onSubmitted: (t) => _sendMessage(t),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _sendMessage(_controller.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
