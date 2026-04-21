import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PromptFileService {
  const PromptFileService();

  Future<String> savePrompt({
    required String prompt,
    required String role,
    String? profile,
  }) async {
    final baseDirectory =
        await getDownloadsDirectory() ?? await getApplicationSupportDirectory();
    final exportDirectory = Directory(p.join(baseDirectory.path, 'Coqui'));
    await exportDirectory.create(recursive: true);

    final profileSuffix =
        profile != null && profile.isNotEmpty ? '-$profile' : '';
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final fileName = 'coqui-prompt-$role$profileSuffix-$timestamp.md';
    final file = File(p.join(exportDirectory.path, fileName));
    await file.writeAsString(prompt);

    return file.path;
  }

  Future<void> openFile(String path) async {
    late ProcessResult result;

    if (Platform.isMacOS) {
      result = await Process.run('open', [path]);
    } else if (Platform.isLinux) {
      result = await Process.run('xdg-open', [path]);
    } else if (Platform.isWindows) {
      result = await Process.run(
        'cmd',
        ['/c', 'start', '', path],
        runInShell: true,
      );
    } else {
      throw UnsupportedError(
          'Opening files is not supported on this platform.');
    }

    if (result.exitCode != 0) {
      throw ProcessException(
        'open',
        [path],
        (result.stderr ?? '').toString(),
        result.exitCode,
      );
    }
  }
}
