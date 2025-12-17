import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:coqui_app/Models/coqui_message.dart';

import 'chat_bubble_bottom_sheet.dart';

class ChatBubbleActions {
  final CoquiMessage message;

  ChatBubbleActions(this.message);

  void handleCopy() {
    Clipboard.setData(ClipboardData(text: message.content));
  }

  void handleSelectText(BuildContext context) {
    showModalBottomSheet(
      context: context,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      isScrollControlled: true,
      builder: (context) {
        return ChatBubbleBottomSheet(
          title: 'Select Text',
          child: SelectableText(
            message.content,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        );
      },
    );
  }
}
