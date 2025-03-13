import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:project/login/login.dart';
import 'package:project/login/verifyEmail.dart';
import 'package:project/main_tabview/main_tabview.dart';
import 'package:project/on_boarding/on_boarding_view.dart';

class Wrapper extends StatefulWidget {
  const Wrapper({super.key});

  @override
  State<Wrapper> createState() => _WrapperState();
}

class _WrapperState extends State<Wrapper> {

  // method สำหรับดึงสถานะ Onboarding ใน firestore user นั้นๆ
  Future<bool> _getOnboardingStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.email!.toLowerCase()).get();
      return userDoc.exists && userDoc.data()?['onboardingComplete'] == true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator()); // แสดง loading ขณะเช็ค auth
          }

          if (snapshot.hasData) {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null && user.emailVerified) { // ข้อมูล user ไม่เป็นค่า null และมีการยืนยันอีเมลแล้ว
              return FutureBuilder<bool>(
                future: _getOnboardingStatus(),
                builder: (context, onboardingSnapshot) {
                  if (onboardingSnapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator()); // รอ Firestore โหลด
                  }

                  if (onboardingSnapshot.data == true) {
                    return MainTabView(); // เคยดูแล้ว → ไปหน้า MainTabView
                  } else {
                    return OnBoardingView(); // ยังไม่เคยดู → ไป OnBoardingView
                  }
                },
              );
            } else {
              return Verifyemail(); // ถ้ายังไม่ยืนยันอีเมล → ให้ไป Verifyemail
            }
          } else {
            return Login(); // ถ้าไม่มีผู้ใช้ → ให้ไปหน้า Login
          }
        },
      ),
    );
  }
}
