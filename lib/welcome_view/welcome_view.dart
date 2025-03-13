import 'package:flutter/material.dart';
import 'package:project/common_widget/round_button.dart';
import 'package:project/login/signup.dart';
import 'package:project/login/wrapper.dart';

class WelcomeView extends StatefulWidget {
  const WelcomeView({super.key});

  @override
  State<WelcomeView> createState() => _WelcomeViewState();
}

class _WelcomeViewState extends State<WelcomeView> {

  @override
  Widget build(BuildContext context) {
    var media = MediaQuery.of(context).size;

    return Scaffold(
      body: Column(
        children: [
          Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Image.asset("assets/img/welcome_top_shape.png",
                width: media.width,
              ),

              Image.asset(
                "assets/img/logo_khanom.png",
                width: media.width * 0.80,
                height: media.height * 0.27,
                fit: BoxFit.contain,
              ),
            ],
          ),

          SizedBox(height: media.width * 0.10,),

          /*
          Text(
          "commentttttttttttttttttttttttttttttttttttttttt",
          textAlign: TextAlign.center,
          style: TextStyle(
              color: TColor.secondaryText, fontSize: 13, fontWeight: FontWeight.w500),
        ),
          SizedBox(height: media.width * 0.1,),
        */

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: RoundButton(title: "เข้าสู่ระบบ", onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const Wrapper()
              ),
              );
            },
            ),
          ),

          SizedBox(height: 20),

          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: RoundButton(
                  title: "สมัครสมาชิก",
                  type: RoundButtonType.textPrimary,
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const Signup()),
                    );
                  }
              )
          ),

          SizedBox(height: media.width * 0.1,),

        ],
      ),
    );
  }
}
