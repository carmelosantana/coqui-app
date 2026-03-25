import 'package:flutter/material.dart';

class ConfigEditorController {
  final TextEditingController _textController = TextEditingController();

  TextEditingController get textController => _textController;

  String get text => _textController.text;
  set text(String value) {
    _textController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void addListener(VoidCallback listener) =>
      _textController.addListener(listener);
  void removeListener(VoidCallback listener) =>
      _textController.removeListener(listener);

  void dispose() => _textController.dispose();
}

class PlatformCodeEditor extends StatelessWidget {
  final ConfigEditorController controller;

  const PlatformCodeEditor({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller.textController,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      style: const TextStyle(
        fontFamily: 'GeistMono',
        fontSize: 13,
        height: 1.5,
      ),
      decoration: InputDecoration(
        border: InputBorder.none,
        contentPadding: const EdgeInsets.all(12),
        fillColor: Theme.of(context).colorScheme.surface,
        filled: true,
      ),
    );
  }
}
