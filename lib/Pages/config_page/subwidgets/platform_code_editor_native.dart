import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';

import 'code_find_panel.dart';

class ConfigEditorController {
  late final CodeLineEditingController _codeController;
  late final CodeScrollController _scrollController;
  late final CodeFindController _findController;

  ConfigEditorController() {
    _codeController = CodeLineEditingController.fromText('');
    _scrollController = CodeScrollController();
    _findController = CodeFindController(_codeController);
  }

  CodeLineEditingController get codeController => _codeController;
  CodeScrollController get scrollController => _scrollController;
  CodeFindController get findController => _findController;

  String get text => _codeController.text;
  set text(String value) => _codeController.text = value;

  void addListener(VoidCallback listener) =>
      _codeController.addListener(listener);
  void removeListener(VoidCallback listener) =>
      _codeController.removeListener(listener);

  void dispose() {
    _codeController.dispose();
    _scrollController.dispose();
    _findController.dispose();
  }
}

class PlatformCodeEditor extends StatelessWidget {
  final ConfigEditorController controller;

  const PlatformCodeEditor({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return CodeEditor(
      controller: controller.codeController,
      scrollController: controller.scrollController,
      findController: controller.findController,
      wordWrap: false,
      style: CodeEditorStyle(
        fontSize: 13,
        fontFamily: 'GeistMono',
        fontHeight: 1.5,
        codeTheme: CodeHighlightTheme(
          languages: {
            'json': CodeHighlightThemeMode(mode: langJson),
          },
          theme: Theme.of(context).brightness == Brightness.dark
              ? atomOneDarkTheme
              : atomOneLightTheme,
        ),
      ),
      indicatorBuilder: (context, editingController, chunkController, notifier) {
        return Row(
          children: [
            DefaultCodeLineNumber(
              controller: editingController,
              notifier: notifier,
            ),
            DefaultCodeChunkIndicator(
              width: 20,
              controller: chunkController,
              notifier: notifier,
            ),
          ],
        );
      },
      findBuilder: (context, controller, readOnly) =>
          CodeFindPanelView(controller: controller, readOnly: readOnly),
      sperator: VerticalDivider(
        // Note: "sperator" is the correct param name (upstream typo)
        width: 1,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}
