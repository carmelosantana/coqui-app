// Adapted from the re_editor example:
// https://github.com/rei-abekura-lvgs/re_editor/blob/main/example/lib/find.dart
//
// CodeFindPanelView is not exported by the re_editor package itself — it ships
// as example code that callers are expected to copy and customise.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

const EdgeInsetsGeometry _kFindMargin = EdgeInsets.only(right: 10);
const double _kFindPanelWidth = 360;
const double _kFindPanelHeight = 36;
const double _kReplacePanelHeight = _kFindPanelHeight * 2;
const double _kIconSize = 16;
const double _kIconWidth = 30;
const double _kIconHeight = 30;
const double _kInputFontSize = 13;
const double _kResultFontSize = 12;
const EdgeInsetsGeometry _kFindPadding = EdgeInsets.only(
  left: 5,
  right: 5,
  top: 2.5,
  bottom: 2.5,
);
const EdgeInsetsGeometry _kInputContentPadding = EdgeInsets.only(
  left: 5,
  right: 5,
);

/// Find/replace panel for the [CodeEditor] widget.
///
/// Pass an instance to [CodeEditor.findBuilder]. The panel hides itself
/// (zero height) when [CodeFindController.value] is `null`.
class CodeFindPanelView extends StatelessWidget implements PreferredSizeWidget {
  final CodeFindController controller;
  final EdgeInsetsGeometry margin;
  final bool readOnly;
  final Color? iconColor;
  final Color? iconSelectedColor;
  final double iconSize;
  final double inputFontSize;
  final double resultFontSize;
  final Color? inputTextColor;
  final Color? resultFontColor;
  final EdgeInsetsGeometry padding;
  final InputDecoration decoration;

  const CodeFindPanelView({
    super.key,
    required this.controller,
    this.margin = _kFindMargin,
    required this.readOnly,
    this.iconColor,
    this.iconSelectedColor,
    this.iconSize = _kIconSize,
    this.inputFontSize = _kInputFontSize,
    this.resultFontSize = _kResultFontSize,
    this.inputTextColor,
    this.resultFontColor,
    this.padding = _kFindPadding,
    this.decoration = const InputDecoration(
      filled: true,
      contentPadding: _kInputContentPadding,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(0)),
        gapPadding: 0,
      ),
    ),
  });

  @override
  Size get preferredSize => Size(
        double.infinity,
        controller.value == null
            ? 0
            : ((controller.value!.replaceMode
                        ? _kReplacePanelHeight
                        : _kFindPanelHeight) +
                    margin.vertical),
      );

  @override
  Widget build(BuildContext context) {
    if (controller.value == null) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: margin,
      alignment: Alignment.topRight,
      height: preferredSize.height,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _kFindPanelWidth,
          child: Column(
            children: [
              _buildFindRow(context),
              if (controller.value!.replaceMode) _buildReplaceRow(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFindRow(BuildContext context) {
    final value = controller.value!;
    final resultText = value.result == null
        ? 'none'
        : '${value.result!.index + 1}/${value.result!.matches.length}';

    return Row(
      children: [
        SizedBox(
          width: _kFindPanelWidth / 1.75,
          height: _kFindPanelHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _buildTextField(
                context: context,
                controller: controller.findInputController,
                focusNode: controller.findInputFocusNode,
                iconsWidth: _kIconWidth * 1.5,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildToggleText(
                    context: context,
                    text: 'Aa',
                    checked: value.option.caseSensitive,
                    onPressed: controller.toggleCaseSensitive,
                  ),
                  _buildToggleText(
                    context: context,
                    text: '.*',
                    checked: value.option.regex,
                    onPressed: controller.toggleRegex,
                  ),
                ],
              ),
            ],
          ),
        ),
        Text(
          resultText,
          style: TextStyle(color: resultFontColor, fontSize: resultFontSize),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildIconButton(
                icon: Icons.arrow_upward,
                tooltip: 'Previous',
                onPressed:
                    value.result == null ? null : controller.previousMatch,
              ),
              _buildIconButton(
                icon: Icons.arrow_downward,
                tooltip: 'Next',
                onPressed: value.result == null ? null : controller.nextMatch,
              ),
              _buildIconButton(
                icon: Icons.close,
                tooltip: 'Close',
                onPressed: controller.close,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReplaceRow(BuildContext context) {
    final value = controller.value!;
    return Row(
      children: [
        SizedBox(
          width: _kFindPanelWidth / 1.75,
          height: _kFindPanelHeight,
          child: _buildTextField(
            context: context,
            controller: controller.replaceInputController,
            focusNode: controller.replaceInputFocusNode,
          ),
        ),
        _buildIconButton(
          icon: Icons.done,
          tooltip: 'Replace',
          onPressed: value.result == null ? null : controller.replaceMatch,
        ),
        _buildIconButton(
          icon: Icons.done_all,
          tooltip: 'Replace All',
          onPressed:
              value.result == null ? null : controller.replaceAllMatches,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required BuildContext context,
    required TextEditingController controller,
    required FocusNode focusNode,
    double iconsWidth = 0,
  }) {
    return Padding(
      padding: padding,
      child: TextField(
        maxLines: 1,
        focusNode: focusNode,
        style: TextStyle(color: inputTextColor, fontSize: inputFontSize),
        decoration: decoration.copyWith(
          contentPadding: (decoration.contentPadding ?? EdgeInsets.zero)
              .add(EdgeInsets.only(right: iconsWidth)),
        ),
        controller: controller,
      ),
    );
  }

  Widget _buildToggleText({
    required BuildContext context,
    required String text,
    required bool checked,
    required VoidCallback onPressed,
  }) {
    final selectedColor =
        iconSelectedColor ?? Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onPressed,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: SizedBox(
          width: _kIconWidth * 0.75,
          child: Text(
            text,
            style: TextStyle(
              color: checked ? selectedColor : iconColor,
              fontSize: inputFontSize,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    VoidCallback? onPressed,
    String? tooltip,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: iconSize),
      constraints: const BoxConstraints(
        maxWidth: _kIconWidth,
        maxHeight: _kIconHeight,
      ),
      tooltip: tooltip,
      splashRadius: max(_kIconWidth, _kIconHeight) / 2,
    );
  }
}
