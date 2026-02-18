import 'package:flutter/material.dart';

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
            Image.asset(
              'assets/images/coqui.png',
              height: 48,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            child,
          ],
        ),
      ),
    );
  }
}
