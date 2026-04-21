class PromptFileService {
  const PromptFileService();

  Future<String> savePrompt({
    required String prompt,
    required String role,
    String? profile,
  }) {
    throw UnsupportedError('Saving prompt files is not supported here.');
  }

  Future<void> openFile(String path) {
    throw UnsupportedError('Opening files is not supported here.');
  }
}
