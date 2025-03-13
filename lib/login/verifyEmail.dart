import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:project/login/wrapper.dart';
import 'package:project/welcome_view/welcome_view.dart';



class Verifyemail extends StatefulWidget {
  const Verifyemail({super.key});

  @override
  State<Verifyemail> createState() => _VerifyemailState();
}

class _VerifyemailState extends State<Verifyemail> {
  @override
  void initState() {
    sendverifylink();
    super.initState();
  }

  sendverifylink() async{
    final user = FirebaseAuth.instance.currentUser!;
    await user.sendEmailVerification().then((value) => {
      Get.snackbar('ส่งลิงก์แล้ว', 'ลิงก์ถูกส่งไปยังอีเมลของคุณแล้ว',
          margin: EdgeInsets.all(30),
          snackPosition: SnackPosition.TOP)
    });
  }

  reload() async {
    final user = FirebaseAuth.instance.currentUser!;

    // รีโหลดข้อมูลผู้ใช้เพื่ออัพเดตสถานะ emailVerified
    await user.reload();

    // รอให้ข้อมูลถูกรีเฟรชแล้วตรวจสอบสถานะ emailVerified
    final updatedUser = FirebaseAuth.instance.currentUser!;

    if (updatedUser.emailVerified) {
      // ถ้าอีเมลยืนยันแล้ว ให้นำทางไปหน้าถัดไป
      Get.offAll(Wrapper());
    } else {
      // ถ้ายังไม่ได้ยืนยันอีเมล แสดง Snackbar แจ้งเตือน
      Get.snackbar(
        'อีเมลยังไม่ได้รับการยืนยัน',
        'กรุณายืนยันอีเมล์ของคุณก่อนดำเนินการต่อ',
        margin: EdgeInsets.all(30),
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("ยืนยันบัญชี"),
        leading: IconButton(
          icon: Image.asset(
            'assets/img/btn_back.png',
            width: 24,
            height: 24,
          ),
          onPressed: () async{
            await FirebaseAuth.instance.signOut(); // บังคับตัดออกจากระบบเมื่อกดย้อนกลับไปหน้าหลักไม่งั้นจะติดวังวนของ login-verify
            Get.offAll(WelcomeView());
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Center(
          child: Text(
            'เปิดอีเมลของคุณและคลิกลิงก์เพื่อยืนยันอีเมลของคุณ จากนั้นกดถัดไป',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => reload(),
        label: Row(
          children: [
            Text("ถัดไป"),
            SizedBox(width: 5), // Space between text and icon
            Icon(Icons.arrow_right_alt),
          ],
        ),
      ),
    );
  }
}
