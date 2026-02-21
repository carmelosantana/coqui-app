import 'package:flutter/material.dart';
import 'package:coqui_app/Constants/constants.dart';
import 'package:coqui_app/Widgets/flexible_text.dart';

class BottomSheetHeader extends StatelessWidget {
  final String title;

  const BottomSheetHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ClipOval(
            child: Image.asset(
              AppConstants.appIconPng,
              height: 48,
              width: 48,
              fit: BoxFit.cover,
            ),
          ),
        ),
        FlexibleText(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
