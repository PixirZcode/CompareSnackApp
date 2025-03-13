import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:project/common/color_extension.dart';
import 'package:project/main_tabview/filterIngredient.dart';
import 'package:project/main_tabview/main_tabview.dart';
import 'package:project/welcome_view/welcome_view.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final ImagePicker picker = ImagePicker();
  XFile? image;
  final user = FirebaseAuth.instance.currentUser;
  String? profileUrl; // ตัวแปรในการจัดเก็บ URL โปรไฟล์

  @override
  void initState() {
    super.initState();
    // ตรวจสอบว่าผู้ใช้ลงชื่อเข้าใช้ด้วย Google และดึงข้อมูล URL โปรไฟล์ของพวกเขาหรือไม่
    if (user != null && user!.providerData.isNotEmpty) {
      final provider = user!.providerData.first;
      if (provider.providerId == "google.com") {
        profileUrl = provider.photoURL; // ดึง URL โปรไฟล์ (URL รูปภาพ)
        setState(() {});
      }
    }
  }

  signOut() async {
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();

    // นำทางไปหน้า WelcomeView และล้าง Stack
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => WelcomeView()),
          (route) => false, // ล้างเส้นทางก่อนหน้า
    );
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
    appBar: AppBar(title: const Text("โปรไฟล์")),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              const SizedBox(
                height: 46,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                ),
              ),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: TColor.placeholder,
                  borderRadius: BorderRadius.circular(50),
                ),
                alignment: Alignment.center,
                child: image != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: Image.file(File(image!.path),
                      width: 100, height: 100, fit: BoxFit.cover),
                )
                    : profileUrl != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: Image.network(
                    profileUrl!, // Show the profile picture if available
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                )
                    : Icon(
                  Icons.person,
                  size: 65,
                  color: TColor.secondaryText,
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              Text(
                '${user!.email}',
                style: TextStyle(
                    color: TColor.primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w700),
              ),

              const SizedBox(
                height: 20,
              ),

              ElevatedButton(
                onPressed: () async {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => filterIngredient()), // นำทางไปหน้า filter()
                  );
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white, // สีตัวอักษร
                  backgroundColor: Colors.deepOrange, // สีพื้นหลังปุ่ม
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8), // มุมโค้งมน
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                child: const Text("แก้ไขสิ่งที่คุณชอบ"),
              ),

              const SizedBox(height: 250),

              /// ปุ่มออกจากระบบ
              OutlinedButton(
                onPressed: () => signOut(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30), // กำหนดความโค้งเอง
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min, // ขนาดตามเนื้อหา
                  children: const [
                    Text("ออกจากระบบ"),
                    SizedBox(width: 8), // ระยะห่างระหว่างข้อความกับไอคอน
                    Icon(Icons.logout, size: 18, color: Colors.red), // ไอคอนออกจากระบบ
                  ],
                ),
              ),
            ]),
          ),
        )
    )
    );
  }
}

/* Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                child: RoundTitleTextfield(
                  title: "Name",
                  hintText: "Enter Name",
                  controller: null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                child: RoundTitleTextfield(
                  title: "Email",
                  hintText: "Enter Email",
                  keyboardType: TextInputType.emailAddress,
                  controller: null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                child: RoundTitleTextfield(
                  title: "Mobile No",
                  hintText: "Enter Mobile No",
                  controller: null,
                  keyboardType: TextInputType.phone,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                child: RoundTitleTextfield(
                  title: "Password",
                  hintText: "* * * * * *",
                  obscureText: true,
                  controller: null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                child: RoundTitleTextfield(
                  title: "Confirm Password",
                  hintText: "* * * * * *",
                  obscureText: true,
                  controller: null,
                ),
              ),
              const SizedBox(
                height: 20,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: RoundButton(title: "Save", onPressed: () {}),
              ), */