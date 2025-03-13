import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:project/main_tabview/main_tabview.dart';

class filterIngredient extends StatefulWidget {
  @override
  _filterIngredientState createState() => _filterIngredientState();
}

class _filterIngredientState extends State<filterIngredient> {

  @override
  void initState() {
    super.initState();
    _loadSavedIngredients(); // โหลดค่าที่บันทึกไว้เมื่อเปิดหน้านี้
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, bool> selectedIngredients = {
    'Corn': false,
    'Cheese': false,
    'Chocolate': false,
    'Strawberry': false,
    'Nori': false,
  };

  Map<String, String> ingredientImages = {
    'Corn': 'assets/img/corn.png',
    'Cheese': 'assets/img/cheese.png',
    'Chocolate': 'assets/img/chocolate.png',
    'Strawberry': 'assets/img/strawberry.png',
    'Nori': 'assets/img/nori_1.png',
  };


// โหลดข้อมูลจาก Firestore
  Future<void> _loadSavedIngredients() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot doc = await _firestore.collection('users').doc(user.email).get();
      if (doc.exists && doc.data() != null) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('ingredients')) {
          Map<String, dynamic> savedIngredients = data['ingredients'];
          setState(() {
            selectedIngredients = savedIngredients.map((key, value) => MapEntry(key, value as bool));
          });
        }
      }
    }
  }

  // บันทึกข้อมูลวัตถุดิบที่เลือกลง Firestore
  Future<void> _saveIngredients() async {
    User? user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.email).set({
        'ingredients': selectedIngredients,
      }, SetOptions(merge: true));

      // พาผู้ใช้ไปที่ MainTabView หลังจากเลือกเสร็จ
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainTabView()),
      );
    }
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
      appBar: AppBar(
        title: Text('เลือกสิ่งที่คุณชื่นชอบ',
          style: TextStyle(fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: selectedIngredients.keys.map((ingredient) {
                  return Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0)),
                    elevation: 4.0,
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12.0),
                            image: DecorationImage(
                              image: AssetImage(ingredientImages[ingredient]!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12.0),
                              color: Colors.black.withOpacity(0.5),
                            ),
                          ),
                        ),
                        Center(
                          child: Text(
                            ingredient,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Checkbox(
                            value: selectedIngredients[ingredient] ?? false, // ใช้ค่าจาก Firestore ถ้าค่าเก่ามัน true จะติ๊กถูกเขียว
                            onChanged: (bool? value) {
                              setState(() {
                                selectedIngredients[ingredient] = value ?? false;
                              });
                            },
                            activeColor: Colors.green,
                          )
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: 16),

            Container(
              width: double.infinity, // Make it take full width like the input box
              height: 50, // ความกว้างปุ่ม
              child: ElevatedButton(
                onPressed: () async {
                  await _saveIngredients(); // บันทึกข้อมูล
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => MainTabView()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade800,
                  shadowColor: Colors.transparent, // ขอบใส
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'ยืนยัน',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
     ),
    );
  }
}
