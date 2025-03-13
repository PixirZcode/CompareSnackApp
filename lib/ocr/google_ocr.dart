import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:project/main_tabview/main_tabview.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'vision_service.dart';

class TextDetectionScreen extends StatefulWidget {
  @override
  _TextDetectionScreenState createState() => _TextDetectionScreenState();
}

class _TextDetectionScreenState extends State<TextDetectionScreen> {
  File? imageFromGallery;
  File? _imageWithoutBg;
  String _detectedText = '';
  List<Data> datas = [];
  bool isLoading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _detectedText = 'กำลังนำพื้นหลังออก...';
        _imageWithoutBg = null;
        // เก็บไฟล์จากแกลลอรี่ไว้อันนี้เพราะจะแสดงรูปจริง ที่ทำแบบนี้เพราะรูปแสดงที่ลบพื้นหลังแล้วเวลาจะเอารูปใหม่ไปทำมันแสดงรูปเก่า
        imageFromGallery = File(pickedFile.path);
      });

      try {
        final visionService = VisionService();
        final imageWithoutBg = await visionService.removeBackground(File(pickedFile.path));

        setState(() {
          _imageWithoutBg = imageWithoutBg;
        });

        final text = await visionService.detectText(imageWithoutBg);
        setState(() {
          _detectedText = text.replaceAll('\n', ' ').replaceAll(RegExp(r'\d'), '');
        });

        if (_detectedText.isNotEmpty) {
          _showProductResults(_detectedText);
        }
      } catch (e) {
        setState(() {
          _detectedText = 'พบข้อผิดพลาด: $e';
        });
      }
    }
  }

  // สกัดตัวเลขจากชื่อสินค้า
  int extractValueFromTitle(String title) {
    final numbers = RegExp(r'\d+').allMatches(title).map((m) => int.parse(m.group(0)!)).toList();
    if (numbers.isEmpty) return 1; // ไม่มีตัวเลข
    return numbers.length > 1 ? numbers[0] * numbers[1] : numbers[0];
  }

  // method คำนวณความคุ้มค่า
  double calculateResult(int value, String price) {
    final priceNumber = double.tryParse(price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 1;
    return priceNumber > 0 ? value / priceNumber : 0;
  }

  // สกัดคำ ก. กรัม ออกที่มีในชื่อ
  String extractProductName(String title) {
    final regex = RegExp(r'(.*?)(\d+\s?(กรัม|ก\.))?$');
    final match = regex.firstMatch(title);
    if (match != null) {
      return match.group(1)?.trim() ?? '';
    }
    return title; // ส่งคืนชื่อเดิมถ้าไม่สามารถทำได้
  }


  Future<List<Data>> _fetchProducts(String query) async {
    try {
      final urls = [
        Uri.parse('http://10.0.0.85:3000/scrap?query=$query&site=bigc'),
        Uri.parse('http://10.0.0.85:3000/scrap?query=$query&site=lotus'),
      ];

      final responses = await Future.wait(urls.map((url) => http.get(url)));
      List<Data> newDatas = [];

      for (final response in responses) {
        if (response.statusCode == 200) {
          final List data = json.decode(response.body);
          newDatas.addAll(data.map((item) => Data(
            title: item['title'],
            url: item['url'],
            urlImage: item['image'],
            price: item['price'],
            category: item['category'],
            isOutOfStock: item['isOutOfStock'],
          )));
        }
      }

      return newDatas;
    } catch (e) {
      print('พบข้อผิดพลาด: $e');
      return [];
    }
  }

  void _showProductResults(String query) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return FutureBuilder<List<Data>>(
          future: _fetchProducts(query),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: MediaQuery.of(context).size.height * 0.6,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            } else if (snapshot.hasError) {
              return Center(child: Text('พบข้อผิดพลาด: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(child: Text('ไม่พบสินค้า "$query"'));
            } else {
              final datas = snapshot.data!;
              // เรียงลำดับจากความคุ้มค่ามากไปน้อย
              datas.sort((a, b) {
                final valueA = extractValueFromTitle(a.title);
                final valueB = extractValueFromTitle(b.title);
                final resultA = calculateResult(valueA, a.price);
                final resultB = calculateResult(valueB, b.price);
                return resultB.compareTo(resultA); // เรียงจากมากไปน้อย
              });
              return Container(
                height: MediaQuery.of(context).size.height * 0.6,
                padding: EdgeInsets.all(12),
                child: ListView.builder(
                  itemCount: datas.length,
                  itemBuilder: (context, index) {
                    final data = datas[index];
                    final value = extractValueFromTitle(data.title);
                    final result = calculateResult(value, data.price);
                    return ListTile(
                      leading: Image.network(data.urlImage, width: 50, height: 50),
                      title: Text(data.title, style: TextStyle(color: Colors.black)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              'ราคา: ${data.price} บาท',
                              style: TextStyle(color: Colors.green)
                          ),
                          Text(
                              'แหล่งที่มาสินค้า: ${data.category}',
                              style: TextStyle(color: Colors.grey)
                          ),
                          Text(
                            'ความคุ้มค่า: ${result.toStringAsFixed(2)} กรัม/บาท',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                      trailing: ElevatedButton(
                        onPressed: () => _openProductLink(data.url),
                        child: Text('ซื้อ', style: TextStyle(color: Colors.black)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orangeAccent,
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 8,
                          shadowColor: Colors.orange.withOpacity(0.5),
                        ),
                      ),
                    );
                  },
                ),
              );
            }
          },
        );
      },
    );
  }

  Future<void> _openProductLink(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      print('ไม่สามารถเปิด URL ได้');
    }
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
      // backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('ค้นหาด้วยรูปภาพ'),
        backgroundColor: Colors.orangeAccent, // AppBar สีส้ม
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 60),
              _imageWithoutBg == null
                  ? Text('ยังไม่ได้เลือกรูปภาพ', style: TextStyle(color: Colors.black, fontSize: 18))
                  : Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.orangeAccent,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                padding: EdgeInsets.all(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.file(
                    imageFromGallery!, //_imageWithoutBg รูปที่ไม่มีแบ็คกราว
                    width: 300,
                    height: 300,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _pickImage,
                child: Text('เลือกรูปภาพ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  backgroundColor: Colors.orangeAccent,
                  elevation: 10,
                  shadowColor: Colors.orange.withOpacity(0.5),
                  textStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
             /* SizedBox(height: 20),
              _detectedText.isEmpty
                  ? Text('ค้นหาข้อความไม่สำเร็จ', style: TextStyle(color: Colors.black))
                  : Container(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _detectedText,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black),
                ),
              ),*/
            ],
          ),
        ),
      ),
    ),
    );
  }
}

class Data {
  final String url;
  final String title;
  final String urlImage;
  final String price;
  final String category;
  final String? isOutOfStock;

  Data({
    required this.url,
    required this.title,
    required this.urlImage,
    required this.price,
    required this.category,
    this.isOutOfStock,
  });
}
