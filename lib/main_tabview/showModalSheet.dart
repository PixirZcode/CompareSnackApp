import 'dart:convert';
import 'package:redis/redis.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:string_similarity/string_similarity.dart';

Command? redisClient;
RedisConnection redisConnection = RedisConnection();

Future<void> initRedis() async {
  try {
    // เชื่อมต่อกับ Redis server (เช่นที่ localhost:6379)
    redisClient = await redisConnection.connect('10.0.0.51', 6379);
    print("✔ เชื่อมต่อกับ Redis สำเร็จ");
  } catch (e) {
    print("❌ ERROR: ไม่สามารถเชื่อมต่อ Redis: $e");
  }
}

// ฟังก์ชันสำหรับเปิด URL และบันทึกประวัติการดูสินค้า
Future<void> openUrlAndSaveOrder(Map<String, dynamic> data) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    print('User = null');
    return;
  }

  final firestore = FirebaseFirestore.instance;

  try {
    // บันทึกข้อมูลใน collection 'historys'

    await firestore
        .collection('users')
        .doc(user.email)
        .collection('historys')
        .add({
      'title': data['title'],
      'url': data['url'],
      'image': data['image'],
      'price': data['price'],
      'unit': data['unit'],
      'stockStatus': data['stockStatus'],
      'value': data['value'],
      'shop': data['shop'],
      'timestamp': FieldValue.serverTimestamp(),
    });

    // เปิด URL ใน Browser
    final Uri uri = Uri.parse(data['url']);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'ไม่สามารถเปิด URL ได้';
    }
  } catch (e) {
    print('เกิดข้อผิดพลาดในการบันทึกคำสั่งซื้อหรือการเปิด URL: $e');
  }
}

void showComparisonSheet(BuildContext context, String productName) async {

  if (redisClient == null) {
    print("🔎 เชื่อมต่อ Redis");
    await initRedis();
  }

  if (redisClient == null) {
    print("❌ Redis เป็น null ข้ามการทำงาน");
    return;
  }

  try {
    List<Map<String, dynamic>> similarProducts = [];
    double similarityThreshold = 0.6; // ตั้งค่าความคล้ายที่ 60% สูงกว่านี้อาจจะไม่ค่อยเจอ

    if (redisClient != null) {
      // ค้นหาใน Redis
      final redisBigc = await redisClient!.get('product:bigc');
      final redisLotus = await redisClient!.get('product:lotus');

      if (redisBigc != null || redisLotus != null) {
        print("✔ ค้นหาข้อมูลใน Redis BigC และ Lotus");

        List<dynamic> bigcData = redisBigc != null ? jsonDecode(redisBigc) : [];
        List<dynamic> lotusData = redisLotus != null ? jsonDecode(redisLotus) : [];

        for (var product in [...bigcData, ...lotusData]) {
          if (product is Map<String, dynamic>) {
            double similarity = productName.similarityTo(product['title'].toString());
            if (similarity >= similarityThreshold) {
              similarProducts.add(product);
            }
          }
        }
      }
    }

    if (similarProducts.isEmpty) {
      // ถ้า Redis ไม่มีข้อมูล ค้นหาใน Firestore แทน
      print("❌ ไม่พบใน Redis กำลังค้นหาใน Firestore...");
      final querySnapshot = await FirebaseFirestore.instance.collection('listproduct').get();

      for (var doc in querySnapshot.docs) {
        final data = doc.data();

        // ตรวจสอบใน BigC
        if (data.containsKey('bigc') && data['bigc'] is List) {
          for (var product in data['bigc']) {
            if (product is Map<String, dynamic>) {
              double similarity = productName.similarityTo(product['title'].toString());
              if (similarity >= similarityThreshold) {
                similarProducts.add(product);
              }
            }
          }
        }

        // ตรวจสอบใน Lotus
        if (data.containsKey('lotus') && data['lotus'] is List) {
          for (var product in data['lotus']) {
            if (product is Map<String, dynamic>) {
              double similarity = productName.similarityTo(product['title'].toString());
              if (similarity >= similarityThreshold) {
                similarProducts.add(product);
              }
            }
          }
        }
      }

      // บันทึกข้อมูลที่ค้นหาได้ลง Redis เพื่อใช้งานในอนาคต
      if (redisClient != null && similarProducts.isNotEmpty) {
        print("✔ บันทึกข้อมูลลง Redis");
        await redisClient!.set('compare:$productName', jsonEncode(similarProducts));
      }
    }

    // จัดเรียงสินค้าที่ได้จาก value มากไปน้อย
    similarProducts.sort((a, b) {
      return (b['value'] ?? 0).compareTo(a['value'] ?? 0);
    });

    // เปิด ModalBottomSheet เพื่อแสดงสินค้าที่ใกล้เคียง
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'สินค้าใกล้เคียงกับ: "$productName"',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Expanded(
                child: similarProducts.isEmpty
                    ? Center(child: Text("ไม่พบสินค้าที่ใกล้เคียง"))
                    : ListView.builder(
                  itemCount: similarProducts.length,
                  itemBuilder: (context, index) {
                    var product = similarProducts[index];
                    return ListTile(
                      leading: Image.network(
                        product['image'] ?? '',
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                      title: Text(product['title'] ?? 'ไม่มีชื่อ'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ราคา: ${product['price']} บาท',
                            style: const TextStyle(color: Colors.green),
                          ),
                          Text(
                            'แหล่งที่มาสินค้า: ${product['shop']}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          Text(
                            'ความคุ้มค่า: ${product['value']} กรัม/บาท',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                      trailing: ElevatedButton(
                        onPressed: () => openUrlAndSaveOrder(product),
                        child: const Text('ซื้อ'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  } catch (e) {
    print("❌ ERROR: $e");
  }
}