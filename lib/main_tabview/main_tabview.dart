import 'package:flutter/material.dart';
import 'package:project/common/color_extension.dart';
import 'package:project/common_widget/tab_button.dart';
import 'package:project/main_tabview/MainPage.dart';
import 'package:project/main_tabview/bookmark_tab.dart';
import 'package:project/main_tabview/history_tab.dart';
import 'package:project/main_tabview/profile_tab.dart';
import 'package:project/main_tabview/promotion_tab.dart';


class MainTabView extends StatefulWidget {
  const MainTabView({super.key});

  @override
  State<MainTabView> createState() => _MainTabViewState();
}

class _MainTabViewState extends State<MainTabView> {

  int selectTab = 2;
  PageStorageBucket storageBucket = PageStorageBucket();
  Widget selectPageView = Homepage(); // Home หน้าสินค้า (รอทำหน้าโปรโมชั่น)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageStorage(bucket: storageBucket, child: selectPageView,),
      backgroundColor: const Color(0xfff5f5f5),
      floatingActionButtonLocation: FloatingActionButtonLocation.miniCenterDocked,
      floatingActionButton: SizedBox(
        width: 60,
        height: 60,
        child: FloatingActionButton(
          onPressed: (){
            if (selectTab != 2) {
              selectTab = 2;
              selectPageView = Homepage(); // Home หน้าสินค้า
            }
            if (mounted) {
              setState(() {
              });
            }

          },
          shape: const CircleBorder(),
          backgroundColor: selectTab ==2 ? TColor.primary : TColor.placeholder,
          child: Image.asset(
            "assets/img/tab_home.png",
            width: 35,
            height: 35,
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        surfaceTintColor: TColor.white,
        shadowColor: Colors.black,
        elevation: 1,
        notchMargin: 12,
        height: 64,
        shape: const CircularNotchedRectangle(),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              TabButton(title: "บุ๊กมาร์ก",
                  icon: "assets/img/tab_fav.png", onTap: (){
                    if (selectTab != 0) {
                      selectTab = 0;
                      selectPageView = BookmarksPage(); // หน้า bookmark
                    }
                    if (mounted) {
                      setState(() {

                      });
                    }
                  }, isSelected: selectTab == 0),

              TabButton(title: "ประวัติการเข้าชม",
                  icon: "assets/img/tab_offer.png", onTap: (){
                    if (selectTab != 1) {
                      selectTab = 1;
                      selectPageView = HistoryPage();
                    }
                    if (mounted) {
                      setState(() {

                      });
                    }
                  }, isSelected: selectTab == 1),

              const SizedBox(width: 40, height: 40,),

              TabButton(title: "โปรไฟล์",
                  icon: "assets/img/tab_profile.png", onTap: (){
                    if (selectTab != 3) {
                      selectTab = 3;
                      selectPageView = const ProfileTab(); // หน้าโปรไฟล์
                    }
                    if (mounted) {
                      setState(() {

                      });
                    }
                  }, isSelected: selectTab == 3),

              TabButton(title: "โปรโมชั่น",
                  icon: "assets/img/promo_tab.png", onTap: (){
                    if (selectTab != 4) {
                      selectTab = 4;
                      selectPageView = promotion();
                    }
                    if (mounted) {
                      setState(() {

                      });
                    }
                  }, isSelected: selectTab == 4),
            ],
          ),
        ),
      ),
    );
  }
}
