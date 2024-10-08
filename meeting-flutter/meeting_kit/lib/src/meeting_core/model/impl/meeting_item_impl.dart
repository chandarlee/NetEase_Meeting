// Copyright (c) 2022 NetEase, Inc. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

part of meeting_core;

class _MeetingItemImpl extends NEMeetingItem {
  _MeetingItemImpl() : super._();

  String? _roomUuid;

  String? _meetingNum;

  int? _meetingId;

  String? _shortMeetingNum;

  String? _subject;

  int? _startTime;

  int? _endTime;

  String? _password;

  bool _noSip = true;

  NEMeetingType? _meetingType;

  NEMeetingItemSetting? _setting;

  NEMeetingItemLive? _live;

  Map<String, NEMeetingRoleType>? _roleBinds;

  NEMeetingItemStatus _status = NEMeetingItemStatus.invalid;

  String? _sipCid;

  @override
  String? get sipCid => _sipCid;

  @override
  set sipCid(String? sipCid) {
    _sipCid = sipCid;
  }

  @override
  List<NEScheduledMember>? scheduledMemberList;

  @override
  NEMeetingType? get meetingType => _meetingType;

  set meetingType(NEMeetingType? type) {
    _meetingType = type;
  }

  @override
  String? get meetingNum => _meetingNum;

  set meetingNum(String? meetingNum) {
    _meetingNum = meetingNum;
  }

  @override
  String? get shortMeetingNum => _shortMeetingNum;

  set shortMeetingNum(String? shortMeetingNum) {
    _shortMeetingNum = shortMeetingNum;
  }

  @override
  String? get roomUuid => _roomUuid;

  set roomUuid(String? roomUuid) {
    _roomUuid = roomUuid;
  }

  @override
  String? get subject => _subject;

  @override
  set subject(String? subject) {
    _subject = subject;
  }

  @override
  int get startTime => _startTime ?? 0;

  @override
  set startTime(int start) {
    _startTime = start;
  }

  @override
  int get endTime => _endTime ?? 0;

  @override
  set endTime(int end) {
    _endTime = end;
  }

  @override
  String? get password => _password;

  @override
  set password(String? password) {
    _password = password;
  }

  @override
  set noSip(bool? noSip) {
    _noSip = noSip ?? true;
  }

  @override
  bool get noSip => _noSip;

  @override
  NEMeetingItemSetting get settings => _setting ?? NEMeetingItemSetting();

  @override
  set settings(NEMeetingItemSetting setting) {
    _setting = setting;
  }

  @override
  NEMeetingItemStatus get status => _status;

  set status(NEMeetingItemStatus status) {
    _status = status;
  }

  @override
  String? extraData;

  @override
  int? get meetingId => _meetingId;

  set meetingId(int? meetingId) {
    _meetingId = meetingId;
  }

  @override
  NEMeetingItemLive? get live => _live;

  set live(NEMeetingItemLive? live) {
    _live = live;
  }

  @override
  Map<String, NEMeetingRoleType>? get roleBinds => _roleBinds;

  set roleBinds(Map<String, NEMeetingRoleType>? roleBinds) {
    _roleBinds = roleBinds;
  }

  String? _inviteUrl;

  @override
  get inviteUrl => _inviteUrl;

  set inviteUrl(String? value) {
    _inviteUrl = value;
  }

  bool _waitingRoomEnabled = false;
  void setWaitingRoomEnabled(bool enabled) {
    _waitingRoomEnabled = enabled;
  }

  bool get waitingRoomEnabled => _waitingRoomEnabled;

  bool _enableJoinBeforeHost = true;

  bool _enableGuestJoin = false;

  @override
  bool get enableJoinBeforeHost {
    return _enableJoinBeforeHost;
  }

  @override
  void setEnableJoinBeforeHost(bool enable) {
    _enableJoinBeforeHost = enable;
  }

  @override
  bool get enableGuestJoin {
    return _enableGuestJoin;
  }

  @override
  void setEnableGuestJoin(bool enable) {
    _enableGuestJoin = enable;
  }

  NEMeetingInterpretationSettings? interpretationSettings;

  NECloudRecordConfig? cloudRecordConfig;

  String? timezoneId;

  Map handleRoomProperties() {
    var roomProperties = {}; // 参考 创建会议 ，从setting里获取controls就可以了
    int securityCtrl = 0;
    settings.controls?.forEach((control) {
      if (control is NEMeetingAudioControl) {
        securityCtrl |= MeetingSecurityCtrlValue.AUDIO_OFF;
        if (control.attendeeOff == NEMeetingAttendeeOffType.offAllowSelfOn) {
          securityCtrl &= ~MeetingSecurityCtrlValue.AUDIO_NOT_ALLOW_SELF_ON;
        } else if (control.attendeeOff ==
            NEMeetingAttendeeOffType.offNotAllowSelfOn) {
          securityCtrl |= MeetingSecurityCtrlValue.AUDIO_NOT_ALLOW_SELF_ON;
        }
      }
      if (control is NEMeetingVideoControl) {
        securityCtrl |= MeetingSecurityCtrlValue.VIDEO_OFF;
        if (control.attendeeOff == NEMeetingAttendeeOffType.offAllowSelfOn) {
          securityCtrl &= ~MeetingSecurityCtrlValue.VIDEO_NOT_ALLOW_SELF_ON;
        } else if (control.attendeeOff ==
            NEMeetingAttendeeOffType.offNotAllowSelfOn) {
          securityCtrl |= MeetingSecurityCtrlValue.VIDEO_NOT_ALLOW_SELF_ON;
        }
      }
    });
    roomProperties[MeetingSecurityCtrlKey.securityCtrlKey] =
        securityCtrl.toString();
    roomProperties[GuestJoinProperty.key] =
        _enableGuestJoin ? GuestJoinProperty.enable : GuestJoinProperty.disable;
    roomProperties[MeetingPropertyKeys.kExtraData] = extraData;
    Map map = roomProperties.map((k, v) => MapEntry(k, {'value': v}));
    if (live?.enable ?? false) {
      map['live'] = handleLiveProperties();
    }
    return map;
  }

  NEMeetingRecurringRule _recurringRule =
      NEMeetingRecurringRule(type: NEMeetingRecurringRuleType.no);

  @override
  NEMeetingRecurringRule get recurringRule => _recurringRule;

  @override
  set recurringRule(NEMeetingRecurringRule recurringRule) {
    _recurringRule = recurringRule;
  }

  ///处理直播属性
  Map handleLiveProperties() {
    bool onlyEmployeesAllow =
        live?.liveWebAccessControlLevel == NEMeetingLiveAuthLevel.appToken;
    var map = {
      'onlyEmployeesAllow': onlyEmployeesAllow,
      'liveChatRoomEnable': true
    };
    String jsonStr = jsonEncode(map);
    return {'extensionConfig': jsonStr};
  }

  @override
  Map toJson() => {
        /// flutter 传递 native 使用
        'roomUuid': _roomUuid,
        'meetingType': meetingType?.type,
        'ownerNickname': ownerNickname,
        'ownerUserUuid': ownerUserUuid,
        'inviteUrl': inviteUrl,
        'shortMeetingNum': _shortMeetingNum,
        if (_subject != null) 'subject': _subject,
        'meetingNum': _meetingNum,
        'meetingId': _meetingId,
        'startTime': _startTime,
        'endTime': _endTime,
        'status': _status.index,
        if (extraData != null) 'extraData': extraData,
        if (_password != null) 'password': _password,
        'settings': settings.toJson(),
        'live': live?.toJson(),
        'roleBinds':
            _roleBinds?.map((key, value) => MapEntry(key, value.index)),
        'noSip': _noSip,
        'waitingRoomEnabled': _waitingRoomEnabled,
        'enableJoinBeforeHost': _enableJoinBeforeHost,
        'enableGuestJoin': _enableGuestJoin,
        'recurringRule': _recurringRule.toJson(),
        'scheduledMembers':
            scheduledMemberList?.map((e) => e.toJson()).toList(),
        'interpretation': interpretationSettings?.toJson() ?? {},
        'cloudRecordConfig': cloudRecordConfig?.toJson(),
        'timezoneId': timezoneId,
        'sipCid': _sipCid,
      };

  @override
  Map request() {
    Map map = {
      'subject': _subject,
      if (_startTime != 0) 'startTime': _startTime,
      if (_endTime != 0) 'endTime': _endTime,
      'password': _password,
      'roomConfigId': kMeetingTemplateId,
      'roomProperties': handleRoomProperties(),
      'openWaitingRoom': _waitingRoomEnabled,
      'enableJoinBeforeHost': _enableJoinBeforeHost,
      'roomConfig': {
        'resource': {
          // 'waitingRoom': _waitingRoomEnabled,
          'live': live?.enable,
          'record': cloudRecordConfig?.enable,
          'sip': !_noSip
        }
      },
      if (_roleBinds != null)
        'roleBinds': _roleBinds?.map((key, value) {
          var roleType = MeetingRoles.mapEnumRoleToString(value);
          return MapEntry(key, roleType);
        }),

      /// 周期性会议
      'recurringRule': _recurringRule.toJson(),

      /// 预约会议指定成员
      'scheduledMembers': scheduledMemberList?.map((e) => e.toJson()).toList(),

      // if (interpretationSettings?.isEmpty == false)
      'interpretation': interpretationSettings?.toJson() ?? {},

      'recordConfig': cloudRecordConfig?.toJson(),

      /// 时区ID
      'timezoneId': timezoneId,
    };
    return map;
  }

  @override
  NEMeetingItem copy() {
    _MeetingItemImpl impl = _MeetingItemImpl();
    impl.ownerUserUuid = ownerUserUuid;
    impl.ownerNickname = ownerNickname;
    impl.meetingType = meetingType;
    impl.meetingNum = meetingNum;
    impl.shortMeetingNum = shortMeetingNum;
    impl.roomUuid = roomUuid;
    impl.meetingId = meetingId;
    impl.subject = subject;
    impl.startTime = startTime;
    impl.endTime = endTime;
    impl.password = password;
    impl.settings = settings;
    impl.status = status;
    impl.extraData = extraData;
    impl.live = live;
    impl.roleBinds = roleBinds;
    impl.noSip = noSip;
    impl.inviteUrl = inviteUrl;
    impl.scheduledMemberList =
        scheduledMemberList?.map((e) => e.copy()).toList();
    impl.setWaitingRoomEnabled(waitingRoomEnabled);
    impl.recurringRule = recurringRule.copy();
    impl.setEnableJoinBeforeHost(enableJoinBeforeHost);
    impl.setEnableGuestJoin(enableGuestJoin);
    impl.interpretationSettings = interpretationSettings?.copy();
    impl.timezoneId = timezoneId;
    impl.sipCid = sipCid;
    return impl;
  }

  static _MeetingItemImpl _fromNativeJson(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return _MeetingItemImpl();
    }
    var impl = _MeetingItemImpl();
    impl.subject = map['subject'] as String?;
    impl.meetingId = map['meetingId'] as int?;
    impl.startTime = (map['startTime'] ?? 0) as int;
    impl.endTime = (map['endTime'] ?? 0) as int;
    impl.noSip = (map['noSip'] ?? true) as bool;
    impl.setWaitingRoomEnabled((map['waitingRoomEnabled'] ?? false) as bool);
    impl.setEnableJoinBeforeHost((map['enableJoinBeforeHost'] ?? true) as bool);
    impl.setEnableGuestJoin((map['enableGuestJoin'] ?? false) as bool);
    impl.status = _MeetingStateExtension.fromState(map['status'] as int);
    impl.password = map['password'] as String?;
    impl.roleBinds =
        ((map['roleBinds']) as Map<String, dynamic>?)?.map((key, value) {
      var roleType = MeetingRoles.mapIntRoleToEnum(value);
      return MapEntry(key, roleType);
    });
    impl.live = NEMeetingItemLive.fromJson(map['live']);
    impl.extraData = map['extraData'] as String?;
    impl.settings = NEMeetingItemSetting.fromNativeJson(map['settings']);

    /// 云端录制配置，如果cloudRecordConfig不为空，则使用cloudRecordConfig，否则使用settings里的cloudRecordOn，兼容旧逻辑
    if (map['cloudRecordConfig'] != null) {
      impl.cloudRecordConfig =
          NECloudRecordConfig.fromJson(map['cloudRecordConfig']);
    } else {
      var cloudRecordOn = (map['settings']?['cloudRecordOn'] ?? false) as bool;
      impl.cloudRecordConfig = NECloudRecordConfig(enable: cloudRecordOn);
    }
    impl.recurringRule = NEMeetingRecurringRule.fromJson(map['recurringRule'],
        startTime: DateTime.fromMillisecondsSinceEpoch(impl.startTime));
    impl.scheduledMemberList = (map['scheduledMemberList'] as List?)
        ?.map((e) => NEScheduledMember.fromJson(e))
        .toList();
    impl.interpretationSettings =
        NEMeetingInterpretationSettings.fromJson(map['interpretation'] as Map?);
    impl.timezoneId = map['timezoneId'] as String?;
    impl.sipCid = map['sipCid'] as String?;
    impl.inviteUrl = map['inviteUrl'] as String?;
    impl.meetingType =
        MeetingTypeExtension.fromType(map['meetingType'] as int? ?? 0);
    impl.meetingNum = map['meetingNum'] as String?;
    impl.shortMeetingNum = map['shortMeetingNum'] as String?;
    return impl;
  }

  /// 解析 服务端数据
  static _MeetingItemImpl _fromJson(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return _MeetingItemImpl();
    }
    var impl = _MeetingItemImpl();
    impl.ownerUserUuid = map['ownerUserUuid'] as String?;
    impl.ownerNickname = map['ownerNickname'] as String?;
    impl.roomUuid = map['roomUuid'] as String?;
    impl.subject = map['subject'] as String?;
    impl.meetingType = MeetingTypeExtension.fromType(map['type'] as int? ?? 0);
    impl.meetingNum = map['meetingNum'] as String?;
    impl.meetingId = map['meetingId'] as int?;
    impl.shortMeetingNum = map['shortMeetingNum'] as String?;
    impl.startTime = (map['startTime'] ?? 0) as int;
    impl.endTime = (map['endTime'] ?? 0) as int;
    impl.status = _MeetingStateExtension.fromState(map['state'] as int);

    final settings = map['settings'] as Map?;
    final roomInfo = settings?['roomInfo'] as Map?;
    final roomProperties = roomInfo?['roomProperties'];
    final roomConfig = roomInfo?['roomConfig'];
    final resource = roomConfig?['resource'];
    impl.password = roomInfo?['password'] as String?;
    impl.roleBinds =
        (roomInfo?['roleBinds'] as Map<String, dynamic>?)?.map((key, value) {
      var roleType = MeetingRoles.mapStringRoleToEnum(value);
      return MapEntry(key, roleType);
    });
    impl.noSip = !((resource?['sip'] ?? false) as bool);
    impl.setWaitingRoomEnabled((roomInfo?['openWaitingRoom'] ?? false) as bool);
    impl.setEnableJoinBeforeHost(
        (roomInfo?['enableJoinBeforeHost'] ?? true) as bool);
    impl.setEnableGuestJoin(roomProperties?[GuestJoinProperty.key]?['value'] ==
        GuestJoinProperty.enable);
    Map? extraDataMap = roomProperties?['extraData'] as Map?;
    impl.extraData = extraDataMap?['value'] as String?;
    final sip = roomProperties?['sip'] as Map?;
    impl.sipCid = sip?['sipCid'] as String?;
    final securityCtrlMap =
        roomProperties?[MeetingSecurityCtrlKey.securityCtrlKey] as Map?;
    if (securityCtrlMap != null) {
      final securityCtrl = securityCtrlMap['value'] as String?;
      if (securityCtrl != null) {
        final number = int.tryParse(securityCtrl);
        if (number != null) {
          final audioControl = NEInMeetingAudioControl.fromSecurityCtrl(number);
          final videoControl = NEInMeetingVideoControl.fromSecurityCtrl(number);
          final controls = [
            if (audioControl.enabled) audioControl,
            if (videoControl.enabled) videoControl,
          ];
          impl.settings = NEMeetingItemSetting()
            ..controls = controls.isNotEmpty ? controls : null;
        }
      }
    }

    impl.cloudRecordConfig =
        NECloudRecordConfig.fromJson(settings?['recordConfig'] as Map?);
    var cloudRecordOn = (resource?['record'] ?? false) as bool;
    impl.cloudRecordConfig?.enable = cloudRecordOn;

    var liveSettings = NEMeetingItemLive();
    liveSettings.liveUrl = settings?['liveConfig']?['liveAddress'] as String?;
    liveSettings.enable = (resource?['live'] ?? false) as bool;
    Map? liveProperties = roomProperties?['live'] as Map?;
    var liveExtensionConfig = liveProperties?['extensionConfig'] as String?;
    if (liveExtensionConfig != null) {
      var map = jsonDecode(liveExtensionConfig);
      bool onlyEmployeesAllow = (map['onlyEmployeesAllow'] ?? false) as bool;
      liveSettings.liveWebAccessControlLevel = onlyEmployeesAllow
          ? NEMeetingLiveAuthLevel.appToken
          : NEMeetingLiveAuthLevel.normal;
    }
    impl.live = liveSettings;

    impl.inviteUrl = map['meetingInviteUrl'] as String?;
    impl.recurringRule = NEMeetingRecurringRule.fromJson(map['recurringRule'],
        startTime: DateTime.fromMillisecondsSinceEpoch(impl.startTime));
    impl.scheduledMemberList = (map['scheduledMemberList'] as List?)
        ?.map((e) => NEScheduledMember.fromJson(e))
        .toList();

    final interpretationProp = roomProperties?['interpretation'] as Map?;
    final interpretationJson = interpretationProp?['value'] as String?;
    if (interpretationJson != null && interpretationJson.isNotEmpty) {
      try {
        impl.interpretationSettings = NEMeetingInterpretationSettings.fromJson(
            jsonDecode(interpretationJson) as Map?);
      } catch (e) {}
    }
    impl.timezoneId = map['timezoneId'] as String?;
    return impl;
  }

  @override
  String toString() => toJson().toString();
}
