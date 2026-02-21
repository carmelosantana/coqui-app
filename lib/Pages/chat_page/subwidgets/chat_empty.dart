import 'package:flutter/material.dart';
import 'package:coqui_app/Constants/constants.dart';

class ChatEmpty extends StatelessWidget {
  final Widget child;

  const ChatEmpty({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipOval(
              child: Image.asset(
                AppConstants.appIconPng,
                height: 48,
                width: 48,
                fit: BoxFit.cover,
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}
