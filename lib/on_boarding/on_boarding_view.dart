import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project/main_tabview/filterIngredient.dart';
import '../../common/color_extension.dart';
import '../../common_widget/round_button.dart';

class OnBoardingView extends StatefulWidget {
  const OnBoardingView({super.key});

  @override
  State<OnBoardingView> createState() => _OnBoardingViewState();
}

class _OnBoardingViewState extends State<OnBoardingView> {
  int selectPage = 0;
  PageController controller = PageController();

  List pageArr = [
    {
      "title": "ค้นหาอาหารที่คุณรัก",
      "subtitle":
      "ค้นพบร้านค้าที่ดีที่สุดจากแหล่งผลิตภัณฑ์ที่หลากหลาย",
      "image": "assets/img/on_boarding_1.png",
    },
    {
      "title": "ประหยัดเวลา",
      "subtitle": "ประหยัดเวลาในการค้นหาผลิตภัณฑ์จากแหล่งต่างๆ",
      "image": "assets/img/on_boarding_2.png",
    },
    {
      "title": "เปรียบเทียบราคาสินค้า",
      "subtitle":
      "เปรียบเทียบราคาจากหลายๆแห่งเพื่อค้นหา \nราคาที่ถูกที่สุดและคุ้มค่าที่สุด",
      "image": "assets/img/on_boarding_3.png",
    },
  ];

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    controller.addListener(() {
      setState(() {
        selectPage = controller.page?.round() ?? 0;
      });
    });
  }

  // ฟังก์ชันเพื่ออัปเดตสถานะการดู Onboarding ใน Firestore
  Future<void> _markOnboardingComplete() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.email!.toLowerCase()).set(
        {'onboardingComplete': true},
        SetOptions(merge: true),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    var media = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          PageView.builder(
            controller: controller,
            itemCount: pageArr.length,
            itemBuilder: ((context, index) {
              var pObj = pageArr[index] as Map? ?? {};
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: media.width,
                    height: media.width,
                    alignment: Alignment.center,
                    child: Image.asset(
                      pObj["image"].toString(),
                      width: media.width * 0.60,
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(
                    height: media.width * 0.15,
                  ),
                  Text(
                    pObj["title"].toString(),
                    style: TextStyle(
                        color: TColor.primaryText,
                        fontSize: 28,
                        fontWeight: FontWeight.w800),
                  ),
                  SizedBox(
                    height: media.width * 0.05,
                  ),
                  Text(
                    pObj["subtitle"].toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: TColor.secondaryText,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                  SizedBox(
                    height: media.width * 0.20,
                  ),
                ],
              );
            }),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: media.height * 0.6,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: pageArr.map((e) {
                  var index = pageArr.indexOf(e);

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 6,
                    width: 6,
                    decoration: BoxDecoration(
                        color: index == selectPage
                            ? TColor.primary
                            : TColor.placeholder,
                        borderRadius: BorderRadius.circular(4)),
                  );
                }).toList(),
              ),
              SizedBox(
                height: media.height * 0.28,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: RoundButton(
                    title: "ถัดไป",
                    onPressed: () async {
                      if(selectPage >= 2){
                        await _markOnboardingComplete(); // อัปเดต Firestore
                        Navigator.push(
                          context, MaterialPageRoute(
                            builder: (context) => filterIngredient()
                        ),
                        );
                      } else {
                        setState(() {
                          selectPage = selectPage + 1;
                          controller.animateToPage(selectPage,
                              duration: const Duration(milliseconds: 150),
                              curve: Curves.bounceInOut);
                        });
                      }
                    }),
              ),
            ],
          )
        ],
      ),
    );
  }
}
