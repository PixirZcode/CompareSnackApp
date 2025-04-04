import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

import 'package:url_launcher/url_launcher.dart'; // สำหรับใช้ Timer

class Imageslider extends StatefulWidget {
  final Function (int) OnChange;
  final int currentSlide;

  const Imageslider(
      {super.key, required this.currentSlide, required this.OnChange});

  @override
  State<Imageslider> createState() => _ImagesliderState();
}

class _ImagesliderState extends State<Imageslider> {

  late PageController _pageController;
  List<Map<String, String>> imageUrls = []; // เปลี่ยนเป็น list ที่เก็บทั้ง url และ link
  late Timer _timer; // ตัวแปรสำหรับ Timer

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.currentSlide);
    _fetchPromotions();
    // ตั้ง Timer ให้เปลี่ยนหน้าในทุกๆ 3 วินาที
    _timer = Timer.periodic(Duration(seconds: 5), (timer) {
      if (_pageController.hasClients) {
        int nextPage = (_pageController.page!.toInt() + 1) % imageUrls.length;
        _pageController.animateToPage(nextPage, duration: Duration(milliseconds: 500), curve: Curves.easeInOut);
        widget.OnChange(nextPage); // แจ้งว่าเปลี่ยนหน้าแล้ว
      }
    });
  }

  Future<void> _fetchPromotions() async {
    try {
      // ดึงโปรโมชั่นจาก BigC (จำกัดแค่ 3 รายการ)
      final responseBigC = await http.get(Uri.parse('http://10.0.0.51:3000/promotions?site=bigc'));

      // ดึงโปรโมชั่นจาก Lotus (จำกัดแค่ 3 รายการ)
      final responseLotus = await http.get(Uri.parse('http://10.0.0.51:3000/promotions?site=lotus'));

      if (responseBigC.statusCode == 200 && responseLotus.statusCode == 200) {
        final dataBigC = json.decode(responseBigC.body);
        final dataLotus = json.decode(responseLotus.body);

        List<Map<String, String>> images = []; // ใช้ List<Map<String, String>> เพื่อเก็บทั้ง url และ link

        // สลับลำดับการแสดงผลโปรโมชั่นจาก BigC และ Lotus
        int lotusIndex = 0;
        int bigCIndex = 0;

        // เราจะดึงแค่ 3 รายการจากแต่ละที่
        for (int i = 0; i < 6; i++) { // รวมทั้งหมด 6 รายการ (3 จาก Lotus + 3 จาก BigC)
          if (i % 2 == 0 && bigCIndex < 3) {
            // เพิ่มรูปจาก BigC
            images.add({
              'url': dataBigC[bigCIndex]['fullImageUrl'] as String, // แปลงเป็น String
              'link': dataBigC[bigCIndex]['url'] as String // แปลงเป็น String
            });
            bigCIndex++;
          } else if (lotusIndex < 3) {
            // เพิ่มรูปจาก Lotus
            images.add({
              'url': dataLotus[lotusIndex]['image'] as String, // แปลงเป็น String
              'link': dataLotus[lotusIndex]['url'] as String // แปลงเป็น String
            });
            lotusIndex++;
          }
        }

        setState(() {
          imageUrls = images;
        });
      } else {
        throw Exception('ไม่สามารถโหลดโปรโมชั่นได้');
      }
    } catch (e) {
      print('เกิดข้อผิดพลาดในการดึงข้อมูลโปรโมชัน: $e');
    }
  }

  // เปิด URL
  Future<void> _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'ไม่สามารถเปิด $url';
    }
  }

  @override
  void dispose() {
    _timer.cancel(); // เพื่อยกเลิก Timer ป้องกัน memory leak
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          height: 220,
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: PageView(
              controller: _pageController,
              scrollDirection: Axis.horizontal,
              allowImplicitScrolling: true,
              physics: const ClampingScrollPhysics(),
              onPageChanged: (index) {
                widget.OnChange(index);
              },
              children: imageUrls.map((item) {
                return GestureDetector(
                  onTap: () => _launchURL(item['link']!), // เปิด URL เมื่อคลิกที่รูป
                  child: Image.network(
                    item['url']!,
                    fit: BoxFit.cover,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Positioned.fill(
          bottom: 10,
          left: 0,
          right: 0,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                imageUrls.length,
                (index) => AnimatedContainer(
                  duration: const Duration(microseconds: 500),
                  width: widget.currentSlide == index ? 12 : 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: widget.currentSlide == index
                          ? Colors.white
                          : Colors.white70,
                      border: Border.all(
                          color: Colors.black
                      ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
