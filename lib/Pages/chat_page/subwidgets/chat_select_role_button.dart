import 'package:flutter/material.dart';

class ChatSelectRoleButton extends StatelessWidget {
  final String? currentRoleName;
  final void Function() onPressed;

  const ChatSelectRoleButton({
    super.key,
    this.currentRoleName,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      icon: const Icon(Icons.auto_awesome_outlined),
      label: Text(currentRoleName ?? 'Select a role to start'),
      iconAlignment: IconAlignment.end,
      onPressed: onPressed,
    );
  }
}
