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

  void _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      print('ไม่สามารถเปิดลิงก์ได้: $url');
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
        appBar: AppBar(title: Text('บุ๊กมาร์ก')),
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
                    leading: Image.network(data['image'],
                        width: 50, height: 50, fit: BoxFit.cover),
                    title: Text(data['title']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ราคา: ${data['price'] ?? 'Not Available'}',
                          style: const TextStyle(fontSize: 14, color: Colors.green),
                        ),
                        Text('แหล่งที่มาสินค้า: ${data['category'] ?? 'Not Available'}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        InkWell(
                          onTap: () {
                            final url =
                                data['id']; // ลิงค์ url ของสินค้า id นั้นๆ
                            _launchURL(url);
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
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeBookmark(doc.id),
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
