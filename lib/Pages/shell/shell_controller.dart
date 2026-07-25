import 'package:flutter/foundation.dart';

/// Holds shell-level navigation state for the Discord-style reskin:
/// the active persona, the active session, and the loop monitor panel.
///
/// Shell widgets (persona rail, session rail, loop monitor) read and mutate
/// this via `provider`. Each mutator updates state then notifies listeners.
class ShellController extends ChangeNotifier {
  String? activePersona;
  String? activeSessionId;
  bool loopPanelOpen = false;
  String? activeLoopId;

  void selectPersona(String? persona) {
    activePersona = persona;
    notifyListeners();
  }

  void selectSession(String? sessionId) {
    activeSessionId = sessionId;
    notifyListeners();
  }

  void openLoopPanel(String loopId) {
    loopPanelOpen = true;
    activeLoopId = loopId;
    notifyListeners();
  }

  void closeLoopPanel() {
    loopPanelOpen = false;
    notifyListeners();
  }
}
