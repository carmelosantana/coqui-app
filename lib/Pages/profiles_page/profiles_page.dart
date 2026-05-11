import 'package:flutter/material.dart';

import 'package:coqui_app/Pages/profiles_page/profile_manager.dart';

class ProfilesPage extends StatefulWidget {
  const ProfilesPage({super.key});

  @override
  State<ProfilesPage> createState() => _ProfilesPageState();
}

class _ProfilesPageState extends State<ProfilesPage> {
  final ProfileManagerController _profileManagerController =
      ProfileManagerController();

  Future<bool> _handleExitAttempt() async {
    return _profileManagerController.confirmPageExit();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }

        final canExit = await _handleExitAttempt();
        if (!context.mounted || !canExit) {
          return;
        }

        Navigator.of(context).pop(result);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: () async {
              final canExit = await _handleExitAttempt();
              if (!mounted || !canExit) {
                return;
              }
              Navigator.of(context).pop();
            },
          ),
          title: const Text('Profiles'),
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ProfileManager(controller: _profileManagerController),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
