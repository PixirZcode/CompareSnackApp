import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:project/login/forgot.dart';
import 'package:project/login/signup.dart';
import 'package:flutter/services.dart' show rootBundle;

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {

  TextEditingController email = TextEditingController();
  TextEditingController password = TextEditingController();
  bool isLoading = false;
  bool _isPasswordVisible = false;
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

  signIn() async {
    if (email.text.isEmpty || password.text.isEmpty) {
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

    setState(() {
      isLoading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email.text, password: password.text);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        Get.snackbar("พบข้อผิดพลาด", "รหัสผ่านไม่ถูกต้อง โปรดลองอีกครั้ง",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white);
      } else if (e.code == 'invalid-credential') {
        Get.snackbar("พบข้อผิดพลาด", "โปรดตรวจสอบให้แน่ใจว่าอีเมลและรหัสผ่านของคุณถูกต้อง",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white);
      } else {
        Get.snackbar("พบข้อผิดพลาด", e.code,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white);
      }
    } catch (e) {
      Get.snackbar("พบข้อผิดพลาด", e.toString(),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
    }

    setState(() {
      isLoading = false;
    });
  }

  signInGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    final GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth?.accessToken,
      idToken: googleAuth?.idToken,
    );
    await FirebaseAuth.instance.signInWithCredential(credential);

  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? Center(child: CircularProgressIndicator())
        : Scaffold(
      appBar: AppBar(
        title: Text("ลงชื่อเข้าใช้"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
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

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Get.to(Forgot()),
                child: Text(
                  "ลืมรหัสผ่าน ?",
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ),

            Container(
              width: double.infinity, // Make it take full width like the input box
              height: 50, // ความกว้างปุ่ม
              child: ElevatedButton(
                onPressed: signIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade800,
                  shadowColor: Colors.transparent, // ขอบใส
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  "เข้าสู่ระบบ",
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
              ),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("ยังไม่มีบัญชี? "),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context, MaterialPageRoute(
                        builder: (context) => const Signup()
                    ),
                    );
                  },
                  child: Text(
                    "สมัครสมาชิก",
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ],
            ),

            SizedBox(height: 20),
            Text("หรือ เข้าสู่ระบบด้วย"),
            SizedBox(height: 5),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround, // Distribute buttons evenly
              children: [
                // Google
                Container(
                  child: ElevatedButton.icon( // เป็นปุ่มที่สามารถมีทั้งรูปและข้อความด้วยกันได้
                    onPressed: () async {
                      await signInGoogle();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent, // พื้นหลังใส
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Image.asset(
                      "assets/img/logo_google.png",
                      width: 25,
                      height: 25,
                    ),
                    label: Text(
                      "Google",
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}