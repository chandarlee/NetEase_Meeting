// Copyright (c) 2022 NetEase, Inc. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

package com.netease.yunxin.meeting.util;

import android.content.Context;
import android.os.Build;

import androidx.annotation.NonNull;

import com.netease.yunxin.meeting.MeetingApplication;
import com.tencent.bugly.crashreport.CrashReport;

import java.util.concurrent.atomic.AtomicBoolean;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class BuglyErrorHandler {

    private static final String CHANNEL = "meeting.error.handler/bugly";

    private static AtomicBoolean initialized = new AtomicBoolean(false);

    public static void install() {
        if (initialized.compareAndSet(false, true)) {
            MeetingApplication application = MeetingApplication.getApplication();
            new MethodChannel(application.getEngine().getDartExecutor().getBinaryMessenger(), CHANNEL)
                    .setMethodCallHandler((call, result) -> {
                        final String method = call.method;
                        if (method.equals("init")) {
                            Context context = application.getApplicationContext();
                            String appId = call.argument("appId");
                            boolean debugMode = call.argument("debugMode");
                            CrashReport.initCrashReport(context, appId, debugMode);
                            CrashReport.setDeviceModel(context, Build.MODEL);
                            result.success(null);
                        } else if (method.equals("testCrash")) {
                            CrashReport.testNativeCrash();
                            result.success(null);
                        } else if (method.equals("setUserId")) {
                            CrashReport.setUserId(call.argument("userId"));
                            result.success(null);
                        } else if (method.equals("postCatchedException")) {
                            String message = call.argument("message");
                            String stack = call.argument("stack");
                            CrashReport.postCatchedException(new Throwable("message: " + message + "\r\nstack: " + stack));
                            result.success(null);
                        } else {
                            result.notImplemented();
                        }
                    });
        }
    }

}
