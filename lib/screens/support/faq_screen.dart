import 'package:flutter/material.dart';
import '../../theme/color_constants.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  final List<Map<String, String>> faqs = const [
    {'question': 'كيف يمكنني إنشاء حساب؟', 'answer': 'يمكنك إنشاء حساب من خلال شاشة التسجيل وإدخال بياناتك.'},
    {'question': 'كيف أضيف منتجاً إلى السلة؟', 'answer': 'اضغط على زر "أضف إلى السلة" في صفحة المنتج.'},
    {'question': 'ما هي طرق الدفع المتاحة؟', 'answer': 'محفظة فلكس، تحويل بنكي، بطاقات هدايا.'},
    {'question': 'كيف أتتبع طلبي؟', 'answer': 'يمكنك تتبع طلبك من خلال شاشة "تتبع الطلب".'},
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      appBar: AppBar(
        title: const Text('الأسئلة الشائعة'),
        backgroundColor: AppColors.goldColor,
        foregroundColor: Colors.black,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: faqs.length,
        itemBuilder: (context, index) {
          final faq = faqs[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              title: Text(faq['question']!, style: const TextStyle(fontWeight: FontWeight.bold)),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(faq['answer']!),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
