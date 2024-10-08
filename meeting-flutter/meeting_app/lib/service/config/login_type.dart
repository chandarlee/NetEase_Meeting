// Copyright (c) 2022 NetEase, Inc. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

/// 登录类型。 token登录， 验证码登录, 密码登录
/// (loginType为0，传meetingToken值
/// loginType为1, 3，传登录密码
/// loginType为2，传手机检验码)
enum LoginType { token, password, verify, third, sso }

class LoginTypeFromInt {
  static LoginType fromInt(int? type) {
    return LoginType.values.firstWhere(
      (element) => element.index == type,
      orElse: () => LoginType.token,
    );
  }
}
