import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:project/main_tabview/main_tabview.dart';
import 'package:url_launcher/url_launcher.dart';

class BookmarksPage extends StatefulWidget {
  @override
  _BookmarksPageState createState() => _BookmarksPageState();
}

class _BookmarksPageState extends State<BookmarksPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  List<String> selectedItems = [];
  bool selectAll = false;

  Future<void> _removeBookmark(String docId) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.email)
          .collection('bookmarks')
          .doc(docId)
          .delete();
      print('ลบบุ๊กมาร์กเรียบร้อยแล้ว');
    } catch (e) {
      print('เกิดข้อผิดพลาดในการลบบุ๊กมาร์ก: $e');
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

  void _toggleSelection(String docId) {
    setState(() {
      if (selectedItems.contains(docId)) {
        selectedItems.remove(docId);
      } else {
        selectedItems.add(docId);
      }
    });
  }

  void _toggleSelectAll(List<String> allDocs) {
    setState(() {
      if (selectAll) {
        selectedItems.clear();
      } else {
        selectedItems = allDocs;
      }
      selectAll = !selectAll;
    });
  }

  Future<void> _confirmDelete() async {
    if (selectedItems.isEmpty) return;

    // ยืนยันการลบ
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ยืนยันการลบ'),
        content: Text('คุณต้องการลบบุ๊กมาร์กที่เลือกใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('ยืนยัน'),
          ),
        ],
      ),
    );

    if (confirmDelete == true) {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return;

      for (String docId in selectedItems) {
        await _removeBookmark(docId);
      }

      setState(() {
        selectedItems.clear(); // ล้างรายการที่เลือกหลังจากลบเสร็จ
        selectAll = false; // รีเซ็ตการเลือกทั้งหมด
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      return Center(child: Text('กรุณาเข้าสู่ระบบ'));
    }

    return WillPopScope(
      // ย้อนกลับไปหน้าหลัก
      onWillPop: () async {
        Navigator.push(
            context, MaterialPageRoute(builder: (context) => MainTabView()));
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('บุ๊กมาร์ก'),
          actions: [
            if (selectedItems.isNotEmpty)
              IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: _confirmDelete,
              ),
            IconButton(
              icon: Icon(
                selectAll ? Icons.deselect : Icons.select_all,
                color: Colors.blue,
              ),
              onPressed: () {
                // รับเอกสารทั้งหมดจาก snapshot เพื่อเลือกทั้งหมด
                final snapshot = FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.email)
                    .collection('bookmarks');
                snapshot.get().then((querySnapshot) {
                  List<String> allDocs = querySnapshot.docs.map((doc) => doc.id).toList();
                  _toggleSelectAll(allDocs);
                });
              },
            ),
          ],
        ),
        body: StreamBuilder(
          stream: _firestore
              .collection('users')
              .doc(user.email)
              .collection('bookmarks')
              .snapshots(),
          builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(child: Text('ไม่มีบุ๊กมาร์ก'));
            }

            return ListView(
              children: snapshot.data!.docs.map((doc) {
                var data = doc.data() as Map<String, dynamic>;
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: ListTile(
                    leading: Image.network(
                        data['image'],
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover
                    ),
                    title: Text(data['title']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ราคา: ${data['price'] ?? 'Not Available'} บาท',
                          style: const TextStyle(fontSize: 14, color: Colors.green),
                        ),
                        Text('แหล่งที่มาสินค้า: ${data['shop'] ?? 'Not Available'}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        Text('ความคุ่มค่า: ${data['value'] ?? 'Not Available'}',
                          style: const TextStyle(color: Colors.red),
                        ),
                        InkWell(
                          onTap: () {
                            openUrlAndSaveOrder(data);
                          },
                          child: Text(
                            'กดเพื่อดูสินค้าต้นทาง',
                            style: TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        selectedItems.contains(doc.id)
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        color: selectedItems.contains(doc.id)
                            ? Colors.green
                            : null,
                      ),
                      onPressed: () => _toggleSelection(doc.id),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}
