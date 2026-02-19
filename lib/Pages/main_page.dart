import 'package:flutter/material.dart';
import 'package:coqui_app/Pages/chat_page/chat_page.dart';
import 'package:coqui_app/Widgets/chat_app_bar.dart';
import 'package:coqui_app/Widgets/chat_drawer.dart';
import 'package:responsive_framework/responsive_framework.dart';

class CoquiMainPage extends StatelessWidget {
  const CoquiMainPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (ResponsiveBreakpoints.of(context).isMobile) {
      return const _CoquiMobileMainPage();
    } else {
      return const _CoquiLargeMainPage();
    }
  }
}

class _CoquiMobileMainPage extends StatelessWidget {
  const _CoquiMobileMainPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: ChatAppBar(),
      body: SafeArea(child: ChatPage()),
      drawer: ChatDrawer(),
    );
  }
}

class _CoquiLargeMainPage extends StatelessWidget {
  const _CoquiLargeMainPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            ChatDrawer(),
            Expanded(child: ChatPage()),
          ],
        ),
      ),
    );
  }
}
