import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:redis/redis.dart';
import 'vision_service.dart';
import 'package:project/main_tabview/main_tabview.dart';
import 'package:string_similarity/string_similarity.dart';

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

  RedisConnection redisConnection = RedisConnection();
  Command? redisClient;

  @override
  void initState() {
    super.initState();
    initRedis();
  }

  Future<void> initRedis() async {
    try {
      redisClient = await redisConnection.connect('10.0.0.85', 6379);
      print("✔ เชื่อมต่อกับ Redis สำเร็จ");
    } catch (e) {
      print("❌ ERROR: ไม่สามารถเชื่อมต่อ Redis: $e");
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _detectedText = 'กำลังนำพื้นหลังออก...';
        _imageWithoutBg = null;
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
          _fetchProducts(_detectedText);
        }
      } catch (e) {
        setState(() {
          _detectedText = 'พบข้อผิดพลาด: $e';
        });
      }
    }
  }

  Future<void> _fetchProducts(String query) async {
    if (redisClient == null) {
      print("❌ ERROR: redisClient ยังไม่ถูกเชื่อมต่อ");
      return;
    }

    setState(() {
      isLoading = true;
    });

    List<Data> fetchedProducts = [];
    int bigcCount = 0;
    int lotusCount = 0;

    // แยกคำจาก query และกรองคำที่สั้นเกินไป
    List<String> queryWords = query
        .toLowerCase()
        .split(' ')
        .where((word) => word.length > 2) // ตัดคำที่สั้นกว่า 3 ตัวอักษร
        .toList();

    // ฟังก์ชันคำนวณ "จำนวนคำที่ตรงกัน" เพื่อใช้เป็นคะแนน
    int calculateMatchScore(String title, List<String> queryWords) {
      int matchCount = 0;
      for (String word in queryWords) {
        double similarity = StringSimilarity.compareTwoStrings(title, word);
        if (title.contains(word) || similarity > 0.3) {
          matchCount++; // เพิ่มคะแนนหากมีคำที่ตรงกัน
        }
      }
      return matchCount;
    }

    // ฟังก์ชันตรวจสอบว่าสินค้าตรงกับ query หรือไม่
    bool isQueryMatch(Map<String, dynamic> product, List<String> queryWords) {
      String title = product['title']?.toLowerCase() ?? '';
      return calculateMatchScore(title, queryWords) > 0; // ตราบใดที่มีคำตรงกัน 1 คำขึ้นไป ถือว่า match
    }

    // ฟังก์ชันค้นหาสินค้าในรายการ พร้อมจำกัดจำนวน
    Future<void> searchInList(List<dynamic> productList, String shopName) async {
      for (var product in productList) {
        if (product is Map<String, dynamic>) {
          if ((shopName == "BigC" && bigcCount < 30) || (shopName == "Lotus" && lotusCount < 30)) {
            if (isQueryMatch(product, queryWords)) {
              Data data = Data.fromMap({...product, 'shop': shopName});
              fetchedProducts.add(data);
              if (shopName == "BigC") {
                bigcCount++;
              } else {
                lotusCount++;
              }
            }
          }
        }
      }
    }

    try {
      final redisBigc = await redisClient!.get('product:bigc');
      final redisLotus = await redisClient!.get('product:lotus');

      if (redisBigc != null && redisBigc is String) {
        final decodedBigc = jsonDecode(redisBigc) as List<dynamic>;
        await searchInList(decodedBigc, "BigC");
      }

      if (redisLotus != null && redisLotus is String) {
        final decodedLotus = jsonDecode(redisLotus) as List<dynamic>;
        await searchInList(decodedLotus, "Lotus");
      }

      if (fetchedProducts.isEmpty) {
        print("❌ ไม่มีข้อมูลที่เกี่ยวข้องใน Redis, ค้นหาใน Firestore");

        final querySnapshot = await FirebaseFirestore.instance.collection('listproduct').get();
        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          if (data.containsKey('bigc')) {
            await searchInList(data['bigc'] as List<dynamic>, "BigC");
          }
          if (data.containsKey('lotus')) {
            await searchInList(data['lotus'] as List<dynamic>, "Lotus");
          }
        }
      }

      // 🔥 จัดลำดับสินค้าให้ "ตรงมากสุดก่อน" แล้วตามด้วย "ความคุ้มค่า"
      fetchedProducts.sort((a, b) {
        int matchScoreA = calculateMatchScore(a.title.toLowerCase(), queryWords);
        int matchScoreB = calculateMatchScore(b.title.toLowerCase(), queryWords);

        // 🔹 ถ้าคะแนน matchCount ต่างกัน ให้เรียงจากมากไปน้อย
        if (matchScoreA != matchScoreB) {
          return matchScoreB.compareTo(matchScoreA);
        }

        // 🔹 ถ้าคะแนนเท่ากัน ให้เรียงตาม "ความคุ้มค่า" (value สูงสุดมาก่อน)
        return b.value.compareTo(a.value);
      });

      setState(() {
        datas = fetchedProducts;
        isLoading = false;
      });

      // Show the fetched products in the modal bottom sheet
      if (datas.isNotEmpty) {
        _showProductModal();
      }

      print("✔ สินค้าที่แสดง: ${datas.length} ชิ้น");
    } catch (e) {
      print("❌ ERROR: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

// แสดงสินค้าแบบ showmodalsheet
  void _showProductModal() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: ListView.builder(
            itemCount: datas.length,
            itemBuilder: (context, index) {
              final data = datas[index];
              return Card(
                elevation: 3,
                margin: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                child: ListTile(
                  contentPadding: EdgeInsets.all(10),
                  leading: Image.network(
                    data.urlImage,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.broken_image, size: 60);
                    },
                  ),
                  title: Text(
                    data.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("ราคา: ${data.price} บาท",
                          style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold)),
                      Text("ความคุ้มค่า: ${data.value} กรัม/บาท",
                          style: TextStyle(
                              color: Colors.deepOrange,
                              fontWeight: FontWeight.bold)),
                      Text("แหล่งที่มา: ${data.shop}",
                          style: TextStyle(
                              color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  trailing: ElevatedButton(
                    onPressed: () => openUrlAndSaveOrder(data),
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
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> openUrlAndSaveOrder(Data data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('User = null');
      return;
    }

    final firestore = FirebaseFirestore.instance;

    try {
      // บันทึกข้อมูลใน collection 'historys'
      String imageUrl = data.urlImage;

      await firestore
          .collection('users')
          .doc(user.email)
          .collection('historys')
          .add({
        'title': data.title,
        'url': data.url,
        'urlImage': imageUrl, // ใช้แบบนี้เพราะค่าใน Redis เก็บเป็น image แต่ history ใน firestore เป็น urlImage เลยต้องเลือกอันใดอันนึง
        'price': data.price,
        'unit': data.unit,
        'stockStatus': data.stockStatus,
        'value': data.value,
        'shop': data.shop,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // เปิด URL ใน Browser
      final Uri uri = Uri.parse(data.url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'ไม่สามารถเปิด URL ได้';
      }
    } catch (e) {
      print('เกิดข้อผิดพลาดในการบันทึกคำสั่งซื้อหรือการเปิด URL: $e');
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
                SizedBox(height: 20),

                // แสดงข้อความโหลดข้อมูล
                if (isLoading)
                  CircularProgressIndicator()
                // ถ้าไม่มีสินค้าให้แสดงข้อความ
                else if (datas.isEmpty)
                  Text('ไม่พบสินค้า', style: TextStyle(fontSize: 18))
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Data {
  final String url, title, urlImage, unit, stockStatus, shop;
  final double price, value;

  Data({
    required this.url,
    required this.title,
    required this.urlImage,
    required this.price,
    required this.unit,
    required this.stockStatus,
    required this.value,
    required this.shop,
  });

  factory Data.fromMap(Map<String, dynamic> map) {
    return Data(
      url: map['url'] ?? '',
      title: map['title'] ?? '',
      urlImage: map['image'] ?? '',
      price: (map['price'] is int) ? (map['price'] as int).toDouble() : double.tryParse(map['price'].toString()) ?? 0.0,
      unit: map['unit'] ?? '',
      stockStatus: map['stockStatus'] ?? '',
      value: double.tryParse(map['value'].toString()) ?? 0.0,
      shop: map['shop'] ?? '',
    );
  }

  // เพิ่ม Method toMap() เพื่อใช้กับ jsonEncode()
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'url': url,
      'urlImage': urlImage,
      'price': price,
      'unit': unit,
      'stockStatus': stockStatus,
      'value': value,
      'shop': shop,
    };
  }
}