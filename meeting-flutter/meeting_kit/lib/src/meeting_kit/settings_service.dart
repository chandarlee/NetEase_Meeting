// Copyright (c) 2022 NetEase, Inc. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

part of meeting_kit;

/// 会议设置服务，可设置入会时、会议中的一些配置信息
/// 如入会时的音视频开关选项，如果在入会时未指定[NEMeetingOptions]，则使用该设置服务提供的默认值
/// 该设置服务使用设备本地存储，暂不支持漫游
/// 可通过 {@link NEMeetingKit#getSettingsService()} 获取对应的服务实例。
abstract class NESettingsService extends ValueNotifier<Map> {
  NESettingsService() : super({});

  /// 设置是否显示会议时长
  ///
  /// [enable] true-开启，false-关闭
  @Deprecated('use setMeetingElapsedTimeDisplayType')
  void enableShowMyMeetingElapseTime(bool enable);

  /// 查询是否显示会议时长
  @Deprecated('use getMeetingElapsedTimeDisplayType')
  Future<bool> isShowMyMeetingElapseTimeEnabled();

  /// 设置会议时长展示类型
  ///
  /// [type] 会议时长展示类型
  void setMeetingElapsedTimeDisplayType(NEMeetingElapsedTimeDisplayType type);

  /// 查询会议时长展示类型
  Future<NEMeetingElapsedTimeDisplayType> getMeetingElapsedTimeDisplayType();

  /// 设置入会时是否打开本地视频
  ///
  /// [enable] true-入会时打开视频，false-入会时关闭视频
  void enableTurnOnMyVideoWhenJoinMeeting(bool enable);

  /// 查询入会时是否打开本地视频
  Future<bool> isTurnOnMyVideoWhenJoinMeetingEnabled();

  /// 设置入会时是否打开本地音频
  ///
  /// [enable] true-入会时打开音频，false-入会时关闭音频
  void enableTurnOnMyAudioWhenJoinMeeting(bool enable);

  /// 查询入会时是否打开本地音频
  Future<bool> isTurnOnMyAudioWhenJoinMeetingEnabled();

  /// 查询应用是否支持会议直播
  bool isMeetingLiveSupported();

  /// 查询应用是否支持白板共享
  bool isMeetingWhiteboardSupported();

  /// 查询应用是否支持云端录制服务
  bool isMeetingCloudRecordSupported();

  /// 设置是否打开音频智能降噪
  ///
  /// [enable] true-开启，false-关闭
  void enableAudioAINS(bool enable);

  /// 查询音频智能降噪是否打开
  Future<bool> isAudioAINSEnabled();

  /// 设置是否显示虚拟背景
  ///
  /// [enable] true 显示 false不显示
  void enableVirtualBackground(bool enable);

  /// 查询虚拟背景是否显示
  Future<bool> isVirtualBackgroundEnabled();

  /// 设置内置虚拟背景图片路径列表
  ///
  /// [pathList] 虚拟背景图片路径列表
  void setBuiltinVirtualBackgroundList(List<String> pathList);

  /// 获取内置虚拟背景图片路径列表
  Future<List<String>> getBuiltinVirtualBackgroundList();

  /// 设置外部虚拟背景图片路径列表
  ///
  /// [pathList] 虚拟背景图片路径列表
  void setExternalVirtualBackgroundList(List<String> pathList);

  /// 获取外部虚拟背景图片路径列表
  Future<List<String>> getExternalVirtualBackgroundList();

  /// 设置最近选择的虚拟背景图片路径
  ///
  /// [path] 虚拟背景图片路径,为空代表不设置虚拟背景
  void setCurrentVirtualBackground(String? path);

  /// 获取最近选择的虚拟背景图片路径
  Future<String?> getCurrentVirtualBackground();

  /// 设置是否开启语音激励
  ///
  /// [enable] true-开启，false-关闭
  void enableSpeakerSpotlight(bool enable);

  /// 查询是否打开语音激励
  Future<bool> isSpeakerSpotlightEnabled();

  /// 设置是否打开前置摄像头镜像
  ///
  /// [enable] true-打开，false-关闭
  Future<void> enableFrontCameraMirror(bool enable);

  /// 查询前置摄像头镜像是否打开
  Future<bool> isFrontCameraMirrorEnabled();

  /// 设置是否打开白板透明
  ///
  /// [enable] true-打开，false-关闭
  Future<void> enableTransparentWhiteboard(bool enable);

  /// 查询白板透明是否打开
  Future<bool> isTransparentWhiteboardEnabled();

  /// 查询应用是否支持美颜
  bool isBeautyFaceSupported();

  /// 获取当前美颜参数，关闭返回0
  Future<int> getBeautyFaceValue();

  /// 设置美颜参数
  ///
  /// [value] 传入美颜等级，参数规则为[0,10]整数
  Future<void> setBeautyFaceValue(int value);

  /// 查询应用是否支持等候室
  bool isWaitingRoomSupported();

  /// 查询应用是否支持虚拟背景
  bool isVirtualBackgroundSupported();

  /// 查询应用同声传译配置
  NEInterpretationConfig getInterpretationConfig();

  /// 查询应用预约会议指定成员配置
  NEScheduledMemberConfig getScheduledMemberConfig();

  /// 查询应用是否支持编辑昵称
  bool isNicknameUpdateSupported();

  /// 查询应用是否支持编辑头像
  bool isAvatarUpdateSupported();

  /// 查询应用是否支持字幕功能
  bool isCaptionsSupported();

  /// 查询应用是否支持转写功能
  bool isTranscriptionSupported();

  /// 查询应用是否支持访客入会
  bool isGuestJoinSupported();

  /// 查询应用是否支持聊天室服务
  bool isMeetingChatSupported();

  /// 查询应用session会话Id
  String getAppNotifySessionId();

  /// 查询云录制配置
  Future<NECloudRecordConfig> getCloudRecordConfig();

  /// 设置云录制配置
  void setCloudRecordConfig(NECloudRecordConfig config);

  ///
  /// 设置会中字幕/转写翻译语言
  /// - [language] 目标翻译语言
  ///
  Future<int> setASRTranslationLanguage(
      NEMeetingASRTranslationLanguage language);

  ///
  /// 获取会中字幕/转写翻译语言
  ///
  NEMeetingASRTranslationLanguage getASRTranslationLanguage();

  ///
  /// 开启会中字幕同时显示双语
  /// - [enable] true-开启，false-关闭
  ///
  Future<int> enableCaptionBilingual(bool enable);

  ///
  /// 查询会中字幕同时显示双语是否开启
  ///
  bool isCaptionBilingualEnabled();

  ///
  /// 开启会中转写同时显示双语
  /// - [enable] true-开启，false-关闭
  ///
  Future<int> enableTranscriptionBilingual(bool enable);

  ///
  /// 查询会中转写同时显示双语是否开启
  ///
  bool isTranscriptionBilingualEnabled();

  ///
  /// 添加设置变更监听器
  ///
  void addSettingsChangedListener(NESettingsChangedListener listener);

  ///
  /// 移除设置变更监听器
  ///
  void removeSettingsChangedListener(NESettingsChangedListener listener);

  ///
  /// 设置聊天新消息提醒类型
  ///
  void setChatMessageNotificationType(NEChatMessageNotificationType type);

  ///
  /// 查询聊天新消息提醒类型
  ///
  Future<NEChatMessageNotificationType> getChatMessageNotificationType();

  /// 查询是否在视频中显示用户名
  Future<bool> isShowNameInVideoEnabled();

  /// 设置是否在视频中显示用户名
  Future<void> enableShowNameInVideo(bool enable);

  /// 设置是否显示未入会成员
  ///
  /// [enable] true-开启，false-关闭
  void enableShowNotYetJoinedMembers(bool enable);

  /// 查询是否显示未入会成员
  Future<bool> isShowNotYetJoinedMembersEnabled();

  /// 查询应用是否支持会议设备邀请
  bool isCallOutRoomSystemDeviceSupported();

  ///
  /// 设置开启/关闭隐藏非视频参会者。默认为 false，即显示非视频参会者。
  ///
  /// [enable] true: 隐藏非视频参会者；false: 显示非视频参会者
  ///
  Future<void> enableHideVideoOffAttendees(bool enable);

  ///
  /// 查询是否开启隐藏非视频参会者。
  ///
  Future<bool> isHideVideoOffAttendeesEnabled();

  ///
  /// 设置开启/关闭隐藏本人视图。默认为 false，即显示本人视图。
  ///
  /// [enable] true: 隐藏本人视图；false: 显示本人视图
  ///
  Future<void> enableHideMyVideo(bool enable);

  ///
  /// 查询是否开启隐藏本人视图。
  ///
  Future<bool> isHideMyVideoEnabled();

  /// 设置是否离开会议需要弹窗确认
  ///
  /// [enable] true-开启，false-关闭
  void enableLeaveTheMeetingRequiresConfirmation(bool enable);

  /// 查询是否离开会议需要弹窗确认
  Future<bool> isLeaveTheMeetingRequiresConfirmationEnabled();
}
