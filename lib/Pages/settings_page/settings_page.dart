import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'subwidgets/subwidgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: GoogleFonts.pacifico()),
      ),
      body: const SafeArea(
        child: _SettingsPageContent(),
      ),
    );
  }
}

class _SettingsPageContent extends StatelessWidget {
  const _SettingsPageContent();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: const [
        ThemesSettings(),
        SizedBox(height: 16),
        InstanceSettings(),
        SizedBox(height: 16),
        RoleSettings(),
        SizedBox(height: 16),
        AboutSettings(),
      ],
    );
  }
}
