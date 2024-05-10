// Copyright (c) 2022 NetEase, Inc. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

part of meeting_kit;

class _NEMeetingInviteServiceImpl extends NEMeetingInviteService
    with _AloggerMixin, EventTrackMixin, _MeetingKitLocalizationsMixin {
  static final _NEMeetingInviteServiceImpl _instance =
      _NEMeetingInviteServiceImpl._();

  factory _NEMeetingInviteServiceImpl() => _instance;
  late final _meetingService = NEMeetingKit.instance.getMeetingService();

  final List<NEMeetingInviteListener> _listeners = <NEMeetingInviteListener>[];

  List<NEMeetingInviteListener> get listeners => _listeners;

  static const kTypeMeetingInviteStatusChanged = 82;

  static const kTypeMeetingSelfJoinRoom = 30;
  static const kTypeMeetingSelfLeaveByRoomClosed = 33;
  static const kTypeMeetingByRoomClosed = 51;

  _NEMeetingInviteServiceImpl._() {
    NERoomKit.instance.messageChannelService.addMessageChannelCallback(
        NEMessageChannelCallback(onReceiveCustomMessage: (message) async {
      try {
        commonLogger.i('invite ,message ${message.data}');

        var data = json.decode(message.data);
        final String? _userUuId = NEMeetingKit.instance
            .getAccountService()
            .getAccountInfo()
            ?.userUuid;

        /// 判断被操作人是不是自己
        bool isSelf = false;
        switch (message.commandId) {
          case kTypeMeetingSelfJoinRoom:
          case kTypeMeetingSelfLeaveByRoomClosed:
            isSelf = _userUuId == data?['members']?[0]?['userUuid'];
            break;
          case kTypeMeetingByRoomClosed:
            isSelf = true;
            break;
          case kTypeMeetingInviteStatusChanged:
            isSelf = _userUuId == data['member']['userUuid'];
            break;
        }
        if (isSelf) {
          _listeners.forEach((element) {
            /// 如果当前会议室和邀请的会议室一致，则直接移除邀请页面
            final currentInviteData =
                InviteQueueUtil.instance.currentInviteData.value;
            if (currentInviteData?.roomUuid == message.roomUuid) {
              InviteQueueUtil.instance.disposeInvite(currentInviteData);
            }

            /// 如果当前会议室和邀请的会议室一致，则直接移除邀请
            InviteQueueUtil.instance.inviteQueue.forEach((element) {
              if (element.roomUuid == message.roomUuid) {
                InviteQueueUtil.instance.disposeInvite(element);
              }
            });

            final inviteInfoObj = NEMeetingInviteInfo.fromMap(
                currentInviteData?.inviteInfo?.toMap());
            inviteInfoObj.meetingNum = currentInviteData?.meetingNum ?? '';
            final meetingId = currentInviteData?.meetingId ?? '';
            NEMeetingInviteStatus status = NEMeetingInviteStatus.unknown;
            if (message.commandId == kTypeMeetingInviteStatusChanged ||
                message.commandId == kTypeMeetingByRoomClosed) {
              status = NEMeetingInviteStatus.canceled;
            }
            if (message.commandId == kTypeMeetingSelfLeaveByRoomClosed ||
                message.commandId == kTypeMeetingSelfJoinRoom) {
              status = NEMeetingInviteStatus.removed;
            }
            element.onMeetingInviteStatusChanged(
                status, meetingId.toString(), inviteInfoObj);
          });
        }
      } catch (e) {
        debugPrint('parse message channel service message error: $e');
      }
    }));
  }

  @override
  Future<NEResult<NERoomContext>> acceptInvite(
      NEJoinMeetingParams param, NEJoinMeetingOptions opts) async {
    apiLogger.i('joinMeetingByInvite param: $param, opts: $opts');
    return _meetingService.joinMeeting(param, opts, isInvite: true);
  }

  @override
  Future<NEResult<VoidResult>> rejectInvite(String meetingId) {
    apiLogger.i('rejectInvite meetingId: $meetingId');
    final currentInviteData = InviteQueueUtil.instance.currentInviteData.value;
    if (currentInviteData?.meetingId != null &&
        currentInviteData?.meetingId!.toString() == meetingId &&
        currentInviteData?.roomUuid != null) {
      return NERoomKit.instance.roomService
          .rejectInvite(currentInviteData!.roomUuid!);
    }
    return Future.value(
        NEResult(code: -1, msg: 'rejectInvite error meetingId not exist'));
  }

  @override
  void addEventListener(NEMeetingInviteListener listener) {
    apiLogger.i('addEventListener, listener: $listener');
    if (_listeners.contains(listener)) {
      return;
    }
    _listeners.add(listener);
  }

  @override
  void removeEventListener(NEMeetingInviteListener listener) {
    apiLogger.i('removeEventListener, listener: $listener');
    if (_listeners.contains(listener)) {
      _listeners.remove(listener);
    }
  }
}
