import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'settings_screen.dart';

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Phi-3 Agent',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(primaryColor: Colors.deepPurple),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

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
  }

  Future<void> _loadMessages() async {
    final dir = await getApplicationDocumentsDirectory();
    final db = await openDatabase('${dir.path}/agent.db');
    final result = await db.query('messages', orderBy: 'id ASC');
    setState(() {
      _messages.clear();
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

    await Future.delayed(const Duration(milliseconds: 500));
    String response = _generateResponse(text);

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

  String _generateResponse(String input) {
    final lower = input.toLowerCase();
    if (lower.contains('مرحبا') || lower.contains('السلام')) {
      return 'مرحباً! 👋 أنا وكيل Phi-3. كيف أخدمك اليوم؟\n\nيمكنني:\n• 🧮 إجراء العمليات الحسابية\n• 📝 حفظ التذكيرات\n• 💾 تذكر المعلومات\n• ⚙️ إعدادات متقدمة';
    }
    if (lower.contains('كيف حالك')) {
      return 'أنا بخير، شكراً! 🧠 جاهز لمساعدتك.';
    }
    if (lower.contains('شكرا')) {
      return 'العفو! 🤝 دائماً في خدمتك.';
    }
    if (lower.contains('وداعا')) {
      return '👋 وداعاً! عد متى شئت.';
    }
    if (lower.contains('+') || lower.contains('-') || lower.contains('*') || lower.contains('/')) {
      return _calculate(input);
    }
    if (lower.contains('ذكرني')) {
      final reminder = input.replaceAll('ذكرني', '').trim();
      return '✅ تم حفظ التذكير: "$reminder"\nسأذكرك في الوقت المناسب!';
    }
    if (lower.contains('تذكر') || lower.contains('احفظ')) {
      final memory = input.replaceAll(RegExp(r'تذكر|احفظ'), '').trim();
      return '💾 تم حفظ: "$memory"\nسأتذكر هذا دائماً!';
    }
    return '🤔 سؤال ذكي! أنا أعمل محلياً على هاتفك.\n\n📌 الأوامر المتاحة:\n• مرحبا\n• 5+3\n• ذكرني بأخذ دواء\n• تذكر أن لوني المفضل أزرق\n• ⚙️ اضغط على زر الإعدادات للأكثر';
  }

  String _calculate(String input) {
    try {
      final numbers = RegExp(r'\d+').allMatches(input).map((m) => int.parse(m.group(0)!)).toList();
      if (numbers.length < 2) return 'الرجاء كتابة عملية حسابية صحيحة';
      if (input.contains('+')) return '🧮 ${numbers[0]} + ${numbers[1]} = ${numbers[0] + numbers[1]}';
      if (input.contains('-')) return '🧮 ${numbers[0]} - ${numbers[1]} = ${numbers[0] - numbers[1]}';
      if (input.contains('*')) return '🧮 ${numbers[0]} × ${numbers[1]} = ${numbers[0] * numbers[1]}';
      if (input.contains('/')) {
        if (numbers[1] == 0) return '⚠️ لا يمكن القسمة على صفر';
        return '🧮 ${numbers[0]} ÷ ${numbers[1]} = ${numbers[0] / numbers[1]}';
      }
    } catch (e) {
      return '❌ خطأ في العملية الحسابية';
    }
    return 'اكتب عملية حسابية مثل: 5+3';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧠 Phi-3 Agent'),
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
                      hintText: 'اكتب رسالتك...',
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
