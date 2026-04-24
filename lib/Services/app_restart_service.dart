import 'package:flutter/services.dart';

import 'package:coqui_app/Platform/platform_info.dart';

enum AppRestartResult {
  restarted,
  requiresManualRestart,
  failed,
}

class AppRestartService {
  static const MethodChannel _channel = MethodChannel('coqui/app');

  const AppRestartService();

  Future<bool> isRestartSupported() async {
    if (PlatformInfo.isWeb || PlatformInfo.isIOS) {
      return false;
    }

    try {
      return await _channel.invokeMethod<bool>('isRestartSupported') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<AppRestartResult> restartApplication() async {
    final supported = await isRestartSupported();
    if (!supported) {
      return AppRestartResult.requiresManualRestart;
    }

    try {
      final restarted =
          await _channel.invokeMethod<bool>('restartApplication') ?? false;
      return restarted ? AppRestartResult.restarted : AppRestartResult.failed;
    } on MissingPluginException {
      return AppRestartResult.requiresManualRestart;
    } on PlatformException {
      return AppRestartResult.failed;
    }
  }
}