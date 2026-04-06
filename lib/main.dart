import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'settings_screen.dart';
import 'real_model_engine.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDatabase();
  runApp(const MyApp());
}

Future<void> initDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  final db = await openDatabase('${dir.path}/agent.db', version: 1,
      onCreate: (db, version) async {
    await db.execute('''
      CREATE TABLE messages(
        id INTEGER PRIMARY KEY,
        text TEXT,
        isUser INTEGER,
        time TEXT
      )
    ''');
  });
  await db.close();
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final RealModelEngine _modelEngine = RealModelEngine();
  bool _modelReady = false;

  @override
  void initState() {
    super.initState();
    _initModel();
  }

  Future<void> _initModel() async {
    final loaded = await _modelEngine.loadModel();
    setState(() {
      _modelReady = loaded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Phi-3 Real Agent',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(primaryColor: Colors.deepPurple),
      home: ChatScreen(modelEngine: _modelEngine, modelReady: _modelReady),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final RealModelEngine modelEngine;
  final bool modelReady;

  const ChatScreen({super.key, required this.modelEngine, required this.modelReady});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _addWelcomeMessage();
  }

  void _addWelcomeMessage() {
    _messages.add({
      'isUser': false,
      'content': widget.modelReady 
        ? '🧠 **Phi-3 Real Agent**\n\n✅ النموذج الحقيقي (91MB) يعمل!\n\nيمكنك التحدث معي بشكل طبيعي، سأستخدم الذكاء الاصطناعي للرد.\n\n**جرب:**\n• مرحبا\n• 5+3\n• ما هو الذكاء الاصطناعي؟'
        : '⚠️ **النموذج غير متوفر**\n\nالرجاء وضع ملف phi3_mini.tflite (91MB) في مجلد Download/models/',
      'time': DateTime.now(),
    });
  }

  Future<void> _loadMessages() async {
    final dir = await getApplicationDocumentsDirectory();
    final db = await openDatabase('${dir.path}/agent.db');
    final result = await db.query('messages', orderBy: 'id ASC');
    setState(() {
      for (var msg in result) {
        _messages.add({
          'isUser': msg['isUser'] == 1,
          'content': msg['text'],
          'time': DateTime.parse(msg['time']),
        });
      }
    });
    await db.close();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'isUser': true, 'content': text, 'time': DateTime.now()});
      _controller.clear();
      _isLoading = true;
    });

    final dir = await getApplicationDocumentsDirectory();
    final db = await openDatabase('${dir.path}/agent.db');
    await db.insert('messages', {
      'text': text,
      'isUser': 1,
      'time': DateTime.now().toString()
    });
    await db.close();

    String response;
    if (widget.modelReady) {
      response = await widget.modelEngine.generateResponse(text);
    } else {
      response = _fallbackResponse(text);
    }

    setState(() {
      _messages.add({'isUser': false, 'content': response, 'time': DateTime.now()});
      _isLoading = false;
    });

    final db2 = await openDatabase('${dir.path}/agent.db');
    await db2.insert('messages', {
      'text': response,
      'isUser': 0,
      'time': DateTime.now().toString()
    });
    await db2.close();
  }

  String _fallbackResponse(String input) {
    final lower = input.toLowerCase();
    if (lower.contains('مرحبا')) return 'مرحباً! 👋';
    if (lower.contains('كيف حالك')) return 'أنا بخير، شكراً!';
    if (lower.contains('شكرا')) return 'العفو! 🤝';
    if (lower.contains('وداعا')) return '👋 وداعاً!';
    if (lower.contains('+')) return _calculate(input);
    return '⚠️ النموذج غير متوفر. الرجاء وضع ملف phi3_mini.tflite في Download/models/';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧠 Phi-3 Real Agent'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            tooltip: 'الإعدادات',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            alignment: Alignment.center,
            child: Text(
              widget.modelReady 
                ? '✅ النموذج الحقيقي يعمل | 91.45 MB' 
                : '⚠️ النموذج غير موجود',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['isUser'] as bool;
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.deepPurple : Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      msg['content'],
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: LinearProgressIndicator(),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              border: Border(top: BorderSide(color: Colors.grey.shade700)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: widget.modelReady ? 'تحدث مع Phi-3...' : 'النموذج غير متوفر',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade800,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.deepPurple,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
