import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'showModalSheet.dart';
import 'package:project/main_tabview/main_tabview.dart';
import 'package:project/ocr/google_ocr.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:redis/redis.dart';
import 'package:string_similarity/string_similarity.dart';

class Search_Product extends StatefulWidget {
  const Search_Product({super.key});

  @override
  State<Search_Product> createState() => _Search_ProductState();
}

class _Search_ProductState extends State<Search_Product> {

  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> products = []; // สร้างลิสต์สำหรับเก็บข้อมูลสินค้า
  List<Map<String, dynamic>> filteredProducts = []; // รายการสินค้าที่กรองแล้ว
  Set<String> bookmarkedProductIds = {}; // Set สำหรับเก็บ ID ของสินค้าที่ถูกบุ๊กมาร์ก
  String resultMessage = ''; // ข้อความสำหรับแสดงผลลัพธ์ค้นหา
  String selectedShop = 'ร้านค้า'; // ตัวแปรเก็บค่าที่เลือกจาก Dropdown
  String selectedCategory = 'หมวดหมู่'; // ตัวแปรเก็บค่าที่เลือกจาก Dropdown สำหรับหมวดหมู่สินค้า
  String selectedValue = 'ความคุ้มค่า'; // ตัวแปรเก็บค่าที่เลือกจาก Dropdown สำหรับความคุ้มค่า
  String selectedPrice = 'ราคา'; // ค่าตัวแปรเลือกค่าเริ่มต้นเป็น "ราคา"
  bool isExpanded = false; // ตัวแปรสำหรับควบคุมการแสดงผลของคำค้นหาที่ซ่อนอยู่
  bool isLoading = false;
  RedisConnection redisConnection = RedisConnection();
  Command? redisClient;

  // แสดงสินค้าเมื่อเปิดแอปด้วยคีย์เวิร์ด Products จากสินค้าทั้ง 2 แหล่ง
  @override
  void initState() {
    super.initState();
    initRedis().then((_) {
      fetchBookmarks().then((_) {
      });
    });
  }

  Future<void> initRedis() async {
    try {
      // เชื่อมต่อกับ Redis server (เช่นที่ localhost:6379)
      redisClient = await redisConnection.connect('10.0.0.85', 6379);
      print("✔ เชื่อมต่อกับ Redis สำเร็จ");
    } catch (e) {
      print("❌ ERROR: ไม่สามารถเชื่อมต่อ Redis: $e");
    }
  }

  Future<void> fetchProducts(String query) async {
    if (redisClient == null) {
      print("❌ ERROR: redisClient ยังไม่ถูกเชื่อมต่อ");
      return;
    }

    String userEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    if (userEmail.isEmpty) return;

    try {
      // เช็คข้อมูลจาก Redis ก่อน
      final redisBigc = await redisClient!.get('product:bigc');
      final redisLotus = await redisClient!.get('product:lotus');

      List<Map<String, dynamic>> fetchedProducts = [];
      int bigcCount = 0;
      int lotusCount = 0;

      // ฟังก์ชันตรวจสอบว่าชื่อสินค้าคล้ายกับ query หรือไม่
      bool isQueryMatch(Map<String, dynamic> product, String query) {
        String title = product['title']?.toLowerCase() ?? '';
        double similarity = StringSimilarity.compareTwoStrings(title, query.toLowerCase());
        return title.contains(query.toLowerCase()) || similarity > 0.3; // ตั้ง threshold ที่ 0.3
      }

      Future<void> searchInList(List<dynamic> productList, String shopName) async {
        for (var product in productList) {
          if (product is Map<String, dynamic>) {
            if ((shopName == "BigC" && bigcCount < 30) || (shopName == "Lotus" && lotusCount < 30)) {
              if (isQueryMatch(product, query)) {
                fetchedProducts.add({...product, 'shop': shopName});
                if (shopName == "BigC") {
                  bigcCount++;
                } else {
                  lotusCount++;
                }
              }
            }
          }
        }
      }

      if (redisBigc != null || redisLotus != null) {
        print("✔ ข้อมูลจาก Redis");

        if (redisBigc != null) {
          await searchInList(jsonDecode(redisBigc) as List<dynamic>, "BigC");
        }
        if (redisLotus != null) {
          await searchInList(jsonDecode(redisLotus) as List<dynamic>, "Lotus");
        }
      }

      // ถ้าใน Redis ไม่เจอ ให้ไปดึงจาก Firestore
      if (fetchedProducts.isEmpty) {
        print("❌ ไม่มีข้อมูลใน Redis, ค้นหาใน Firestore");

        final querySnapshot = await FirebaseFirestore.instance.collection('listproduct').get();
        print("✔ ดึงข้อมูลจาก Firestore สำเร็จ, จำนวนสินค้า: ${querySnapshot.docs.length}");

        if (querySnapshot.docs.isNotEmpty) {
          for (var doc in querySnapshot.docs) {
            final data = doc.data();
            if (data.containsKey('bigc')) {
              await searchInList(data['bigc'] as List<dynamic>, "BigC");
            }
            if (data.containsKey('lotus')) {
              await searchInList(data['lotus'] as List<dynamic>, "Lotus");
            }

            if (bigcCount >= 30 && lotusCount >= 30) break;
          }

          // บันทึกข้อมูลลง Redis เพื่อลดโหลดในอนาคต
          await redisClient!.set('product:bigc', jsonEncode(fetchedProducts.where((p) => p['shop'] == 'BigC').toList()));
          await redisClient!.set('product:lotus', jsonEncode(fetchedProducts.where((p) => p['shop'] == 'Lotus').toList()));
        }
      }

      // ตั้งค่าสถานะว่าถูกบุ๊กมาร์กหรือไม่
      for (var product in fetchedProducts) {
        product['isBookmarked'] = bookmarkedProductIds.contains(product['url']);
      }

      setState(() {
        products = fetchedProducts;
        filteredProducts = fetchedProducts;
      });

      if (fetchedProducts.isEmpty) {
        resultMessage = "ไม่พบสินค้าที่เกี่ยวข้องกับ '$query'";
      } else {
        resultMessage = "พบสินค้า ${fetchedProducts.length} รายการสำหรับ '$query'";
      }

      print("✔ สินค้าที่ดึงมา: $fetchedProducts");
    } catch (e) {
      print("❌ ERROR: $e");
    }
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

  // ฟังก์ชันกรองสินค้า
  void filterAndSortProducts(String shop, String category, String value, String price) {
    print("🔍 Filtering with: shop=$shop, category=$category, value=$value, price=$price");

    List<Map<String, dynamic>> tempProducts = products.where((product) {
      bool matchesShop = (shop == 'ร้านค้า') || (product['shop'] == shop);
      bool matchesCategory = (category == 'หมวดหมู่') ||
          (category == 'ชิ้น' && product['unit'] != 'แพ็ค') ||
          (category == 'แพ็ค' && product['unit'] == 'แพ็ค');

      return matchesShop && matchesCategory;
    }).toList();

    // เรียงสินค้าตาม value ถ้าเลือก
    if (value == 'น้อยไปมาก') {
      tempProducts.sort((a, b) =>
          (double.tryParse(a['value'].toString()) ?? 0.0)
              .compareTo(double.tryParse(b['value'].toString()) ?? 0.0));
    } else if (value == 'มากไปน้อย') {
      tempProducts.sort((a, b) =>
          (double.tryParse(b['value'].toString()) ?? 0.0)
              .compareTo(double.tryParse(a['value'].toString()) ?? 0.0));
    }

    // เรียงสินค้าตามราคา ถ้าเลือก
    if (price == 'น้อยไปมาก') {
      tempProducts.sort((a, b) => a['price'].compareTo(b['price']));
    } else if (price == 'มากไปน้อย') {
      tempProducts.sort((a, b) => b['price'].compareTo(a['price']));
    }

    setState(() {
      filteredProducts = tempProducts;
    });
  }

  // ฟังก์ชันในการดึงข้อมูลบุ๊กมาร์ก
  Future<void> fetchBookmarks() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final bookmarksRef = FirebaseFirestore.instance.collection('users').doc(user.email).collection('bookmarks');
    final snapshot = await bookmarksRef.get();

    setState(() {
      bookmarkedProductIds = snapshot.docs.map((doc) => doc['url'] as String).toSet();
    });
  }

  // เพิ่มข้อมูลสินค้าลงในบุ๊กมาร์ก
  Future<void> addToBookmarks(Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid.isEmpty) {
      print('ผู้ใช้ไม่ได้เข้าสู่ระบบ');
      return;
    }

    final _firestore = FirebaseFirestore.instance;
    final bookmarksRef = _firestore.collection('users').doc(user.email).collection('bookmarks');

    try {
      await bookmarksRef.add({
        'title': data['title'],
        'url': data['url'],
        'image': data['image'],
        'price': data['price'],
        'unit': data['unit'],
        'stockStatus': data['stockStatus'],
        'value': data['value'],
        'shop': data['shop'],
      });

      setState(() {
        data['isBookmarked'] = true;
        bookmarkedProductIds.add(data['url']);
      });

      print('เพิ่มบุ๊กมาร์กเรียบร้อยแล้ว');
    } catch (e) {
      print('เกิดข้อผิดพลาดในการเพิ่มบุ๊กมาร์ก: $e');
    }
  }

  // ลบสินค้าจากบุ๊กมาร์ก
  Future<void> removeFromBookmarks(Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid.isEmpty) {
      print('ผู้ใช้ไม่ได้เข้าสู่ระบบ');
      return;
    }

    final _firestore = FirebaseFirestore.instance;
    final bookmarksRef = _firestore.collection('users').doc(user.email).collection('bookmarks');

    try {
      final querySnapshot = await bookmarksRef.where('url', isEqualTo: data['url']).get();
      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
      }

      setState(() {
        data['isBookmarked'] = false;
        bookmarkedProductIds.remove(data['url']);
      });

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
        'image': data['image'], // ใช้แบบนี้เพราะค่าใน Redis เก็บเป็น image แต่ history ใน firestore เป็น urlImage เลยต้องเลือกอันใดอันนึง
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
                                  fetchProducts(query);
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
                                fetchProducts(query);
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
                      // Dropdown สำหรับเลือกหมวดหมู่สินค้า
                      Spacer(),
                      DropdownButton<String>(
                        value: selectedShop,
                        items: [
                          DropdownMenuItem(value: 'ร้านค้า', child: Text('ร้านค้า')),
                          DropdownMenuItem(value: 'BigC', child: Text('BigC')),
                          DropdownMenuItem(value: 'Lotus', child: Text('Lotus')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedShop = value ?? 'ร้านค้า';
                          });
                          filterAndSortProducts(selectedShop, selectedCategory, selectedValue, selectedPrice); // เรียกฟังก์ชันกรองและจัดเรียง
                        },
                      ),
                      Spacer(),
                      // Dropdown สำหรับเลือกหมวดหมู่ (ชิ้น หรือ แพ็ค)
                      DropdownButton<String>(
                        value: selectedCategory,
                        items: [
                          DropdownMenuItem(value: 'หมวดหมู่', child: Text('หมวดหมู่')),
                          DropdownMenuItem(value: 'ชิ้น', child: Text('ชิ้น')),
                          DropdownMenuItem(value: 'แพ็ค', child: Text('แพ็ค')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedCategory = value ?? 'หมวดหมู่';
                          });
                          filterAndSortProducts(selectedShop, selectedCategory, selectedValue, selectedPrice); // เรียกฟังก์ชันกรองและจัดเรียง
                        },
                      ),
                      Spacer(),
                      // Dropdown สำหรับเลือกความคุ้มค่า
                      DropdownButton<String>(
                        value: selectedValue,
                        items: [
                          DropdownMenuItem(value: 'ความคุ้มค่า', child: Text('ความคุ้มค่า')),
                          DropdownMenuItem(value: 'น้อยไปมาก', child: Text('ต่ำไปสูง▲')),
                          DropdownMenuItem(value: 'มากไปน้อย', child: Text('สูงไปต่ำ▼')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedValue = value ?? 'ความคุ้มค่า';
                          });
                          filterAndSortProducts(selectedShop, selectedCategory, selectedValue, selectedPrice); // เรียกฟังก์ชันกรองและจัดเรียง
                        },
                      ),
                      Spacer(),
                      DropdownButton<String>(
                        value: selectedPrice,
                        items: [
                          DropdownMenuItem(value: 'ราคา', child: Text('ราคา')),
                          DropdownMenuItem(value: 'น้อยไปมาก', child: Text('ต่ำไปสูง▲')),
                          DropdownMenuItem(value: 'มากไปน้อย', child: Text('สูงไปต่ำ▼')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedPrice = value ?? 'ความคุ้มค่า';
                          });
                          filterAndSortProducts(selectedShop, selectedCategory, selectedValue, selectedPrice); // เรียกฟังก์ชันกรองและจัดเรียง
                        },
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
          else if (products.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'เริ่มต้นค้นหาสินค้า\nที่คุณอยากค้นหาได้เลย !!',
                  style: TextStyle(
                    fontSize: 22, // ปรับขนาดฟอนต์ที่ต้องการ
                    fontWeight: FontWeight.bold, // เพิ่มความหนาของฟอนต์ (ถ้าต้องการ)
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: filteredProducts.length,
                itemBuilder: (context, index) {
                  final data = filteredProducts[index];
                  print("🔍 Debug data: $data"); // ✅ เพิ่มบรรทัดนี้
                  bool isOutOfStock = data['stockStatus'] != 'Y' && data['stockStatus'] != 'IN_STOCK';

                  return Card(
                    elevation: 3,
                    color: isOutOfStock ? Colors.grey[300] : null,
                    child: Stack(
                      children: [
                        // Product details
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ListTile(
                            leading: data['image'] != null
                                ? Image.network(
                              data['image'],
                              height: 60,
                              width: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.broken_image);
                              },
                            )
                                : const Icon(Icons.broken_image),
                            title: Text(
                              data['title'],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "ราคา: ${data['price']} บาท",
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "แหล่งที่มา: ${data['shop']}",
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic,
                                    fontSize: 12,
                                  ),
                                ),

                                // แสดง value และ result ใต้ category
                                Builder(
                                  builder: (context) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'ความคุ้มค่า: ${data['value']} กรัม/บาท',
                                          style: TextStyle(
                                            color: Colors.deepOrangeAccent,
                                            fontSize: 12,
                                          ),
                                        ),
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
                                data['isBookmarked']
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                              ),
                              color: data['isBookmarked'] ? Colors.pink : Colors.black,
                              iconSize: 25, // ขนาดของ Icon
                              onPressed: () {
                                // เพิ่มหรือลบบุ๊กมาร์กเมื่อกดปุ่ม
                                if (data['isBookmarked']) {
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
                              showComparisonSheet(context, data['title']),
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
