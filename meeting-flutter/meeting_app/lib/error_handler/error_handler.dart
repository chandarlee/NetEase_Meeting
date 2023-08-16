// Copyright (c) 2022 NetEase, Inc. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nemeeting/error_handler/bugly_error_handler.dart';
import 'package:nemeeting/error_handler/do_nothing_handler.dart';

abstract class ErrorHandler {
  static ErrorHandler? _handler;

  ErrorHandler();

  factory ErrorHandler.instance() {
    _handler ??= Platform.isAndroid ? BuglyErrorHandler() : DoNothingErrorHandler();
    return _handler!;
  }

  @mustCallSuper
  Future<void> install() async {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) async {
      await recordFlutterError(details);
      originalOnError?.call(details);
    };
  }

  Future<void> recordError(dynamic exception, StackTrace? stack,
      {bool fatal = false});

  Future<void> recordFlutterError(FlutterErrorDetails flutterErrorDetails,
      {bool fatal = false});
}
