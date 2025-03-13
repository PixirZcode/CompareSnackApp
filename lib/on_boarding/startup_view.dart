import 'package:flutter/material.dart';
import 'package:project/welcome_view/welcome_view.dart';

class StartupView extends StatefulWidget {
  const StartupView({super.key});

  @override
  State<StartupView> createState() => _StarupViewState();
}

class _StarupViewState extends State<StartupView> {
  @override
  void initState() {
    super.initState();
    goWelcomePage();
  }

  void goWelcomePage() async{

    await Future.delayed(const Duration(seconds: 1) );
    welcomePage();
  }

  void welcomePage(){
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => const WelcomeView()));
  }

  @override
  Widget build(BuildContext context){

    var media = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            "assets/img/splash_bg.png",
            width: media.width,
            height: media.height,
            fit: BoxFit.contain,
          ),
          Image.asset(
            "assets/img/logo_khanom.png",
            width: media.width * 0.55,
            height: media.height * 0.55,
            fit: BoxFit.contain,
          ),

        ],
      ),
    );
  }
}
