import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project/main_tabview/main_tabview.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("ประวัติการเข้าชม")),
        body: const Center(child: Text("กรุณาเข้าสู่ระบบเพื่อดูประวัติของคุณ")),
      );
    }

    final historysRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.email)
        .collection('historys')
        .orderBy('timestamp', descending: true);

    return WillPopScope(
        // ย้อนกลับไปหน้าหลัก
        onWillPop: () async {
      Navigator.push(
          context, MaterialPageRoute(builder: (context) => MainTabView()));
      return false;
    },
    child: Scaffold(
      appBar: AppBar(title: const Text("ประวัติการเข้าชม")),
      body: StreamBuilder<QuerySnapshot>(
        stream: historysRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text("เกิดข้อผิดพลาดในการโหลดประวัติการเข้าชม"));
          }

          final historys = snapshot.data?.docs ?? [];

          if (historys.isEmpty) {
            return const Center(child: Text("ไม่พบประวัติการเข้าชม"));
          }

          return ListView.builder(
            itemCount: historys.length,
            itemBuilder: (context, index) {
              final order = historys[index].data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: ListTile(
                  leading: order['image'] != null && order['image'] != ''
                      ? Image.network(
                    order['image'],
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.broken_image);
                    },
                  )
                      : const Icon(Icons.broken_image),
                  title: Text(order['title'] ?? 'No Title',
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ราคา: ${order['price'] ?? 'Not Available'}',
                          style: const TextStyle(fontSize: 14, color: Colors.green),
                      ),
                      Text('แหล่งที่มาสินค้า: ${order['category'] ?? 'Not Available'}',
                          style: const TextStyle(color: Colors.grey),
                      ),
                      Text(
                        order['timestamp'] != null
                            ? 'เข้าชมเมื่อ: ${DateFormat('dd/MM/yyyy HH:mm').format(
                            DateTime.fromMillisecondsSinceEpoch(order['timestamp'].seconds * 1000).toLocal())}'
                            : 'เข้าชมเมื่อ: ไม่ระบุ',
                        style: const TextStyle(fontSize: 14, color: Colors.black),
                      ),
                      InkWell(
                        onTap: () async {
                          final url = order['id'];
                          if (url != null && url.isNotEmpty) {
                            final Uri uri = Uri.parse(url);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("ไม่สามารถเปิดลิงก์ได้")),
                              );
                            }
                          }
                        },
                        child: Text(
                          "กดเพื่อดูสินค้าต้นทาง",
                          style: TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline, // ขีดเส้นใต้เหมือนลิงก์เว็บ
                          ),
                        ),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                        Icons.delete,
                        color: Colors.red),
                    onPressed: () async {
                      final historysId = historys[index].id;
                      try {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.email)
                            .collection('historys')
                            .doc(historysId)
                            .delete();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("ลบประวัติการเข้าชมเรียบร้อยแล้ว!")),
                        );
                      } catch (error) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("เกิดข้อผิดพลาดในการลบประวัติการเข้าชม: $error")),
                        );
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      ),
    );
  }
}
