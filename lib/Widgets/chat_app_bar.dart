import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:coqui_app/Constants/constants.dart';
import 'package:coqui_app/Models/coqui_role.dart';
import 'package:coqui_app/Providers/chat_provider.dart';
import 'package:coqui_app/Widgets/bottom_sheet_header.dart';
import 'package:coqui_app/Widgets/role_list_tile.dart';
import 'package:coqui_app/Widgets/selection_bottom_sheet.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);

    return AppBar(
      title: Column(
        children: [
          Text(AppConstants.appName, style: GoogleFonts.pacifico()),
          if (chatProvider.currentSession != null)
            InkWell(
              onTap: () {
                _handleRoleSelectionButton(context);
              },
              customBorder: const StadiumBorder(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  chatProvider.currentSession!.modelRole,
                  style: GoogleFonts.kodeMono(
                    textStyle: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
            ),
        ],
      ),
      actions: [
        if (chatProvider.currentSession != null)
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () {
              _handleConfigureButton(context);
            },
          ),
      ],
      forceMaterialTransparency: !ResponsiveBreakpoints.of(context).isMobile,
    );
  }

  Future<void> _handleRoleSelectionButton(BuildContext context) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    await showSelectionBottomSheet<CoquiRole>(
      context: context,
      header: const BottomSheetHeader(title: "Available Roles"),
      fetchItems: () async {
        return await chatProvider.fetchAvailableRoles();
      },
      currentSelection: null,
      itemBuilder: (role, selected, onSelected) {
        return RoleListTile(
          role: role,
          selected: selected,
          onSelected: onSelected,
        );
      },
    );
  }

  Future<void> _handleConfigureButton(BuildContext context) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          minimum: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BottomSheetHeader(title: 'Session Options'),
              const Divider(),
              if (chatProvider.lastTurnSummary != null)
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Last Turn'),
                  subtitle: Text(chatProvider.lastTurnSummary!),
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete Session'),
                textColor: Theme.of(context).colorScheme.error,
                iconColor: Theme.of(context).colorScheme.error,
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ],
          ),
        );
      },
    );

    if (action == 'delete') {
      await chatProvider.deleteCurrentSession();
    }
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
