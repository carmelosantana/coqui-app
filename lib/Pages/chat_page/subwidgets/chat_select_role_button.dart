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
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
      ),
      icon: const Icon(Icons.auto_awesome_outlined),
      label: Text(currentRoleName ?? 'Select a role'),
      onPressed: onPressed,
    );
  }
}
