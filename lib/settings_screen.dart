import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkMode = true;
  bool _soundEnabled = true;
  bool _notificationsEnabled = true;
  String _modelStatus = "جاري التحقق...";
  String _modelPath = "غير موجود";
  String _modelSize = "0 MB";
  int _messagesCount = 0;
  int _dbSize = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadModelInfo();
    _loadStats();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _darkMode = prefs.getBool('darkMode') ?? true;
      _soundEnabled = prefs.getBool('soundEnabled') ?? true;
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', _darkMode);
    await prefs.setBool('soundEnabled', _soundEnabled);
    await prefs.setBool('notificationsEnabled', _notificationsEnabled);
  }

  Future<void> _loadModelInfo() async {
    // البحث عن النموذج في المسارات المختلفة
    List<String> paths = [
      '/storage/emulated/0/Download/models/phi3_mini.tflite',
      '/sdcard/Download/models/phi3_mini.tflite',
      '/data/data/com.termux/files/home/downloads/training_package/flutter_app/assets/models/phi3_mini.tflite',
    ];

    for (String path in paths) {
      File file = File(path);
      if (await file.exists()) {
        setState(() {
          _modelStatus = "✅ موجود";
          _modelPath = path;
          _modelSize = "${(await file.length() / 1024 / 1024).toStringAsFixed(2)} MB";
        });
        break;
      } else {
        setState(() {
          _modelStatus = "❌ غير موجود";
        });
      }
    }
  }

  Future<void> _loadStats() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = '${dir.path}/agent.db';
    File dbFile = File(dbPath);
    if (await dbFile.exists()) {
      setState(() {
        _dbSize = await dbFile.length();
      });
    }

    final db = await openDatabase(dbPath);
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM messages');
    setState(() {
      _messagesCount = result.first['count'] as int;
    });
    await db.close();
  }

  Future<void> _clearDatabase() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مسح المحادثات'),
        content: const Text('هل أنت متأكد من حذف جميع المحادثات؟ لا يمكن التراجع.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              final dir = await getApplicationDocumentsDirectory();
              final db = await openDatabase('${dir.path}/agent.db');
              await db.delete('messages');
              await db.close();
              setState(() {
                _messagesCount = 0;
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم مسح جميع المحادثات')),
              );
            },
            child: const Text('مسح', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _exportDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = '${dir.path}/agent.db';
    final exportPath = '/storage/emulated/0/Download/chat_backup.db';
    
    try {
      await File(dbPath).copy(exportPath);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم التصدير إلى: $exportPath')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل التصدير')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),
      body: ListView(
        children: [
          // قسم النموذج
          Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '🤖 النموذج (Model)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                _buildInfoRow('الحالة', _modelStatus),
                _buildInfoRow('المسار', _modelPath),
                _buildInfoRow('الحجم', _modelSize),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton.icon(
                    onPressed: _loadModelInfo,
                    icon: const Icon(Icons.refresh),
                    label: const Text('تحديث'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      minimumSize: const Size(double.infinity, 45),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // قسم الإحصائيات
          Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '📊 الإحصائيات',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                _buildInfoRow('عدد الرسائل', '$_messagesCount'),
                _buildInfoRow('حجم قاعدة البيانات', '${(_dbSize / 1024).toStringAsFixed(2)} KB'),
              ],
            ),
          ),

          // قسم التفضيلات
          Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '⚙️ التفضيلات',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                SwitchListTile(
                  title: const Text('الوضع الليلي'),
                  subtitle: const Text('تغيير مظهر التطبيق'),
                  value: _darkMode,
                  onChanged: (value) {
                    setState(() {
                      _darkMode = value;
                      _saveSettings();
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('الأصوات'),
                  subtitle: const Text('تشغيل أصوات عند الإرسال والاستقبال'),
                  value: _soundEnabled,
                  onChanged: (value) {
                    setState(() {
                      _soundEnabled = value;
                      _saveSettings();
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('الإشعارات'),
                  subtitle: const Text('تلقي إشعارات التذكيرات'),
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    setState(() {
                      _notificationsEnabled = value;
                      _saveSettings();
                    });
                  },
                ),
              ],
            ),
          ),

          // قسم إدارة البيانات
          Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '💾 إدارة البيانات',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.download, color: Colors.blue),
                  title: const Text('تصدير المحادثات'),
                  subtitle: const Text('حفظ المحادثات إلى ملف'),
                  onTap: _exportDatabase,
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('مسح جميع المحادثات'),
                  subtitle: const Text('حذف قاعدة البيانات بالكامل'),
                  onTap: _clearDatabase,
                ),
              ],
            ),
          ),

          // معلومات
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text(
                  'Phi-3 Smart Agent',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'الإصدار 2.0.0',
                  style: TextStyle(color: Colors.grey.shade400),
                ),
                const SizedBox(height: 8),
                Text(
                  'نموذج ذكي يعمل محلياً على هاتفك',
                  style: TextStyle(color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}
