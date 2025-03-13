import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:project/main_tabview/main_tabview.dart';
import 'dart:convert';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

class promotion extends StatefulWidget {
  @override
  _promotionState createState() => _promotionState();
}

class _promotionState extends State<promotion> {
  late List<Map<String, dynamic>> bigCPromotions = [];
  late List<Map<String, dynamic>> lotusPromotions = [];
  PageController _bigCController = PageController();
  PageController _lotusController = PageController();
  int _bigCPage = 0;
  int _lotusPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchPromotions();
  }

  Future<void> _fetchPromotions() async {
    try {
      final bigCResponse = await http.get(Uri.parse('http://10.0.0.85:3000/promotions?site=bigc'));
      if (bigCResponse.statusCode == 200) {
        final List<dynamic> bigCData = json.decode(bigCResponse.body);
        setState(() {
          bigCPromotions = List<Map<String, dynamic>>.from(bigCData.map((item) => item as Map<String, dynamic>));
        });
      }

      final lotusResponse = await http.get(Uri.parse('http://10.0.0.85:3000/promotions?site=lotus'));
      if (lotusResponse.statusCode == 200) {
        final List<dynamic> lotusData = json.decode(lotusResponse.body);
        setState(() {
          lotusPromotions = List<Map<String, dynamic>>.from(lotusData.map((item) => item as Map<String, dynamic>));
        });
      }

      if (bigCPromotions.isNotEmpty || lotusPromotions.isNotEmpty) {
        _startAutoSlide();
      }
    } catch (e) {
      print("เกิดข้อผิดพลาดในการโหลดโปรโมชั่น: $e");
    }
  }

  void _startAutoSlide() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 5), (timer) {
      if (bigCPromotions.isNotEmpty) {
        _bigCPage = (_bigCPage + 1) % bigCPromotions.length;
        _bigCController.animateToPage(_bigCPage, duration: Duration(milliseconds: 500), curve: Curves.easeInOut);
      }
      if (lotusPromotions.isNotEmpty) {
        _lotusPage = (_lotusPage + 1) % lotusPromotions.length;
        _lotusController.animateToPage(_lotusPage, duration: Duration(milliseconds: 500), curve: Curves.easeInOut);
      }
    });
  }

  void _resetAutoSlide() {
    _timer?.cancel();
    _startAutoSlide();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bigCController.dispose();
    _lotusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        // ย้อนกลับไปหน้าหลัก
        onWillPop: () async {
      Navigator.push(
          context, MaterialPageRoute(builder: (context) => MainTabView()));
      return false;
    },
    child: Scaffold(
      appBar: AppBar(title: Text('โปรโมชั่น')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: bigCPromotions.isEmpty && lotusPromotions.isEmpty
            ? Center(child: CircularProgressIndicator())
            : ListView(
          children: [
            if (bigCPromotions.isNotEmpty)
              buildPromotionSection('โปรโมชั่นจากบิ๊กซี', bigCPromotions, _bigCController, _bigCPage, (index) {
                setState(() => _bigCPage = index);
                _resetAutoSlide();
              }),
            if (lotusPromotions.isNotEmpty)
              buildPromotionSection('โปรโมชั่นจากโลตัส', lotusPromotions, _lotusController, _lotusPage, (index) {
                setState(() => _lotusPage = index);
                _resetAutoSlide();
              }),
          ],
        ),
      ),
    ),
    );
  }

  Widget buildPromotionSection(String title, List<Map<String, dynamic>> promotions, PageController controller,
      int currentPage, Function(int) onPageChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Container(
          height: 200,
          child: PageView.builder(
            controller: controller,
            itemCount: promotions.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              final promo = promotions[index];
              return PromotionCard(
                image: promo['fullImageUrl'] ?? promo['image']!,
                url: promo['url']!,
              );
            },
          ),
        ),
        SizedBox(height: 10),
        buildIndicator(promotions.length, currentPage),
        SizedBox(height: 20),
      ],
    );
  }

  Widget buildIndicator(int count, int currentPage) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
            (index) => Container(
          margin: EdgeInsets.symmetric(horizontal: 4),
          width: currentPage == index ? 12 : 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: currentPage == index ? Colors.orange : Colors.grey[400],
          ),
        ),
      ),
    );
  }
}

class PromotionCard extends StatelessWidget {
  final String image;
  final String url;

  const PromotionCard({
    required this.image,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        if (await canLaunch(url)) {
          await launch(url);
        }
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(image, height: 200, width: double.infinity, fit: BoxFit.cover),
        ),
      ),
    );
  }
}