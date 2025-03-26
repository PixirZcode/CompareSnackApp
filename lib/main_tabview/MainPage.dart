import 'dart:convert';
import 'package:redis/redis.dart';
import 'package:flutter/material.dart';
import 'package:project/main_tabview/Search_Product.dart';
import 'package:project/main_tabview/ImageSlider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:project/ocr/google_ocr.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:string_similarity/string_similarity.dart';
import 'showModalSheet.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  int currentSlide = 0;
  List<Map<String, dynamic>> products = []; // สร้างลิสต์สำหรับเก็บข้อมูลสินค้า
  Set<String> bookmarkedProductIds = {}; // Set สำหรับเก็บ ID ของสินค้าที่ถูกบุ๊กมาร์ก
  List<Map<String, dynamic>> filteredProducts = []; // รายการสินค้าที่กรองแล้ว
  String selectedShop = 'ร้านค้า'; // ตัวแปรเก็บค่าที่เลือกจาก Dropdown
  String selectedCategory = 'หมวดหมู่'; // ตัวแปรเก็บค่าที่เลือกจาก Dropdown สำหรับหมวดหมู่สินค้า
  String selectedValue = 'ความคุ้มค่า'; // ตัวแปรเก็บค่าที่เลือกจาก Dropdown สำหรับความคุ้มค่า
  String selectedPrice = 'ราคา'; // ค่าตัวแปรเลือกค่าเริ่มต้นเป็น "ราคา"
  RedisConnection redisConnection = RedisConnection();
  Command? redisClient;

  // แสดงสินค้าเมื่อเปิดแอปด้วยคีย์เวิร์ด Products จากสินค้าทั้ง 2 แหล่ง
  @override
  void initState() {
    super.initState();
    initRedis().then((_) {
      fetchBookmarks().then((_) {
        fetchProducts(); // โหลดสินค้า หลังจากรู้ข้อมูลบุ๊กมาร์กแล้ว
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

  // แสดงข้อมูลสินค้า
  Future<void> fetchProducts() async {
    if (redisClient == null) {
      print("❌ ERROR: redisClient ยังไม่ถูกเชื่อมต่อ");
      return; // ออกจากฟังก์ชันถ้า redisClient ยังไม่ได้เชื่อมต่อ
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

      // ฟังก์ชันค้นหาความคล้ายคลึงระหว่าง ingredients และ title ของสินค้า
      bool isIngredientMatch(Map<String, dynamic> product, Set<String> ingredients) {
        for (var ingredient in ingredients) {
          // ใช้ StringSimilarity เพื่อหาความคล้ายคลึง
          double similarity = StringSimilarity.compareTwoStrings(product['title'] ?? '', ingredient);
          if (similarity > 0.3) { // ตั้งไว้ประมาณ 0.2-0.4 กำลังดี
            return true; // หากพบคำที่คล้ายกัน
          }
        }
        return false; // หากไม่มีคำที่ตรงกันให้คืนค่า false
      }

      // ดึงข้อมูล ingredients ของผู้ใช้
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userEmail).get();
      final ingredientsData = userDoc.data()?['ingredients'] ?? {};

      // แปลงเป็น Set<String> จาก Map<String, bool> (เก็บเฉพาะคีย์ที่มีค่าเป็น true)
      Set<String> ingredients = Set<String>.from(ingredientsData.entries
          .where((entry) => entry.value == true) // เลือกเฉพาะที่มีค่าเป็น true
          .map((entry) => entry.key) // แปลงคีย์เป็น String
      );

      if (redisBigc != null && redisLotus != null) {
        // ถ้ามีข้อมูลใน Redis
        print("✔ ข้อมูลจาก Redis: BigC และ Lotus");

        final bigcData = jsonDecode(redisBigc) as List<dynamic>;
        final lotusData = jsonDecode(redisLotus) as List<dynamic>;

        // ตรวจสอบให้แน่ใจว่า bigcData และ lotusData เป็น List
        if (bigcData is List && lotusData is List) {
          // ดึงข้อมูลจาก BigC
          for (var product in bigcData) {
            if (product is Map<String, dynamic> && bigcCount < 30) {
              // หากมี ingredient ที่ตรง
              if (isIngredientMatch(product, ingredients)) {
                fetchedProducts.add({
                  'title': product['title'] ?? 'ไม่มีชื่อ',
                  'url': product['url'] ?? '',
                  'image': product['image'] ?? '',
                  'price': product['price'] ?? 0,
                  'unit': product['unit'] ?? '',
                  'stockStatus': product['stockStatus'] ?? '',
                  'value': product['value'] ?? 0,
                  'shop': 'BigC',
                });
                bigcCount++;
              }
            }
          }

          // ดึงข้อมูลจาก Lotus
          for (var product in lotusData) {
            if (product is Map<String, dynamic> && lotusCount < 30) {
              // หากมี ingredient ที่ตรง
              if (isIngredientMatch(product, ingredients)) {
                fetchedProducts.add({
                  'title': product['title'] ?? 'ไม่มีชื่อ',
                  'url': product['url'] ?? '',
                  'image': product['image'] ?? '',
                  'price': product['price'] ?? 0,
                  'unit': product['unit'] ?? '',
                  'stockStatus': product['stockStatus'] ?? '',
                  'value': product['value'] ?? 0,
                  'shop': 'Lotus',
                });
                lotusCount++;
              }
            }
          }
        } else {
          print("❌ ข้อมูลจาก Redis ไม่ใช่ List");
        }

      } else {
        // ถ้าไม่มีข้อมูลใน Redis, ดึงข้อมูลจาก Firestore
        print("❌ ไม่มีข้อมูลใน Redis, ดึงข้อมูลจาก Firestore");

        final querySnapshot = await FirebaseFirestore.instance.collection('listproduct').get();
        print("✔ ดึงข้อมูลจาก Firestore สำเร็จ, จำนวนสินค้า: ${querySnapshot.docs.length}");

        if (querySnapshot.docs.isNotEmpty) {
          for (var doc in querySnapshot.docs) {
            final data = doc.data();
            print("✔ ข้อมูลที่ได้จาก Firestore: $data");

            if (data.containsKey('bigc') && data['bigc'] is List<dynamic>) {
              for (var product in data['bigc']) {
                if (product is Map<String, dynamic> && bigcCount < 30) {
                  // หากมี ingredient ที่ตรง
                  if (isIngredientMatch(product, ingredients)) {
                    fetchedProducts.add({
                      'title': product['title'] ?? 'ไม่มีชื่อ',
                      'url': product['url'] ?? '',
                      'image': product['image'] ?? '',
                      'price': product['price'] ?? 0,
                      'unit': product['unit'] ?? '',
                      'stockStatus': product['stockStatus'] ?? '',
                      'value': product['value'] ?? 0,
                      'shop': product['shop'] ?? 'BigC',
                    });
                    bigcCount++;
                  }
                }
              }
            }

            if (data.containsKey('lotus') && data['lotus'] is List<dynamic>) {
              for (var product in data['lotus']) {
                if (product is Map<String, dynamic> && lotusCount < 30) {
                  // หากมี ingredient ที่ตรง
                  if (isIngredientMatch(product, ingredients)) {
                    fetchedProducts.add({
                      'title': product['title'] ?? 'ไม่มีชื่อ',
                      'url': product['url'] ?? '',
                      'image': product['image'] ?? '',
                      'price': product['price'] ?? 0,
                      'unit': product['unit'] ?? '',
                      'stockStatus': product['stockStatus'] ?? '',
                      'value': product['value'] ?? 0,
                      'shop': product['shop'] ?? 'Lotus',
                    });
                    lotusCount++;
                  }
                }
              }
            }

            // หยุดเมื่อดึงครบ 30 รายการจากทั้งสองแหล่ง
            if (bigcCount >= 30 && lotusCount >= 30) break;
          }

          // เก็บข้อมูลใน Redis สำหรับการใช้งานครั้งถัดไป
          await redisClient!.set('product:bigc', jsonEncode(fetchedProducts.where((p) => p['shop'] == 'BigC').toList()));
          await redisClient!.set('product:lotus', jsonEncode(fetchedProducts.where((p) => p['shop'] == 'Lotus').toList()));

          print("✔ สินค้าที่ดึงมา: $fetchedProducts");

        } else {
          print("❌ ไม่มีสินค้าใน Firestore");
        }
      }

      // ตั้งค่าสถานะว่าเป็นสินค้าที่ถูกบุ๊กมาร์กหรือไม่
      for (var product in fetchedProducts) {
        product['isBookmarked'] = bookmarkedProductIds.contains(product['url']);
      }

      setState(() {
        products = fetchedProducts;
        filteredProducts = fetchedProducts; // กรองเป็นทั้งหมดในตอนแรก
      });

    } catch (e) {
      print("❌ ERROR: $e");
    }
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
      body: SingleChildScrollView(
        child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(left: 15, right: 15, top: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () {
                          // เมื่อกดที่ Container จะพาไปหน้า Scrapping()
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => Search_Product()),
                          );
                        },
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
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Icon(
                                  Icons.search,
                                  color: Color(0xFFDB3022),
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                "ค้นหาสินค้า", // ข้อความในช่องค้นหา
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
                              MaterialPageRoute(builder: (context) => TextDetectionScreen()), // เปลี่ยน NewPage() เป็นหน้าใหม่ของคุณ
                            );
                          },
                          child: Center(
                            child: Icon(Icons.camera_alt_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Container(
                    height: 150,
                    width: MediaQuery.of(context).size.width,
                    decoration: BoxDecoration(
                      color: Color(0xFFFFF0DD),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Imageslider(
                        currentSlide: currentSlide,
                        OnChange: (value) {
                          setState(() {
                            currentSlide = value;
                          });
                        }),
                  ),
                  SizedBox(height: 20),
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
                  SizedBox(height: 20),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "รายการสินค้า",
                      style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(height: 20),

                  // แสดงสินค้าใน GridView.builder
                  GridView.builder(
                    itemCount: filteredProducts.length,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.6,
                      crossAxisSpacing: 2,
                    ),
                    itemBuilder: (context, index) {
                      final data = filteredProducts[index];
                      bool isOutOfStock = data['stockStatus'] != 'Y' && data['stockStatus'] != 'IN_STOCK';
                      print("🔍 Debug data: $data"); // ✅ เพิ่มบรรทัดนี้

                      return Container(
                        color: isOutOfStock ? Colors.grey[300] : null,
                        margin: EdgeInsets.only(right: 15),
                        child: Stack( // ครอบ Column ด้วย Stack เพื่อให้ใช้ Positioned ได้
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: 150,
                                  child: Stack(
                                    children: [
                                      Image.network(
                                        data['image'],
                                        height: 150,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                      Positioned(
                                        right: 10,
                                        top: 10,
                                        child: IconButton(
                                          onPressed: () {
                                            // เพิ่มหรือลบบุ๊กมาร์กเมื่อกดปุ่ม
                                            if (data['isBookmarked']) {
                                              removeFromBookmarks(data);
                                            } else {
                                              addToBookmarks(data);
                                            }
                                          },
                                          icon: Icon(
                                            data['isBookmarked']
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                          ),
                                          color: data['isBookmarked'] ? Colors.pink : Colors.black,
                                          iconSize: 30,
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                                Text(
                                  data['title'],
                                  style: TextStyle(fontSize: 14),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                    ),
                                    Text(
                                      "ราคา: ${data['price']} บาท",
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  "แหล่งที่มา: ${data['shop']}",
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic,
                                    fontSize: 12,
                                  ),
                                ),
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
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    InkWell(
                                      onTap: () => openUrlAndSaveOrder(data),
                                      child: const Text(
                                        'ดูสินค้าต้นทาง',
                                        style: TextStyle(
                                          color: Colors.blue,
                                          decoration: TextDecoration.underline,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => showComparisonSheet(context, data['title']),
                                      style: TextButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        minimumSize: Size(80, 30),
                                      ),
                                      child: Text(
                                        'เปรียบเทียบ',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            // ส่วนของรูป out of stock (อยู่ใน Stack แล้ว)
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
                ],
              ),
            )),
      ),
    );
  }
}