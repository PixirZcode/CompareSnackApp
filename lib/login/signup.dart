import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:project/login/login.dart';
import 'package:project/login/wrapper.dart';
import 'package:get/get.dart';

class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> {

  TextEditingController email = TextEditingController();
  TextEditingController password = TextEditingController();
  TextEditingController confirmPassword = TextEditingController();
  bool _isPasswordVisible = false;
  final _formKey = GlobalKey<FormState>();
  List<String> allowedDomains = [];
  @override
  void initState() {
    super.initState();
    loadAllowedDomains();
  }
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

  signUp() async {
    if (email.text.isEmpty || password.text.isEmpty || confirmPassword.text.isEmpty) {
      Get.snackbar("พบข้อผิดพลาด", "กรุณากรอกให้ครบทุกช่อง",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
      return;
    }

    if (password.text != confirmPassword.text) {
      Get.snackbar("พบข้อผิดพลาด", "รหัสผ่านไม่ตรงกัน",
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
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email.text, password: password.text);

      if (userCredential.user != null) {
        await _markOnboardingComplete(); // อัปเดตสถานะ Onboarding หลังจากสมัครสมาชิกสำเร็จ
        Get.offAll(Wrapper());
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        Get.snackbar("พบข้อผิดพลาด", "ที่อยู่อีเมลนี้มีการใช้งานแล้วโดยบัญชีอื่น",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white);
      } else {
        Get.snackbar("พบข้อผิดพลาด", "รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white);
      }
    }
  }

  // ฟังก์ชันเพื่ออัปเดตสถานะการดู Onboarding ใน Firestore
  Future<void> _markOnboardingComplete() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.email!.toLowerCase()).set(
        {'onboardingComplete': false},
        SetOptions(merge: true),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("สมัครสมาชิก"),),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextField(
                controller: email,
                decoration: InputDecoration(
                    hintText: 'อีเมล',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 20),

              TextField(
                controller: password,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  hintText: 'รหัสผ่าน',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      color: _isPasswordVisible ? Colors.blue : Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
              ),
              SizedBox(height: 20),

              TextField(
                controller: confirmPassword,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  hintText: 'ยืนยันรหัสผ่าน',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      color: _isPasswordVisible ? Colors.blue : Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
              ),
              SizedBox(height: 20),

              Container(
                width: double.infinity, // Make it take full width like the input box
                height: 50, // ความกว้างปุ่ม
                child: ElevatedButton(
                  onPressed: signUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade800,
                    shadowColor: Colors.transparent, // ขอบใส
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    "สมัครสมาชิก",
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("มีบัญชีอยู่แล้วใช่ไหม? "),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context, MaterialPageRoute(
                          builder: (context) => const Login()
                      ),
                      );
                    },
                    child: Text(
                      "เข้าสู่ระบบตอนนี้",
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
