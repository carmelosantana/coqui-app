import 'package:flutter/material.dart';

import 'package:coqui_app/Pages/profiles_page/profile_manager.dart';

class ProfilesPage extends StatelessWidget {
  const ProfilesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profiles'),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                ProfileManager(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
