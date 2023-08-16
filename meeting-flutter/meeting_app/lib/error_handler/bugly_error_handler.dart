// Copyright (c) 2022 NetEase, Inc. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nemeeting/base/util/global_preferences.dart';
import 'package:nemeeting/error_handler/error_handler.dart';
import 'package:nemeeting/service/auth/auth_manager.dart';

// https://bugly.qq.com/docs/user-guide/instruction-manual-android/?v=1.0.0#_5
class BuglyErrorHandler extends ErrorHandler {
  // bugly AppId
  static const buglyAppId = 'Get_From_Bugly_Console';

  final channel = MethodChannel('meeting.error.handler/bugly');

  bool _initialized = false;

  @override
  Future<void> install() async {
    super.install();
    if (Platform.isAndroid) {
      GlobalPreferences().ensurePrivacyAgree().then((value) {
        debugPrint('Install bugly error handler');
        return channel.invokeMapMethod('init', {
          'appId': buglyAppId,
          'debugMode': kDebugMode,
        });
      }).then((value) {
        _initialized = true;
        debugPrint('Success to init bugly');
        AuthManager().authInfoStream().listen((loginInfo) {
          channel.invokeMapMethod('setUserId', {
            'userId': loginInfo?.accountId ?? '',
          });
        });
      }).catchError((e, s) {
        debugPrint('Failed to init bugly: $e\n$s');
      });
    }
  }

  void testCrash() {
    if (_initialized) {
      channel.invokeMethod('testCrash');
    }
  }

  @override
  Future<void> recordError(exception, StackTrace? stack, {bool fatal = false}) {
    if (_initialized) {
      return channel.invokeMapMethod('postCatchedException', {
        'message': exception.toString(),
        'stack': stack.toString(),
      });
    }
    return Future.value(null);
  }

  @override
  Future<void> recordFlutterError(FlutterErrorDetails flutterErrorDetails,
      {bool fatal = false}) {
    if (_initialized) {
      return channel.invokeMapMethod('postCatchedException', {
        'message': flutterErrorDetails.exceptionAsString(),
        'stack': flutterErrorDetails.stack.toString(),
      });
    }
    return Future.value(null);
  }
}
