import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart' show rootBundle;

class Forgot extends StatefulWidget {
  const Forgot({super.key});

  @override
  State<Forgot> createState() => _ForgotState();
}

class _ForgotState extends State<Forgot> {

  TextEditingController email = TextEditingController();
  List<String> allowedDomains = [];

  Future<void> loadAllowedDomains() async {
    try {
      String fileContent = await rootBundle.loadString('assets/providers.txt');
      setState(() {
        allowedDomains = fileContent.split('\n').map((e) => e.trim()).toList();
      });
    } catch (e) {
      print("เกิดข้อผิดพลาดในการโหลดโดเมนผู้ให้บริการ: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    loadAllowedDomains();
  }

  reset() async{
    if (email.text.isEmpty) {
      Get.snackbar("พบข้อผิดพลาด", "กรุณากรอกให้ครบทุกช่อง",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
      return;
    }

    // ตรวจสอบรูปแบบอีเมล
    final emailPattern = RegExp(r"^[a-zA-Z0-9._%+-]+@([a-zA-Z0-9.-]+\.[a-zA-Z]{2,})$");
    if (!emailPattern.hasMatch(email.text)) {
      Get.snackbar("พบข้อผิดพลาด", "รูปแบบอีเมลไม่ถูกต้อง",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
      return;
    }

    // ตรวจสอบโดเมนจากไฟล์
    String? domain = email.text.split('@').last;
    if (!allowedDomains.contains(domain)) {
      Get.snackbar("พบข้อผิดพลาด", "ไม่รองรับผู้ให้บริการอีเมล",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
      return;
    }

    try {
      // เข้าถึง document โดยใช้ email เป็น documentId
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(email.text) // ใช้อีเมลเป็น ID ของ document
          .get();

      // ตรวจสอบว่าพบเอกสารหรือไม่
      if (!userDoc.exists) {
        Get.snackbar("พบข้อผิดพลาด", "ไม่พบข้อมูลอีเมลนี้ในระบบ",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white);
        return;
      }

      // ถ้ามีข้อมูล แสดงข้อความสำเร็จ
      Get.snackbar("สำเร็จ", "ลิงก์รีเซ็ตรหัสผ่านถูกส่งไปยังอีเมลของคุณแล้ว",
          snackPosition: SnackPosition.TOP,
        margin: EdgeInsets.all(30),);
      // ส่งลิงก์รีเซ็ตรหัสผ่าน
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.text);

    } on FirebaseAuthException catch (e) {
      Get.snackbar("พบข้อผิดพลาด", e.toString(),
          backgroundColor: Colors.red,
          colorText: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("ลืมรหัสผ่าน"),),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text("กรุณากรอกบัญชีที่คุณต้องการรีเซ็ตรหัสผ่าน"),
            SizedBox(height: 10),

            TextField(
              controller: email,
              decoration: InputDecoration(hintText: 'กรอกอีเมลของคุณ'),
            ),
            SizedBox(height: 20),

            ElevatedButton(
              onPressed: (()=>reset()),
              style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              shadowColor: Colors.transparent, // ขอบใส
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ), child: Text("ส่งลิงค์",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            ),
          ],
        ),
      ),
    );
  }
}
