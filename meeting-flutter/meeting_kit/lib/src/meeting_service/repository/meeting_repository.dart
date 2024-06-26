// Copyright (c) 2022 NetEase, Inc. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

part of meeting_service;

class MeetingRepository {
  /// 创建会议
  static Future<NEResult<MeetingInfo>> createMeeting({
    required NEMeetingType type,
    String? subject,
    String? password,
    required int roomConfigId,
    Map? roomProperties,
    Map? roleBinds,
    bool enableWaitingRoom = false,
    NEMeetingFeatureConfig featureConfig = const NEMeetingFeatureConfig(),
  }) {
    return HttpApiHelper.execute(
      _CreateMeetingApi(
        type,
        _CreateMeetingRequest(
          subject: subject,
          password: password,
          enableWaitingRoom: enableWaitingRoom,
          roomConfigId: roomConfigId,
          roomProperties:
              roomProperties?.map((k, v) => MapEntry(k, {'value': v})),
          roleBinds: roleBinds,
          featureConfig: featureConfig,
        ),
      ),
    );
  }

  static Future<NEResult<MeetingInfo>> getMeetingInfo(String meetingId) {
    return HttpApiHelper.execute(_GetMeetingInfoApi(meetingId));
  }

  static Future<NEResult<MeetingInfo>> getMeetingInfoBySharingCode(
      String sharingCode) async {
    LoginInfo? logInfo = await SDKPreferences.getLoginInfo();
    return HttpApiHelper.execute(
        _GetMeetingBySharingCodeApi(sharingCode, logInfo));
  }

  static Future<NEResult<MeetingInfo>> getMeetingInfoEx(
      {String? meetingId, String? meetingCode}) async {
    if (meetingId != null && meetingId.isNotEmpty) {
      return HttpApiHelper.execute(_GetMeetingInfoApi(meetingId));
    } else if (meetingCode != null && meetingCode.isNotEmpty) {
      return HttpApiHelper.execute(_GetMeetingInfoApi2(meetingCode));
    }
    return NEResult(code: -1);
  }

  /// 匿名登陆
  static Future<NEResult<AnonymousLoginInfo>> anonymousLogin() {
    return HttpApiHelper._anonymousLogin();
  }

  /// 获取会议主持人信息
  static Future<NEResult<List<NERoomMember>>> getHostAndCoHostList(roomUuid) {
    return HttpApiHelper._getHostAndCoHostList(roomUuid);
  }

  /// 获取最新的房间属性
  static Future<NEResult<Map<String, dynamic>>> getWaitingRoomProperties(
      roomUuid) {
    return HttpApiHelper._getWaitingRoomProperties(roomUuid);
  }
}
