import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:project/main_tabview/main_tabview.dart';
import 'package:project/ocr/google_ocr.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

class Scarping_Product extends StatefulWidget {
  const Scarping_Product({super.key});

  @override
  State<Scarping_Product> createState() => _Scarping_ProductState();
}

class _Scarping_ProductState extends State<Scarping_Product> {
  List<Data> datas = [];
  final TextEditingController _searchController = TextEditingController();
  String resultMessage = ''; // ข้อความสำหรับแสดงผลลัพธ์ค้นหา
  String selectedSortPrice = 'all'; // sort ราคา
  String selectedShop = 'all'; // ค่า Dropdown เริ่มต้น all sort shop
  bool isExpanded = false; // ตัวแปรสำหรับควบคุมการแสดงผลของคำค้นหาที่ซ่อนอยู่
  String favIngre = ''; // ตัวแปรสำหรับเก็บ Ingredient ที่เลือก
  String selectedPackageType = 'all'; // all, ชิ้น, แพ็ค
  bool isLoading = false;

  // แสดงสินค้าเมื่อเปิดแอปด้วยคีย์เวิร์ด Products จากสินค้าทั้ง 2 แหล่ง
  @override
  void initState() {
    super.initState();
    fetchFavIngre(); // ดึงค่าจาก Firestore แล้วใช้ค้นหา
  }

  // ดึง ingredients ที่มีค่า true จาก Firestore
  Future<void> fetchFavIngre() async {
    String userEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    if (userEmail.isEmpty) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userEmail).get();
      if (doc.exists && doc.data()?['ingredients'] != null) {
        final ingredients = Map<String, dynamic>.from(doc.data()?['ingredients']);
        final selectedIngredients = ingredients.entries
            .where((entry) => entry.value == true)
            .map((entry) => entry.key)
            .toList();

        setState(() {
          favIngre = (selectedIngredients.isNotEmpty ? 'ขนม ' + selectedIngredients.join(', ') : 'ขนม');
        });
      }
    } catch (e) {
      print('เกิดข้อผิดพลาดในการดึงข้อมูล FavIngre: $e');
    } finally {
      getWebsiteData(favIngre, showResultMessage: false); // ใช้ favIngre ในการค้นหาเริ่มต้น
    }
  }

  // method เกี่ยวกับแสดงข้อมูล
  Future<void> getWebsiteData(String query, {bool showResultMessage = true}) async {
    setState(() {
      isLoading = true;
      if (showResultMessage) resultMessage = '';
    });

    try {
      final urls = <Uri>[];
      if (selectedShop == 'bigc' || selectedShop == 'all') {
        urls.add(Uri.parse('http://10.0.0.85:3000/scrap?query=$query&site=bigc'));
      }
      if (selectedShop == 'lotus' || selectedShop == 'all') {
        urls.add(Uri.parse('http://10.0.0.85:3000/scrap?query=$query&site=lotus'));
      }

      final responses = await Future.wait(urls.map((url) => http.get(url)));
      final List<Data> newDatas = [];

      for (final response in responses) {
        if (response.statusCode == 200) {
          final List data = json.decode(response.body);
          newDatas.addAll(data.map((item) => Data(
            title: item['title'],
            url: item['url'],
            urlImage: item['image'],
            price: item['price'],
            category: item['category'],
            isOutOfStock: item['isOutOfStock'],
          )));
        }
      }

      final limitedDatas = newDatas.take(60).toList();

      // โหลด bookmarks แล้วเช็กว่าแต่ละบทความถูก bookmark หรือไม่
      final bookmarkedUrls = await fetchBookmarks();
      for (var data in limitedDatas) {
        data.isBookmarked = bookmarkedUrls.contains(data.url);
      }

      if (mounted) {
        setState(() {
          datas = limitedDatas;
          if (showResultMessage && query != favIngre) {
            resultMessage = 'ค้นหา "$query เจอ ${datas.length} ผลลัพธ์';
          }
          sortPriceDatas();
        });
      }
    } catch (e) {
      print('พบข้อผิดพลาด: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          if (datas.isEmpty && showResultMessage && query != favIngre) {
            resultMessage = 'ไม่พบผลลัพธ์ "$query"';
          }
        });
      }
    }
  }

  // method เรียงราคา น้อย>มาก/มาก>น้อย
  void sortPriceDatas() {
    if (selectedSortPrice == 'Low to High') {
      datas.sort((a, b) => double.tryParse(a.price.replaceAll(RegExp(r'[^\d.]'), ''))?.compareTo(double.tryParse(b.price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0) ?? 0);
    } else if (selectedSortPrice == 'High to Low') {
      datas.sort((a, b) => double.tryParse(b.price.replaceAll(RegExp(r'[^\d.]'), ''))?.compareTo(double.tryParse(a.price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0) ?? 0);
    }
  }

  // method สำหรับเปิดกดเปิดลิงค์แล้วแสดงใน browser
  Future<void> openUrlAndSaveOrder(Data data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('User = null');
      return;
    }

    final firestore = FirebaseFirestore.instance;

    try {
      await firestore
          .collection('users')
          .doc(user.email)
          .collection('historys')
          .add({
        'id': data.url,
        'title': data.title,
        'price': data.price,
        'image': data.urlImage,
        'category': data.category,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // เปิด URL ให้ขึ้นใน Browser
      final Uri uri = Uri.parse(data.url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'ไม่สามารถเปิด URL ได้';
      }
    } catch (e) {
      print('เกิดข้อผิดพลาดในการบันทึกคำสั่งซื้อหรือการเปิด URL: $e');
    }
  }

  // ดึงข้อมูล bookmarks จาก firestore
  Future<Set<String>> fetchBookmarks() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};

    final bookmarksRef = FirebaseFirestore.instance.collection('users').doc(user.email).collection('bookmarks');
    final snapshot = await bookmarksRef.get();

    return snapshot.docs.map((doc) => doc['id'] as String).toSet();
  }

  // เพิ่มข้อมูล bookmarks เข้า firestore
  Future<void> addToBookmarks(Data data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid.isEmpty) {
      print('ผู้ใช้ไม่ได้เข้าสู่ระบบ');
      return;
    }

    print('ผู้ใช้ UID: ${user.uid}');
    final _firestore = FirebaseFirestore.instance;

    final bookmarksPath = 'users/${user.email}/bookmarks';
    print('Path บุ๊กมาร์ก: $bookmarksPath');

    final bookmarksRef = _firestore.collection('users').doc(user.email).collection('bookmarks');
    if (user.uid == null || user.uid.trim().isEmpty) {
      throw Exception('UID ผู้ใช้ไม่ถูกต้อง: ${user.uid}');
    }
    final docPath = 'users/${user.email}';
    if (docPath.contains('//')) {
      throw Exception('Path Firestore ไม่ถูกต้อง: $docPath');
    }

    try {
      await bookmarksRef.add({
        'id': data.url, // or a unique identifier for the product
        'title': data.title,
        'price': data.price,
        'image': data.urlImage,
        'category': data.category,
      });
      setState(() {
        data.isBookmarked = true;
      });
      print('เพิ่มบุ๊กมาร์กเรียบร้อยแล้ว');
    } catch (e) {
      print('เกิดข้อผิดพลาดในการเพิ่มบุ๊กมาร์ก: $e');
    }
  }

  // ลบ bookmarks ออกจาก firestore
  Future<void> removeFromBookmarks(Data data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid.isEmpty) {
      print('ผู้ใช้ไม่ได้เข้าสู่ระบบ');
      return;
    }

    final _firestore = FirebaseFirestore.instance;

    final bookmarksRef = _firestore.collection('users').doc(user.email).collection('bookmarks');
    try {
      final querySnapshot = await bookmarksRef.where('id', isEqualTo: data.url).get();
      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
      }

      setState(() {
        data.isBookmarked = false;
      });
      print('ลบบุ๊กมาร์กเรียบร้อยแล้ว');
    } catch (e) {
      print('เกิดข้อผิดพลาดในการลบบุ๊กมาร์ก: $e');
    }
  }

  // สกัดตัวเลขจากชื่อสินค้า
  int extractValueFromTitle(String title) {
    final numbers = RegExp(r'\d+').allMatches(title).map((m) => int.parse(m.group(0)!)).toList();
    if (numbers.isEmpty) return 1; // ไม่มีตัวเลข
    return numbers.length > 1 ? numbers[0] * numbers[1] : numbers[0];
  }

  // method คำนวณความคุ้มค่า กรัม หาร ราคาสินค้า
  double calculateResult(int value, String price) {
    final priceNumber = double.tryParse(price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 1;
    return priceNumber > 0 ? value / priceNumber : 0;
  }

  // สกัดคำ ก. กรัม ออกที่มีในชื่อ
  String extractProductName(String title) {
    final regex = RegExp(r'(.*?)(\d+\s?(กรัม|ก\.))?$');
    final match = regex.firstMatch(title);
    if (match != null) {
      return match.group(1)?.trim() ?? '';
    }
    return title; // ส่งคืนชื่อเดิมถ้าไม่สามารถทำได้
  }

  // ดึงข้อมูลสินค้าที่เปรียบเทียบ(ใช้วิธีนำชื่อสินค้าที่สนใจไปค้นหาในเว็บอีกที)
  Future<List<Data>> fetchComparisonProducts(String productName) async {
    final urls = <Uri>[
      Uri.parse('http://10.0.0.85:3000/scrap?query=$productName&site=bigc'),
      Uri.parse('http://10.0.0.85:3000/scrap?query=$productName&site=lotus'),
    ];

    try {
      final responses = await Future.wait(urls.map((url) => http.get(url)));

      final List<Data> comparedProducts = [];
      for (final response in responses) {
        if (response.statusCode == 200) {
          final List data = json.decode(response.body);
          comparedProducts.addAll(data.map((item) => Data(
            title: item['title'],
            url: item['url'],
            urlImage: item['image'],
            price: item['price'],
            category: item['category'],
            isOutOfStock: item['isOutOfStock'],
          )));
        }
      }
      return comparedProducts;
    } catch (e) {
      print('เกิดข้อผิดพลาดในการดึงข้อมูลสินค้าเปรียบเทียบ: $e');
      return [];
    }
  }

  // method สำหรับเปรียบเทียบ และ ส่วนแสดงผล
  void showComparisonModal(Data data) async {
    final productName = extractProductName(data.title);

    // แสดง showModalBottomSheet
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(12.0),
          height: 500,
          child: Column(
            children: [
              Image.network(
                data.urlImage,
                height: 100,
                width: 100,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 100),
              ),
              Text(
                'เปรียบเทียบ: ${data.title}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              // ตัวโหลดหมุนๆ
              Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ],
          ),
        );
      },
    );

    // ดึงข้อมูลเปรียบเทียบสินค้า
    final comparedProducts = await fetchComparisonProducts(productName);

    final List<Map<String, dynamic>> productsWithResults = comparedProducts.map((product) {
      final value = extractValueFromTitle(product.title);
      final result = calculateResult(value, product.price);
      return {
        'product': product,
        'result': result,
      };
    }).toList();

    productsWithResults.sort((a, b) => b['result'].compareTo(a['result']));

    final sortedProducts = productsWithResults.map((e) => e['product']).toList();

    // ปิดโหลดหมุนๆจากนั้นแสดงผล
    Navigator.pop(context);

    // ส่วนแสดงผลหลังจากที่เรียงลำดับความคุ้มจากมาก > น้อย
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(12.0),
          height: 500,
          child: Column(
            children: [
              Image.network(
                data.urlImage,
                height: 100,
                width: 100,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 100),
              ),
              Text(
                'เปรียบเทียบ: ${data.title}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              sortedProducts.isNotEmpty
                  ? Expanded(
                child: ListView.builder(
                  itemCount: sortedProducts.length,
                  itemBuilder: (context, index) {
                    final comparedProduct = sortedProducts[index];
                    final value = extractValueFromTitle(comparedProduct.title);
                    final result = calculateResult(value, comparedProduct.price);

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      child: ListTile(
                        leading: Image.network(
                          comparedProduct.urlImage,
                          height: 50,
                          width: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.broken_image),
                        ),
                        title: Text(comparedProduct.title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ราคา: ${comparedProduct.price}',
                              style: const TextStyle(color: Colors.green),
                            ),
                            Text(
                              'แหล่งที่มาสินค้า: ${comparedProduct.category}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                            Text(
                              'ความคุ้มค่า: ${result.toStringAsFixed(2)} กรัม/บาท',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: () => openUrlAndSaveOrder(comparedProduct),
                          child: const Text('ซื้อ'),
                        ),
                      ),
                    );
                  },
                ),
              )
                  : const Center(
                child: Text(
                  'ไม่มีสินค้าที่ตรงกันในแหล่งต่างๆ',
                  style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // กรองชิ้น/แพ็ค
  List<Data> filterDatas() {
    return datas.where((data) {
      final title = data.title.toLowerCase(); // แปลงเป็นตัวพิมพ์เล็ก
      final RegExp packRegex = RegExp(r'x\s?\d+', caseSensitive: false); // คำว่า 'X' ตามด้วยตัวเลข เช่น X10, X 10
      final RegExp packBoxRegex = RegExp(r'\d+\s?ซอง', caseSensitive: false); // คำว่า 'ซอง' ตามด้วยตัวเลข เช่น 10ซอง, 10 ซอง
      final RegExp packFongRegex = RegExp(r'\d+\s?ฟอง', caseSensitive: false); // คำว่า 'ฟอง' ตามด้วยตัวเลข เช่น 10ฟอง, 10 ฟอง

      final isPack = title.contains('แพ็ค') || packRegex.hasMatch(title) || packBoxRegex.hasMatch(title) || packFongRegex.hasMatch(title);

      if (selectedPackageType == 'all') {
        return true; // แสดงทั้งหมด
      } else if (selectedPackageType == 'pack') {
        return isPack; // แสดงเฉพาะแพ็ค
      } else {
        return !isPack; // แสดงเฉพาะชิ้น
      }
    }).toList();
  }

  // เซฟประวัติการพิมพ์ค้นหาชื่อสินค้า
  Future<void> saveSearchHistory(String query) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    final String userEmail = user.email!;
    final historyRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userEmail)
        .collection('search_history');

    final batch = FirebaseFirestore.instance.batch();

    // ค้นหาคำค้นหาที่ซ้ำกัน
    final querySnapshot = await historyRef.where('query', isEqualTo: query).get();

    // ลบข้อมูลเก่า
    for (var doc in querySnapshot.docs) {
      batch.delete(doc.reference);
    }

    // เพิ่มข้อมูลใหม่
    final newDocRef = historyRef.doc(); // สร้าง document ใหม่
    batch.set(newDocRef, {
      'query': query,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // ดำเนินการทั้งหมดใน batch
    await batch.commit();
  }

  // ดึงประวัติการพิมพ์ค้นหาชื่อสินค้า
  Future<List<String>> getSearchHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return [];

    final String userEmail = user.email!;
    final historyRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userEmail)
        .collection('search_history')
        .orderBy('timestamp', descending: true)
        .limit(5);

    final snapshot = await historyRef.get();
    return snapshot.docs.map((doc) => doc['query'] as String).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
      title: Text("ค้นหาสินค้า"),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => MainTabView()),
            );
          },
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.all(5),
                        height: 50,
                        width: MediaQuery.of(context).size.width / 1.5,
                        decoration: BoxDecoration(
                          color: Colors.black12.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12.withOpacity(0.05),
                              blurRadius: 2,
                              spreadRadius: 1,
                            ),
                          ],
                        ),

                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: 'ค้นหาสินค้า',
                            suffixIcon: ElevatedButton(
                              style: ElevatedButton.styleFrom(// ปรับขนาดให้เท่ากับความสูงของ Container
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10), // ขอบโค้งมน
                                ),
                                backgroundColor: Colors.white.withOpacity(0.7), // ปรับความทึบของพื้นหลัง
                              ),
                              onPressed: () {
                                final query = _searchController.text.trim();
                                if (query.isNotEmpty) {
                                  saveSearchHistory(query); // บันทึกการค้นหา
                                  getWebsiteData(query, showResultMessage: true);
                                } else {
                                  getWebsiteData('ขนม', showResultMessage: true);
                                }
                              },
                              child: const Text(
                                'ค้นหา',
                                style: TextStyle(color: Colors.black), // สีข้อความ
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 35),
                    Container(
                      height: 50,
                      width: MediaQuery.of(context).size.width / 6,
                      decoration: BoxDecoration(
                          color: Colors.black12.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12.withOpacity(0.05),
                              blurRadius: 2,
                              spreadRadius: 1,
                            )
                          ]),
                      child: GestureDetector(
                        onTap: () {
                          // ไปยังหน้าใหม่
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => TextDetectionScreen()),
                          );
                        },
                        child: Center(
                          child: Icon(Icons.camera_alt_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
                FutureBuilder<List<String>>(
                  future: getSearchHistory(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const SizedBox(); // ไม่แสดงอะไรถ้าไม่มีประวัติ
                    }
                    final history = snapshot.data!;
                    final displayedHistory = isExpanded ? history : history.take(3).toList();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 4.0),
                          child: Text('ประวัติการค้นหา:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        Wrap(
                          spacing: 6,
                          children: displayedHistory.map((query) {
                            return GestureDetector(
                              onTap: () {
                                _searchController.text = query;
                                getWebsiteData(query, showResultMessage: true);
                              },
                              child: Chip(
                                label: Text(
                                  query,
                                  style: TextStyle(fontSize: 12), // ปรับขนาดตัวอักษร
                                ),
                                deleteIcon: const Icon(Icons.close),
                                visualDensity: VisualDensity.compact, // ลด padding ใน Chip
                                onDeleted: () async {
                                  final user = FirebaseAuth.instance.currentUser;
                                  if (user != null) {
                                    final userEmail = user.email!.toLowerCase(); // ใช้อีเมลเป็น key
                                    final historyRef = FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(userEmail)
                                        .collection('search_history');

                                    final querySnapshot = await historyRef
                                        .where('query', isEqualTo: query)
                                        .get();

                                    for (var doc in querySnapshot.docs) {
                                      await doc.reference.delete(); // ลบประวัติ
                                    }
                                    setState(() {});
                                  }
                                },
                              ),
                            );
                          }).toList(),
                          ),
                          // ปุ่ม "More" เพื่อแสดงคำค้นหาที่ซ่อนอยู่(สำหรับ Recent Search)
                          if (history.length > 3)
                              TextButton(
                                onPressed: () {
                                setState(() {
                                  isExpanded = !isExpanded; // สลับสถานะของ isExpanded
                                });
                              },
                                child: Text(isExpanded ? 'แสดงน้อยลง' : 'แสดงเพิ่มเติม'), // ปรับข้อความให้แสดงตามสถานะ
                          ),
                      ],
                    );
                  },
                ),
                if (resultMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      resultMessage,
                      style: const TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),
                  ),

                // ส่วน Dropdown
                SizedBox(
                  height: 50,
                  child: Row(
                    children: [
                      // ส่วน Dropdown
                      Spacer(),
                      DropdownButton<String>(
                        value: selectedShop,
                        onChanged: (String? newValue) {
                          setState(() {
                            selectedShop = newValue ?? 'all';
                            final query = _searchController.text.trim().isEmpty ? favIngre : _searchController.text.trim();
                            getWebsiteData(query, showResultMessage: _searchController.text.trim().isNotEmpty);
                          });
                        },
                        items: <String>['all', 'bigc', 'lotus']
                            .map<DropdownMenuItem<String>>((String value) {
                          String displayValue = value == 'all' ? 'ร้านค้า' : value.toUpperCase();
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(displayValue, style: TextStyle(fontSize: 14)),
                          );
                        }).toList(),
                      ),

                      Spacer(),
                      DropdownButton<String>(
                        value: selectedPackageType,
                        onChanged: (String? newValue) {
                          setState(() {
                            selectedPackageType = newValue ?? 'all';
                          });
                        },
                        items: <String>['all', 'piece', 'pack']
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value == 'all' ? 'หมวดหมู่' : value == 'piece' ? 'ชิ้น' : 'แพ็ค',
                              style: const TextStyle(fontSize: 14),
                            ),
                          );
                        }).toList(),
                      ),
                      Spacer(),

                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (selectedSortPrice == 'Low to High') {
                              selectedSortPrice = 'High to Low'; // เปลี่ยนเป็น สูงไปต่ำ▼
                            } else {
                              selectedSortPrice = 'Low to High'; // เปลี่ยนเป็น ต่ำไปสูง▲
                            }
                            sortPriceDatas(); // เรียกใช้ฟังก์ชัน sortPriceDatas()
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            selectedSortPrice == 'Low to High'
                                ? 'ต่ำไปสูง▲'
                                : selectedSortPrice == 'High to Low'
                                ? 'สูงไปต่ำ▼'
                                : 'ราคา▲▼',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),

                      Spacer(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isLoading)
            const CircularProgressIndicator()
          else if (datas.isEmpty)
            const Expanded(
              child: Center(child: Text('No results found.')),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: filterDatas().length,
                itemBuilder: (context, index) {
                  final data = filterDatas()[index];
                  bool isOutOfStock = data.isOutOfStock == "สินค้าจะมีเร็วๆนี้";

                  return Card(
                    elevation: 3,
                    color: isOutOfStock ? Colors.grey[300] : null,
                    child: Stack(
                      children: [
                        // Product details
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ListTile(
                            leading: data.urlImage.isNotEmpty
                                ? Image.network(
                              data.urlImage,
                              height: 60,
                              width: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.broken_image);
                              },
                            )
                                : const Icon(Icons.broken_image),
                            title: Text(
                                data.title.isNotEmpty
                                    ? data.title
                                    : 'ชื่อสินค้าไม่พร้อมใช้งาน'
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data.price.isNotEmpty && data.price != 'Not Available'
                                      ? 'ราคา: ${data.price}'
                                      : 'ราคาไม่พร้อมใช้งาน',
                                  style: TextStyle(
                                    color: data.price.isNotEmpty && data.price != 'Not Available'
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  data.category.isNotEmpty
                                      ? 'แหล่งที่มาสินค้า: ${data.category}'
                                      : 'แหล่งที่มาสินค้าไม่พร้อมใช้งาน',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),

                                // แสดง value และ result ใต้ category
                                Builder(
                                  builder: (context) {
                                    final value = extractValueFromTitle(data.title);
                                    final result = calculateResult(value, data.price);
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Text('Value Product: $value', style: TextStyle(fontWeight: FontWeight.bold)),
                                        Text('ความคุ้มค่า: ${result.toStringAsFixed(2)} กรัม/บาท', style: TextStyle(color: Colors.deepOrangeAccent)),
                                      ],
                                    );
                                  },
                                ),
                                InkWell(
                                  onTap: () => openUrlAndSaveOrder(data),
                                  child: const Text(
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
                                data.isBookmarked ? Icons.favorite : Icons.favorite_border,
                                color: data.isBookmarked ? Color(0xFFDB3022) : null,
                              ),
                              iconSize: 25, // ขนาดของ Icon
                              onPressed: () {
                                if (data.isBookmarked) {
                                  removeFromBookmarks(data);
                                } else {
                                  addToBookmarks(data);
                                }
                              },
                            ),
                          ),
                        ),

                        Positioned(
                          right: 22,
                          bottom: 8,
                          child: TextButton(
                            onPressed: () =>
                              showComparisonModal(data)
                            ,
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.blue,  // เปลี่ยนสีพื้นหลัง
                              padding: EdgeInsets.symmetric(horizontal: 1),  // ขนาดปุ่ม
                            ),
                            child: Text(
                              'เปรียบเทียบ',  // ข้อความที่แสดงในปุ่ม
                              style: TextStyle(
                                color: Colors.white,  // สีข้อความ
                                fontSize: 12,  // ขนาดตัวอักษร
                              ),
                            ),
                          ),
                        ),

                        // ส่วนของรูป out of stock
                        if (isOutOfStock)
                          Positioned.fill(
                            child: Align(
                              alignment: Alignment.center,
                              child: Image.asset(
                                'assets/img/logo_outofstock.png',
                                height: 400,
                                width: 300,
                                fit: BoxFit.fill,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            )
        ],
      ),
    );
  }
}

class Data {
  final String url;
  final String title;
  final String urlImage;
  final String price;
  final String category;
  bool isBookmarked;
  final String? isOutOfStock;  // Make this nullable

  Data({
    required this.url,
    required this.title,
    required this.urlImage,
    required this.price,
    required this.category,
    this.isBookmarked = false,
    this.isOutOfStock,  // No default value needed
  });
}
