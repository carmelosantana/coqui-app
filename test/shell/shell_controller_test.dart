import 'package:flutter_test/flutter_test.dart';
import 'package:coqui_app/Pages/shell/shell_controller.dart';

void main() {
  test('selecting persona notifies and stores', () {
    final c = ShellController();
    var n = 0;
    c.addListener(() => n++);
    c.selectPersona('caelum');
    expect(c.activePersona, 'caelum');
    expect(n, 1);
  });
  test('loop panel open/close toggles', () {
    final c = ShellController()..openLoopPanel('loop-1');
    expect(c.loopPanelOpen, true);
    expect(c.activeLoopId, 'loop-1');
    c.closeLoopPanel();
    expect(c.loopPanelOpen, false);
  });
}
