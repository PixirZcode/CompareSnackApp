import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';  // นำเข้า Firestore
import 'package:project/welcome_view/welcome_view.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class StartupView extends StatefulWidget {
  const StartupView({super.key});

  @override
  State<StartupView> createState() => _StarupViewState();
}

class _StarupViewState extends State<StartupView> {
  @override
  void initState() {
    super.initState();
    goWelcomePage();
  }

  void goWelcomePage() async {
    await Future.delayed(const Duration(seconds: 1));
    await fetchAndStoreData();
    welcomePage();
  }

  void welcomePage() {
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => const WelcomeView()));
  }

  Future<void> fetchAndStoreData() async {
    // ดึงข้อมูลจาก API ของคุณ
    var bigcData = await fetchBigcData();
    var lotusData = await fetchLotusData();
    var promotions = await fetchPromotions();

    // สร้าง Firestore instance
    FirebaseFirestore firestore = FirebaseFirestore.instance;

    // เช็คว่ามี document ที่เก็บข้อมูลสินค้าหรือไม่
    var productDocRef = firestore.collection('listproduct').doc('productData');

    // อัปเดตข้อมูลสินค้าลงใน Firestore
    await productDocRef.set({
      'bigc': bigcData,
      'lotus': lotusData,
    }, SetOptions(merge: true)); // ใช้ merge เพื่อไม่ลบข้อมูลเก่า

    // เช็คว่ามี document ที่เก็บข้อมูลโปรโมชันหรือไม่
    var promotionDocRef = firestore.collection('promotion').doc('promotionData');

    // อัปเดตข้อมูลโปรโมชันลงใน Firestore
    await promotionDocRef.set({
      'promotions': promotions,
    }, SetOptions(merge: true)); // ใช้ merge เพื่อไม่ลบข้อมูลเก่า
  }

  // ฟังก์ชันดึงข้อมูลสินค้าจาก BigC API
  Future<List<Map<String, dynamic>>> fetchBigcData() async {
    final response = await http.get(Uri.parse('http://10.0.0.85:3000/scrap?site=bigc'));
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data.map((item) => item as Map<String, dynamic>));
    } else {
      throw Exception('Failed to load BigC data');
    }
  }

  // ฟังก์ชันดึงข้อมูลสินค้าจาก Lotus API
  Future<List<Map<String, dynamic>>> fetchLotusData() async {
    final response = await http.get(Uri.parse('http://10.0.0.85:3000/scrap?site=lotus'));
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data.map((item) => item as Map<String, dynamic>));
    } else {
      throw Exception('Failed to load Lotus data');
    }
  }

  // ฟังก์ชันดึงข้อมูลโปรโมชันจากทั้ง BigC และ Lotus
  Future<List<Map<String, dynamic>>> fetchPromotions() async {
    final responseBigc = await http.get(Uri.parse('http://10.0.0.85:3000/promotions?site=bigc'));
    final responseLotus = await http.get(Uri.parse('http://10.0.0.85:3000/promotions?site=lotus'));

    List<Map<String, dynamic>> promotions = [];

    if (responseBigc.statusCode == 200) {
      List<dynamic> bigcPromotions = json.decode(responseBigc.body);
      promotions.addAll(bigcPromotions.map((item) => item as Map<String, dynamic>));
    }
    if (responseLotus.statusCode == 200) {
      List<dynamic> lotusPromotions = json.decode(responseLotus.body);
      promotions.addAll(lotusPromotions.map((item) => item as Map<String, dynamic>));
    }

    return promotions;
  }

  @override
  Widget build(BuildContext context) {
    var media = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            "assets/img/splash_bg.png",
            width: media.width,
            height: media.height,
            fit: BoxFit.contain,
          ),
          Image.asset(
            "assets/img/logo_khanom.png",
            width: media.width * 0.55,
            height: media.height * 0.55,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }
}
