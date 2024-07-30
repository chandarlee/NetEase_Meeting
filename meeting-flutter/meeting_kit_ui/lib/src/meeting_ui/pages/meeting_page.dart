// Copyright (c) 2022 NetEase, Inc. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.
part of meeting_ui;

const _tag = 'MeetingPage';

class MeetingPage extends StatefulWidget {
  static const routeName = 'MeetingPage';
  final MeetingArguments arguments;

  MeetingPage(this.arguments) {
    assert(() {
      print('debug create');
      return true;
    }());
  }

  @override
  State<StatefulWidget> createState() {
    return MeetingBusinessUiState(arguments);
  }
}

class MeetingBusinessUiState extends LifecycleBaseState<MeetingPage>
    with
        TickerProviderStateMixin,
        EventTrackMixin,
        NEWaitingRoomListener,
        _AloggerMixin,
        MeetingKitLocalizationsMixin,
        MeetingStateScope,
        MeetingNavigatorScope
    implements
        AudioManager,
        MinimizeMeetingManager,
        MeetingMenuItemManager,
        NERoomUserVideoViewListener,
        NEMeetingMessageSessionListener {
  MeetingBusinessUiState(this.arguments);

  static const _moreMenuRouteName = '/moreMenuRoute';

  @override
  String get logTag => _tag;

  var galleryItemSize = 4;

  MeetingArguments arguments;

  int? _currentExitCode;
  String? _currentReason;

  bool _isEverConnected = false;
  late MeetingState _meetingState;

  /// 显示逻辑，有焦点显示焦点， 否则显示活跃， 否则显示host，否则显示自己, speakingUid与activeUid相同，当没有人说话时，activeUid不变，speakingUid置空
  String? focusUid, activeUid, bigUid, smallUid, speakingUid;

  Timer? joinTimeOut, _inComingTipsTimer;

  late ValueNotifier<int> _meetingMemberCount;

  ValueListenable<int> get meetingMemberCountListenable => _meetingMemberCount;

  late ChatRoomMessageSource _messageSource;

  late ValueNotifier<_NetworkStatus> _networkStats;

  ValueListenable<_NetworkStatus> get meetingNetworkStatsListenable =>
      _networkStats;

  late ValueNotifier<NetWorkRttInfo> _networkInfo;

  ValueListenable<NetWorkRttInfo> get meetingNetworkInfoListenable =>
      _networkInfo;

  late ValueNotifier<bool> _isGalleryLayout;

  ValueListenable<bool> get isGalleryLayout => _isGalleryLayout;
  late ValueNotifier<bool> _isLiveStreaming;
  ValueListenable<bool> get isLiveStreaming => _isLiveStreaming;

  late bool _isShowOpenMicroDialog,
      _isShowOpenVideoDialog,
      _isShowOpenScreenShareDialog,
      switchBigAndSmall,
      interceptEvent,
      autoSubscribeAudio,
      _invitingToOpenAudio,
      _invitingToOpenVideo;

  PageController? _galleryModePageController;
  double? pipViewAspectRatio = 9 / 16;
  Map<String, double> _userAspectRatioMap = {};
  WindowMode _windowMode = WindowMode.gallery;

  static const double appBarHeight = 64, bottomBarHeight = 54, space = 0;

  late AnimationController appBarAnimController;
  bool _appBarAnimControllerDisposed = false;

  late Animation<Offset> bottomAnim, topBarAnim, meetingEndTipAnim;

  late Animation<double> localAudioVolumeIndicatorAnim,
      cloudRecordAnim,
      incomingMessageAnim;

  late int meetingBeginTime;

  bool _isAlreadyCancel = false, _isAlreadyMeetingDisposeInMinimized = false;

  var gridLayoutMode = _GridLayoutMode.audio;

  bool get isAudioGridLayoutMode =>
      gridLayoutMode == _GridLayoutMode.audio &&
      !isWhiteBoardSharing() &&
      !isScreenSharing();

  void updateGridLayoutMode() {
    gridLayoutMode = userList.any((user) => user.isVideoOn)
        ? _GridLayoutMode.video
        : _GridLayoutMode.audio;
    if (gridLayoutMode == _GridLayoutMode.audio) {
      switchBigAndSmall = false;
      meetingUIState.lockUserVideo(null);
    }
  }

  MeetingGridLayout get currentGridLayout =>
      isAudioGridLayoutMode ? audioGridLayout : videoGridLayout;
  late final audioGridLayout = MeetingAudioGridLayout();
  late final videoGridLayout = MeetingVideoGridLayout();

  bool get _isMinimized => meetingUIState.isMinimized;

  set _isMinimized(bool value) {
    meetingUIState.isMinimized = value;
  }

  bool _isPad = false;
  final localMirrorState = ValueNotifier(true);
  final alwaysUnMirrorState = ValueNotifier(false);

  OverlayEntry? _overlayEntry;

  final _audioDeviceSelected = ValueNotifier(NEAudioOutputDevice.kSpeakerPhone);
  final _audioDeviceChanged =
      StreamController<AudioDeviceChangedEvent>.broadcast();

  Stream<AudioDeviceChangedEvent> get audioDeviceChangedStream =>
      _audioDeviceChanged.stream;
  var availableAudioDevices = <NEAudioOutputDevice>{};

  late int beautyLevel;

  int meetingEndTipMin = 0;
  late bool showMeetingEndTip;
  final _remainingSeconds = ValueNotifier(0);
  Stopwatch _remainingSecondsAdjustment = Stopwatch();
  final streamSubscriptions = <StreamSubscription>[];

  final StreamController<Object> roomInfoUpdatedEventStream =
      StreamController.broadcast();
  final StreamController<Object> moreMenuItemUpdatedEventStream =
      StreamController.broadcast();
  final StreamController<Object> webAppListUpdatedEventStream =
      StreamController.broadcast();
  late NERoomWhiteboardController whiteboardController;
  late NERoomChatController chatController;
  late NERoomRtcController rtcController;
  late NEMessageChannelCallback messageCallback;
  late NERoomEventCallback roomEventCallback;
  late NERoomRtcStatsCallback roomStatsCallback;
  ValueNotifier<BuildContext?>? raiseVideoContextNotifier = ValueNotifier(null);
  ValueNotifier<BuildContext?>? raiseAudioContextNotifier = ValueNotifier(null);

  ValueNotifier<bool> whiteBoardInteractionStatusNotifier =
      ValueNotifier<bool>(false);
  ValueNotifier<bool> whiteBoardEditingState = ValueNotifier<bool>(false);

  NEHistoryMeetingItem? historyMeetingItem;

  static const kSmallVideoViewSize = const Size(92.0, 162.0);
  static const kIPadSmallVideoViewSize = const Size(138.0, 243.0);
  final smallVideoViewPaddings = ValueNotifier(EdgeInsets.zero);
  var smallVideoViewAlignment = Alignment.topRight;

  static const int minSpeakingVolume = 20;
  static const int minMinutesToRemind = 5;
  static const int minSpeakingTimesToRemind = 10;

  /// 入会后delay一段时间后才开始静音检测，防止误报
  static const muteDetectDelay = Duration(seconds: 5);

  /// 用户主动关闭麦克风后延迟3s开始静音检测
  static const muteMyAudioDelay = Duration(seconds: 3);
  bool? muteDetectStarted;
  Timer? muteDetectStartedTimer;
  var volumeInfo = <int>[];
  var vadInfo = <bool>[];

  var focusSwitchInterval = Duration(seconds: 2);

  /// 上次焦点视频切换时间
  var lastFocusSwitchTimestamp = DateTime.utc(2020);
  final audioVolumeStreams = <String, StreamController<int>>{};
  ActiveSpeakerManager? activeSpeakerManager;
  late NERoomContext roomContext;
  late NERoomUserVideoStreamSubscriber userVideoStreamSubscriber;
  late bool isPreviewVirtualBackground;
  bool isAnonymous = false;

  final audioSharingListenable = ValueNotifier(false);
  final pageViewCurrentIndex = ValueNotifier(0);
  final pageViewScrollableListenable = ValueNotifier(true);

  final networkTaskExecutor = NetworkTaskExecutor();
  final floating = NEMeetingPlugin().getFloatingService();
  final settings = NEMeetingKit.instance.getSettingsService();

  /// iOS是否画中画模式中
  bool pictureInPictureState = false;

  /// 是否正在展示重进的dialog, 防止多次弹框
  bool isExistRejoinDialog = false;
  SDKConfig? crossAppSDKConfig;

  StreamSubscription<int>? _meetingEndTipEventSubscription;

  /// 会议时长结束提醒次数
  int _countForEndTip = 0;

  /// 一分钟提示倒计时
  Timer? _oneMinuteTimer;
  late BuildContext pipContext;
  DialogRoute? dialogRoute;
  MaterialMeetingPageRoute? meetingPageRoute;

  /// 会议已断开，是否恢复断网弹窗
  bool isShowNetworkAbnormalityAlertDialog = false;

  /// 是否已经展示过断开音频的弹窗，一次通话只展示一次
  bool hasShowAudioDisconnectTips = false;
  double currentVolume = 0.0;

  /// 进入画中画模式后，展示过的userUuid
  final Set<String> pipUsers = {};
  final Set<String> cachePIPUsers = {};

  bool userIsPIP(String userUuid) {
    return cachePIPUsers.contains(userUuid);
  }

  /// 进入画中画模式后，展示过的shareScreenUuid
  final Set<String> pipShareUsers = {};
  final Set<String> cachePIPShareUsers = {};

  bool shareUserIsPIP(String userUuid) {
    return cachePIPShareUsers.contains(userUuid);
  }

  /// 网络异常回调计数
  int _networkPoorCount = 0;

  /// 网络异常，会议重连loading展示
  final _isMeetingReconnecting = ValueNotifier(false);

  late bool modifyingAudioShareState;

  ValueNotifier<bool>? _screenShareListenable;

  ValueNotifier<bool>? _whiteBoardShareListenable;

  /// 云录制中
  ValueNotifier<bool>? _cloudRecordListenable;

  /// 云录制弹窗关闭回调，用于云录制开始和结束弹窗的关闭
  DismissCallback? _cloudRecordStartedDismissCallback;
  DismissCallback? _cloudRecordStoppedDismissCallback;

  late final isMySelfHostListenable = ValueNotifier(isHost());
  late final isMySelfManagerListenable = ValueNotifier(isSelfHostOrCoHost());

  /// 云录制左上角的提示，未开启云录制\正在开启云录制\云录制中
  ValueNotifier<_CloudRecordState>? _cloudRecordStateListenable;

  /// 音频是否断开
  ValueNotifier<bool>? _audioConnectStateListenable;

  /// 是否刚入会或重新入会
  bool _isFirstJoinOrRejoinMeeting = true;

  /// 是否需要展示云录制弹窗，小窗的时候如果有云录制弹窗设置为true，小窗回来时展示
  bool _needToShowCloudRecordChange = false;

  WaitingRoomManager? _waitingRoomManager;

  WaitingRoomManager get waitingRoomManager {
    _waitingRoomManager ??= WaitingRoomManager(roomContext,
        waitingRoomMemberJoinHandler: handleWaitingRoomMemberJoin);
    return _waitingRoomManager!;
  }

  ChatRoomManager? _chatRoomManager;

  ChatRoomManager get chatRoomManager {
    _chatRoomManager ??=
        ChatRoomManager(roomContext, waitingRoomManager: waitingRoomManager);
    return _chatRoomManager!;
  }

  /// 等候室等待Tip显示
  ValueNotifier<MeetingNotifyDialogCountTipType>
      _waitingRoomCountTipListenable =
      ValueNotifier(MeetingNotifyDialogCountTipType.hide);

  ValueNotifier<int>? _memberTotalCountNotify;

  ValueListenable<int> get memberTotalCountListenable {
    if (_memberTotalCountNotify == null) {
      _memberTotalCountNotify = ValueNotifier(0);
      _updateMemberTotalCount();
      waitingRoomManager.waitingRoomMemberCountListenable
          .addListener(_updateMemberTotalCount);
      meetingMemberCountListenable.addListener(_updateMemberTotalCount);
    }
    return _memberTotalCountNotify!;
  }

  /// 更新底部管理参会者右上角人数角标，主持人和联席主持人为会议内+等候室总人数
  void _updateMemberTotalCount() {
    var count = meetingMemberCountListenable.value;
    if (isSelfHostOrCoHost()) {
      count += waitingRoomManager.currentMemberCount;
    }
    _memberTotalCountNotify?.value = count;
  }

  ValueNotifier<List<NEMeetingCustomSessionMessage>> _allNotifyMessageList =
      ValueNotifier([]);

  ValueNotifier<MeetingNotifyDialogCountTipType> _notifyMessageTipListenable =
      ValueNotifier(MeetingNotifyDialogCountTipType.hide);
  ValueNotifier<List<NEMeetingCustomSessionMessage>>
      _unreadNotifyMessageListenable = ValueNotifier([]);

  ValueNotifier<List<NEMeetingCustomSessionMessage>>
      get unreadNotifyMessageListenable => _unreadNotifyMessageListenable;

  ValueNotifier<int> get unreadMessageCountListenable {
    return ValueNotifier<int>(_unreadNotifyMessageListenable.value.length);
  }

  ValueNotifierAdapter<int, int>? _unReadMoreMenuItemUnreadCountNotifier;

  ValueListenable<int>? get unreadMoreMenuItemTipListenable {
    _unReadMoreMenuItemUnreadCountNotifier ??= ValueNotifierAdapter<int, int>(
      source: ValueNotifier<int>(_unreadNotifyMessageListenable.value.length),
      mapper: (value) => value,
    );
    return _unReadMoreMenuItemUnreadCountNotifier;
  }

  ValueNotifier<int> getWebAppNotifyCountListenable(String sessionId) {
    return ValueNotifier<int>(unreadNotifyMessageListenable.value
        .where((value) => value.sessionId == sessionId)
        .length);
  }

  /// VideoStrategyContext 实例
  late MERoomVideoStrategyContext videoStrategyContext;

  /// 主持人成员列表
  List<String> hostVideoOrderList = [];

  @override
  void reassemble() {
    super.reassemble();
  }

  @override
  void initState() {
    super.initState();
    assert(() {
      // debugPrintScheduleBuildForStacks = true;
      debugPrintRebuildDirtyWidgets = false;
      // debugRepaintTextRainbowEnabled = debugRepaintRainbowEnabled = true;
      return true;
    }());
    NEMeetingPlugin().padCheckDetector.isPad().then((value) {
      if (_isPad != value && mounted) {
        _isPad = value;
        setState(() {});
      }
    });
    _initData(arguments.roomContext);
  }

  _initData(NERoomContext updateRoomContext) {
    /// 重新初始化会中属性
    roomContext = updateRoomContext;
    _meetingState = MeetingState.init;
    _isFirstJoinOrRejoinMeeting = true;
    _needToShowCloudRecordChange = false;
    whiteBoardInteractionStatusNotifier.value = false;
    whiteBoardEditingState.value = false;
    _isShowOpenMicroDialog = false;
    _isShowOpenScreenShareDialog = false;
    _isShowOpenVideoDialog = false;
    switchBigAndSmall = false;
    interceptEvent = false;
    autoSubscribeAudio = false;
    _invitingToOpenAudio = false;
    _invitingToOpenVideo = false;
    _audioDeviceSelected.value = NEAudioOutputDevice.kSpeakerPhone;
    beautyLevel = 0;
    showMeetingEndTip = false;
    isPreviewVirtualBackground = false;
    modifyingAudioShareState = false;
    audioSharingListenable.value = false;
    pageViewCurrentIndex.value = 0;
    crossAppSDKConfig = null;
    _screenShareListenable = null;
    _whiteBoardShareListenable = null;
    _audioConnectStateListenable = null;
    whiteboardController = roomContext.whiteboardController;
    chatController = roomContext.chatController;
    rtcController = roomContext.rtcController;
    _waitingRoomManager?.dispose();
    _waitingRoomManager = null;
    _chatRoomManager?.dispose();
    _chatRoomManager = null;
    _isMeetingReconnecting.value = false;

    /// 初始化VideoStrategyContext
    videoStrategyContext = MERoomVideoStrategyContext(roomContext);
    userVideoStreamSubscriber =
        NERoomUserVideoStreamSubscriber(videoStrategyContext);
    _meetingMemberCount = ValueNotifier(userCount);
    _memberTotalCountNotify = null;
    _networkStats = ValueNotifier(_NetworkStatus.good);
    _isGalleryLayout = ValueNotifier(false);
    _isLiveStreaming = ValueNotifier(false);
    _moreMenuItemUnreadCountNotifier = null;
    hasShowAudioDisconnectTips = false;
    NEMeetingKit.instance.addReceiveSessionMessageListener(this);
    _updateMemberTotalCount();
    roomContext.liveController.getLiveInfo().then((value) {
      if (value.isSuccess()) {
        NERoomLiveInfo? liveInfo = value.data;
        if (liveInfo != null) {
          _isLiveStreaming.value = (liveInfo.state == NERoomLiveState.started);
        }
      }
    });
    _networkInfo = ValueNotifier(NetWorkRttInfo(0, 0, 0));
    _messageSource = ChatRoomMessageSource(
        sdkConfig: sdkConfig,
        chatroomConfig:
            arguments.options.chatroomConfig ?? NEMeetingChatroomConfig());
    SystemChrome.setPreferredOrientations([]);
    meetingBeginTime = DateTime.now().millisecondsSinceEpoch;
    _galleryModePageController = PageController(initialPage: 0);
    _galleryModePageController?.addListener(_handleGalleryModePageChange);
    _initAnimationController();
    trackPeriodicEvent(TrackEventName.pageMeeting);
    isAnonymous = NEMeetingKit.instance.getAccountService().isAnonymous;
    roomEventCallback = NERoomEventCallback(
      chatroomMessagesReceived: chatroomMessagesReceived,
      chatroomMessageAttachmentProgress:
          _messageSource.updateMessageAttachmentProgress,
      memberNameChanged: memberNameChanged,
      memberRoleChanged: memberRoleChanged,
      memberJoinRtcChannel: memberJoinRtcChannel,
      memberLeaveRtcChannel: memberLeaveRtcChannel,
      memberJoinRoom: memberJoinRoom,
      memberLeaveRoom: memberLeaveRoom,
      memberVideoMuteChanged: memberVideoMuteChanged,
      memberAudioMuteChanged: memberAudioMuteChanged,
      memberWhiteboardShareStateChanged: memberWhiteboardShareStateChanged,
      memberScreenShareStateChanged: memberScreenShareStateChanged,
      roomPropertiesChanged: (map) => handleRoomPropertiesEvent(map, false),
      roomPropertiesDeleted: (map) => handleRoomPropertiesEvent(map, true),
      memberPropertiesChanged: handleMemberPropertiesEvent,
      memberPropertiesDeleted: handleMemberPropertiesEvent,
      liveStateChanged: liveStateChanged,
      rtcChannelError: onRtcChannelError,
      rtcRemoteAudioVolumeIndication: onRemoteAudioVolumeIndication,
      rtcLocalAudioVolumeIndication: onLocalAudioVolumeIndicationWithVad,
      rtcAudioOutputDeviceChanged: onRtcAudioOutputDeviceChanged,
      rtcVirtualBackgroundSourceEnabled: onRtcVirtualBackgroundSourceEnabled,
      roomRemainingSecondsRenewed: onRoomDurationRenewed,
      roomConnectStateChanged: onRoomConnectStateChanged,
      roomCloudRecordStateChanged: onRoomCloudRecordStateChanged,
      memberAudioConnectStateChanged: onMemberAudioConnectStateChanged,
      memberSipStateChanged: onMemberSipStateChanged,
      memberAppStateChanged: onMemberAppStateChanged,
    );
    roomContext.addEventCallback(roomEventCallback);

    /// 通知到iOS画中画去刷新页面
    InviteQueueUtil.instance.currentInviteData.addListener(() {
      if (InviteQueueUtil.instance.currentInviteData.value == null) {
        floating.inviteDispose();
      }
    });

    roomStatsCallback = NERoomRtcStatsCallback(
      rtcStats: handleRoomRtcStats,
      networkQuality: handleRoomNetworkQuality,
    );
    roomContext.addRtcStatsCallback(roomStatsCallback);

    messageCallback = NEMessageChannelCallback(
      onReceiveCustomMessage: handlePassThroughMessage,
    );
    NERoomKit.instance.messageChannelService
        .addMessageChannelCallback(messageCallback);

    NEMeetingPlugin().volumeController.removeListener();
    NEMeetingPlugin().volumeController.listener((volume) {
      debugPrint('volume controller: $volume');

      /// 低于阈值时提示断开音频
      if (currentVolume > 0.1 &&
          volume < 0.1 &&
          !hasShowAudioDisconnectTips &&
          roomContext.localMember.isAudioConnected) {
        showToast(NEMeetingUIKitLocalizations.of(context)!
            .meetingDisconnectAudioTips);
        hasShowAudioDisconnectTips = true;
      }
      currentVolume = volume;
    });

    MeetingCore()
        .notifyStatusChange(NEMeetingStatus(NEMeetingEvent.connecting));
    setupAudioProfile();
    setupMeetingEndTip();
    final requestPermissionElapsed = Stopwatch()..start();
    permissionCheckBeforeJoin().then((value) async {
      final elapsed = requestPermissionElapsed.elapsedMilliseconds;
      arguments.trackingEvent?.addAdjustDuration(elapsed);
      arguments.trackingEvent
          ?.addParam(kEventParamRequestPermissionElapsed, elapsed);

      /// 媒体流加密
      final encryptionConfig = arguments.encryptionConfig;
      if (encryptionConfig != null) {
        commonLogger.i('encryptionConfig: ${encryptionConfig.encryptionMode}');
        await roomContext.rtcController.enableEncryption(
            encryptionKey: encryptionConfig.encryptKey,
            encryptionMode: encryptionConfig.encryptionMode);
      }
      _setupAudioDeviceState();
      arguments.trackingEvent?.beginStep(kMeetingStepJoinRtc);
      roomContext.rtcController.joinRtcChannel().then((value) {
        if (!value.isSuccess()) {
          reportMeetingJoinResultEvent(value);
          if (mounted) {
            commonLogger.i('join channel error: ${value.code} ${value.msg}');
            roomContext.leaveRoom();
            _onCancel(exitCode: NEMeetingCode.joinChannelError);
          }
        } else {
          arguments.trackingEvent?.endStepWithResult(value);
          arguments.trackingEvent?.beginStep(kMeetingStepServerNotifyJoinRtc);
        }
      });
      _joining();
    });
    localMirrorState.value = arguments.options.enableFrontCameraMirror;
    _stopScreenShareAndWhiteboardShare();
    getPluginSmallAppList();
  }

  void getPluginSmallAppList() {
    if (arguments.options.noWebApps) return;
    roomContext.getWebAppList().then((value) {
      if (value.isSuccess()) {
        if (value.data?.pluginInfos != null) {
          webAppList = value.data!.pluginInfos!.map((e) {
            return NESingleStateMenuItem<NEMeetingWebAppItem>(
                itemId: genWebAppItemId(),
                visibility: NEMenuVisibility.visibleAlways,
                singleStateItem: NEMenuItemInfo(
                    text: e.name,
                    icon: e.icon.defaultIcon,
                    customObject: e,
                    isNetworkImage: true));
          }).toList();
        }
        if (!webAppListUpdatedEventStream.isClosed) {
          webAppListUpdatedEventStream.add(webAppList);
        }
      }
    });
  }

  bool get isAudioDeviceSwitchEnabled =>
      arguments.options.enableAudioDeviceSwitch;

  /// 初始化设备选择状态
  /// 开启音频设备切换时，Android需要关闭RTC内部的音频自动路由
  void _setupAudioDeviceState() {
    final enable = isAudioDeviceSwitchEnabled;
    if (enable) {
      if (Platform.isIOS) {
        /// iOS通过这两个参数让设备选择列表支持扬声器
        roomContext.rtcController.setParameters({
          'KNERtcKeyDisableOverrideSpeakerOnReceiver': 1,
          'kNERtcKeySupportCallkit': 1
        });
      }

      /// Android走外部的音频设备监听
      if (Platform.isAndroid) {
        NEMeetingPlugin()
            .audioService
            .audioDeviceChanged
            .listen(_onAudioDeviceChanged);
      }
      NEMeetingPlugin().audioService.getSelectedAudioDevice().then((device) {
        commonLogger.i('AudioDevice selected: $device');
        _audioDeviceSelected.value = device;
      });
    }
  }

  Object? requestToken;

  void _onAudioDeviceChanged(AudioDeviceChangedEvent event) async {
    commonLogger.i(
        '_onAudioDeviceChanged changed: ${event.$1} ${event.$2} ${event.$3}');
    if (!mounted || !isAudioDeviceSwitchEnabled) return;
    requestToken = Object();
    _audioDeviceSelected.value = event.$1;
    _audioDeviceChanged.add((event.$1, event.$2, event.$3));
    var lastAudioDevices = availableAudioDevices;
    availableAudioDevices = event.$2;

    final oldListHasBluetooth =
        lastAudioDevices.contains(NEAudioOutputDevice.kBluetoothHeadset);
    final newListHasBluetooth =
        availableAudioDevices.contains(NEAudioOutputDevice.kBluetoothHeadset);

    /// 蓝牙设备移除时，关闭设备选择弹窗
    if (!newListHasBluetooth) {
      _audioDevicePickerDismissCallback?.call();
    } else if (!oldListHasBluetooth &&
        newListHasBluetooth &&
        event.$1 != NEAudioOutputDevice.kBluetoothHeadset) {
      /// 蓝牙设备可用，但没有自动连接到蓝牙设备
      /// 此时，没有蓝牙权限。需要提示用户打开蓝牙权限
      final token = requestToken;
      commonLogger.i('request permission to connect to bluetooth headset');
      requestAndroidBluetoothPermission().then((hasPermission) {
        if (!mounted || token != requestToken || !hasPermission) return;
        commonLogger.i('restart bluetooth');
        NEMeetingPlugin().audioService.restartBluetooth();
        NEMeetingPlugin()
            .audioService
            .selectAudioDevice(NEAudioOutputDevice.kBluetoothHeadset);
      });
    }
  }

  Future<bool> requestPhoneStatePermission() async {
    if (Platform.isAndroid) {
      if (await Permission.phone.status == PermissionStatus.granted)
        return true;
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt < 31) return true;
      if (arguments.options.noReadPhoneState) return false;
      if (await _LocalSettings().shouldRequestPhoneStatePermission()) {
        _LocalSettings().updatePhoneStatePermissionTime();
        return await PermissionHelper.requestPermissionSingle(
          context,
          Permission.phone,
          arguments.meetingTitle,
          NEMeetingUIKit().ofLocalizations().meetingPhoneState,
          useDialog: true && !_isMinimized,
        );
      } else {
        return false;
      }
    }
    return Platform.isIOS;
  }

  Future<dynamic> permissionCheckBeforeJoin() async {
    requestPhoneStatePermission().then((hasPermission) {
      commonLogger.i(
        'request phone state permission: $hasPermission',
      );
      if (hasPermission) {
        handlePhoneStateChangeEvent();
      }
    });

    /// 如果关闭了设备切换，则入会时请求蓝牙权限
    if (Platform.isAndroid && !isAudioDeviceSwitchEnabled) {
      return requestAndroidBluetoothPermission(checkInterval: true);
    }
  }

  bool _isAppInBackground = false;
  bool _needAutoRestartVideo = false;

  void handleAppLifecycleChangeEvent() {
    var subscription = NEAppLifecycleDetector()
        .onBackgroundChange
        .listen((isInBackground) async {
      if (!mounted || _isAlreadyCancel) return;
      commonLogger.i(
        'Handle App lifecycle: background=$isInBackground',
      );
      _isAppInBackground = isInBackground;
      if (isInBackground) {
        // ios 从左上角下滑，会快速连续发送三次事件：background -> foreground -> background
        if (Platform.isIOS) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (!_isAppInBackground) return;
          // iOS 进入后台判断画中画是否开启
          final isActive = await floating.isActive();
          if (isActive) {
            if (!_isMinimized) _isMinimized = true;
          }
          iOSUpdatePIPVideo(bigUid ?? '');
          pictureInPictureState = await floating.isActive();
        }

        await ConnectivityManager().awaitUntilConnected();
        if (!mounted) return;
        if (!_isAppInBackground) {
          commonLogger.i(
            'Handle App lifecycle: no network when background',
          );
          return;
        }
        if (roomContext.localMember.isVideoOn) {
          final result = await rtcController.muteMyVideo();
          _needAutoRestartVideo = result.isSuccess();
          commonLogger.i(
              'Handle App lifecycle: in background and close video: $_needAutoRestartVideo $_isAppInBackground');
        }
      }
      // 异常case：关闭摄像头操作还未
      // 在完成异步关闭摄像头后，立刻检查是否需要重新打开摄像头。
      if (!_isAppInBackground && _needAutoRestartVideo) {
        _needAutoRestartVideo = false;
        final _canUnmute = roomContext.canUnmuteMyVideo();
        commonLogger.i(
            'Handle App lifecycle: in foreground and open video automatically: canUnmute=$_canUnmute, inviting=$_invitingToOpenVideo');
        if (_canUnmute || _invitingToOpenVideo) {
          _invitingToOpenVideo = false;
          final result = await rtcController.unmuteMyVideo();
          commonLogger
              .i('Handle App lifecycle: open video automatically $result');
        } else {
          commonLogger
              .i('Handle App lifecycle: in foreground but cannot open anymore');
        }
      }
      if (!_isAppInBackground) {
        /// iOS 进入前台，需要先销毁画中画, 再重新初始化
        if (Platform.isIOS) {
          iOSDisposePIP().then((value) {
            if (!mounted) return;
            SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
              if (value) {
                setState(() {
                  _isMinimized = false;
                });
              }
            });
            pictureInPictureState = false;

            if (!isSelfScreenSharing() && arguments.enablePictureInPicture) {
              iOSSetupPIP(roomContext.roomUuid);
            }
            setState(() {
              cachePIPUsers.addAll(pipUsers);
              cachePIPShareUsers.addAll(pipShareUsers);
              pipUsers.clear();
              pipShareUsers.clear();
            });
            SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
              setState(() {
                cachePIPUsers.clear();
                cachePIPShareUsers.clear();
              });
            });
          });
        }
      }
    });
    streamSubscriptions.add(subscription);
  }

  static const _updateMyPhoneState = 'UpdateMyPhoneState';

  void handlePhoneStateChangeEvent() {
    NEMeetingPlugin().phoneStateService.start();
    var subscription = NEMeetingPlugin()
        .phoneStateService
        .inCallStateChanged
        .asyncMap((event) => Future.delayed(const Duration(seconds: 1),
            () => event)) // 延迟1S排队执行，避免连续两次更新可能导致的属性错乱
        .listen((isInCall) {
      roomContext.localMember.updateMyPhoneStateLocal(isInCall);
      networkTaskExecutor
          .execute(
        () => roomContext.updateMyPhoneState(isInCall),
        type: _updateMyPhoneState,
        debugName: '$_updateMyPhoneState($isInCall)',
        cancelOthers: true,
      )
          .catchError((err) {
        debugPrint('$_updateMyPhoneState($isInCall) $err');
        return null;
      });
      if (isInCall) {
        if (isSelfScreenSharing()) rtcController.stopScreenShare();
        if (audioSharingListenable.value) enableAudioShare(false);
        // 通话中，中断音频，停止摄像头采集
        roomContext.rtcController
          ..adjustPlaybackSignalVolume(0)
          ..adjustRecordingSignalVolume(0)
          ..pauseLocalVideoCapture();
      } else {
        // 通话结束，恢复音频，恢复摄像头采集
        roomContext.rtcController
          ..adjustPlaybackSignalVolume(100)
          ..adjustRecordingSignalVolume(100)
          ..resumeLocalVideoCapture();
      }
    });
    streamSubscriptions.add(subscription);
  }

  /// [manual]: 手动请求还是自动请求；
  /// 如果是手动请求，则不校验上次请求时间；用于用户手动切换蓝牙设备；
  /// 如果是自动请求，需要连续两次请求权限的时间间隔满足条件；
  /// [checkInterval] 是否检查时间间隔
  Future<bool> requestAndroidBluetoothPermission(
      {bool checkInterval = false}) async {
    if ((await DeviceInfoPlugin().androidInfo).version.sdkInt < 31) return true;
    if (await Permission.bluetoothConnect.status == PermissionStatus.granted)
      return true;
    if (checkInterval &&
        !await _LocalSettings().shouldRequestBluetoothConnectPermission())
      return false;
    _LocalSettings().updateBluetoothConnectPermissionTime();
    return PermissionHelper.requestPermissionSingle(
      context,
      Permission.bluetoothConnect,
      arguments.meetingTitle,
      NEMeetingUIKitLocalizations.of(context)!.meetingBluetooth,
      message: NEMeetingUIKitLocalizations.of(context)!
          .meetingNeedRationaleAudioPermission(
              NEMeetingUIKitLocalizations.of(context)!.meetingBluetooth),
      useDialog: true && !_isMinimized,
    ).then((value) {
      commonLogger.i(
        'request bluetooth connect permission granted=$value',
      );
      return value;
    });
  }

  StreamSubscription? _roomEndStreamSubscription;
  StreamSubscription? _waitingRoomStatusSubscription;

  void _listenStreams() {
    _roomEndStreamSubscription ??=
        meetingLifecycleState.roomEndStream.listen(onRoomDisconnected);
    _waitingRoomStatusSubscription ??= meetingLifecycleState
        .onPuttedInWaitingRoom
        .listen((_) => navigateToWaitingRoom());
  }

  void _unlistenStreams() {
    _roomEndStreamSubscription?.cancel();
    _roomEndStreamSubscription = null;
    _waitingRoomStatusSubscription?.cancel();
    _waitingRoomStatusSubscription = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    commonLogger.i('didChangeDependencies');
    refreshSmallVideoViewPaddings();
    _listenStreams();
    updateGridLayoutParams();
    final orientation = MediaQuery.maybeOrientationOf(context);
    if (orientation != _screenOrientation) {
      _screenOrientation = orientation;
      _screenShareController.value = Matrix4.identity();
    }
  }

  void refreshSmallVideoViewPaddings() {
    final safeArea = MediaQuery.of(context).viewPadding;
    var paddings = EdgeInsets.fromLTRB(max(safeArea.left, 12.0),
        safeArea.top + 20, max(safeArea.right, 12.0), safeArea.bottom + 20);
    if (isToolbarShowing) {
      paddings +=
          const EdgeInsets.fromLTRB(0, appBarHeight, 0, bottomBarHeight);
    }
    smallVideoViewPaddings.value = paddings;
  }

  @override
  void onAppLifecycleState(AppLifecycleState state) {
    if (!Platform.isIOS && mounted) {
      _checkResumeFromMinimized(state);
    }
  }

  Future<void> _checkResumeFromMinimized(AppLifecycleState state) async {
    commonLogger.i('resume from minimized state :${state.name}');
    PiPStatus pipStatus = await updatePIPAspectRatio(canPopToMeetingPage: true);
    if (!mounted) return;
    if (arguments.backgroundWidget != null) {
      if (_isMinimized == (pipStatus == PiPStatus.enabled)) return;
      SchedulerBinding.instance.scheduleFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _isMinimized = false;
        });
      });

      if (state == AppLifecycleState.resumed) {
        MeetingCore()
            .notifyStatusChange(NEMeetingStatus(NEMeetingEvent.inMeeting));
        commonLogger.i('resume from minimized');
      }
    } else {
      if (!_isAlreadyCancel &&
          state == AppLifecycleState.resumed &&
          _isMinimized &&
          pipStatus != PiPStatus.enabled) {
        setState(() {
          _isMinimized = false;
        });
        MeetingCore()
            .notifyStatusChange(NEMeetingStatus(NEMeetingEvent.inMeeting));
      }
    }
  }

  void _initAnimationController() {
    appBarAnimController = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    bottomAnim = Tween(begin: Offset(0, 0), end: Offset(0, 1)).animate(
        CurvedAnimation(parent: appBarAnimController, curve: Curves.easeOut));
    topBarAnim = Tween(begin: Offset(0, 0), end: Offset(0, -1)).animate(
        CurvedAnimation(parent: appBarAnimController, curve: Curves.easeOut));
    cloudRecordAnim = Tween(begin: appBarHeight, end: 0.0).animate(
        CurvedAnimation(parent: appBarAnimController, curve: Curves.easeOut));
    incomingMessageAnim = Tween(begin: bottomBarHeight, end: 0.0).animate(
        CurvedAnimation(parent: appBarAnimController, curve: Curves.easeOut));
    localAudioVolumeIndicatorAnim =
        Tween(begin: -50.0, end: bottomBarHeight + 30.0).animate(
            CurvedAnimation(
                parent: appBarAnimController, curve: Curves.easeOut));
    meetingEndTipAnim = Tween(begin: Offset(0, 0), end: Offset(0, 0)).animate(
        CurvedAnimation(parent: appBarAnimController, curve: Curves.easeOut));
    appBarAnimController.addStatusListener((status) {
      refreshSmallVideoViewPaddings();
    });
  }

  void _joining() {
    if (_meetingState == MeetingState.init) {
      _meetingState = MeetingState.joining;
      final joinTimeoutTips =
          NEMeetingUIKitLocalizations.of(context)?.meetingJoinTimeout;
      joinTimeOut = Timer(Duration(milliseconds: arguments.joinTimeout), () {
        if (_meetingState.index <= MeetingState.joining.index) {
          commonLogger.i(
            'join meeting timeout',
          );
          reportMeetingJoinResultEvent();
          _meetingState = MeetingState.closing;
          roomContext.leaveRoom();
          _onCancel(
              exitCode: NEMeetingCode.joinTimeout, reason: joinTimeoutTips);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isMinimized) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    } else {
      SystemChrome.setPreferredOrientations([]);

      /// 离开会议默认退出，当会议被踢出时，不退出，进行弹窗
      checkMeetingEnd(false);
    }

    /// 入会或重新入会以及小窗模式回来，判断是否需要展示云录制弹窗
    determineToShowMeetingCloudRecordDialog();

    /// 获取水印信息并更新UI
    _updateWatermarkInfo();

    Widget? buildWidget;
    if (Platform.isAndroid) {
      if (SchedulerBinding.instance.lifecycleState ==
              AppLifecycleState.resumed &&
          arguments.backgroundWidget != null &&
          _isMinimized) {
        buildWidget = buildPIPView();
      }
    } else if (Platform.isIOS) {
      if (arguments.backgroundWidget != null && _isMinimized) {
        buildWidget = buildPIPView();
      }
    }
    return buildWidget ??
        AnnotatedRegion<SystemUiOverlayStyle>(
          value: AppStyle.systemUiOverlayStyleLight,
          child: _isMinimized
              ? InComingInvite(
                  child: buildChild(context), isInMinimizedMode: true)
              : buildChild(context),
        );
  }

  /// 画中画模式下，目前不支持自动恢复到全屏，因此展示相应提示
  /// 用户点击后，退出画中画模式，并提示
  Widget buildMeetingWasInterrupted() {
    return Container(
      color: _UIColors.grey_292933,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: FittedBox(
            child: Text(
              NEMeetingUIKitLocalizations.of(context)!.meetingWasInterrupted,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildChild(BuildContext context) {
    pipContext = context;
    if (_meetingState.index < MeetingState.joined.index || !_isEverConnected) {
      return buildJoiningUI();
    }
    final data = MediaQuery.of(context);
    final height = appBarHeight + data.viewPadding.top;
    return PopScope(
      canPop: false,
      child: OrientationBuilder(builder: (_, orientation) {
        return Stack(
          children: <Widget>[
            GestureDetector(
              key: MeetingUIValueKeys.meetingFullScreen,
              onTap: changeToolBarStatus,
              // 快速回到画廊模式首页
              onLongPress: () {
                final controller = _galleryModePageController;
                if (controller != null &&
                    controller.hasClients &&
                    controller.page! > 4) {
                  controller.jumpToPage(0);
                }
              },
              child: buildCenter(),
            ),
            // MeetingCoreValueKey.addTextWidgetTest(valueKey:MeetingCoreValueKey.meetingFullScreen,value: handlMeetingFullScreen),
            Visibility(
                visible: !_isMinimized,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: RepaintBoundary(
                    child: SlideTransition(
                      child: buildBottomAppBar(),
                      position: bottomAnim,
                    ),
                  ),
                )),
            if (isMeetingEndTimeTiSupported() &&
                showMeetingEndTip &&
                meetingEndTipMin != 0 &&
                !_isMinimized)
              buildMeetingEndTip(height),
            Visibility(
                visible: !_isMinimized,
                child: RepaintBoundary(
                  child: SlideTransition(
                      position: topBarAnim, child: buildAppBar(data, height)),
                )),
            Visibility(
                visible: !_isMinimized,
                child: AnimatedBuilder(
                  animation: cloudRecordAnim,
                  builder: (context, child) => Positioned(
                      top: cloudRecordAnim.value + data.viewPadding.top,
                      left: 0,
                      child: ValueListenableBuilder<_CloudRecordState>(
                        valueListenable: cloudRecordStateListenable,
                        builder: (context, value, child) {
                          return Visibility(
                              visible: value != _CloudRecordState.notStarted &&
                                  arguments.options.showCloudRecordingUI,
                              child: buildCloudRecordState(value));
                        },
                      )),
                )),
          ],
        );
      }),
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (closeCloudRecordingStartedDialog() ||
            closeCloudRecordingStoppedDialog()) {
          return;
        }
        finishPage();
      },
    );
  }

  Widget buildCenter() {
    return Stack(
      children: <Widget>[
        NERoomUserVideoStreamSubscriberProvider(
          subscriber: userVideoStreamSubscriber,
          child: ValueListenableBuilder<bool>(
            valueListenable: whiteBoardEditingState,
            builder: (context, value, child) => buildGalleyUI(),
          ),
        ),
        ValueListenableBuilder<bool>(
            valueListenable: _isMeetingReconnecting,
            builder: (context, value, child) {
              return Visibility(
                  visible: value && !_isMinimized,
                  child: Center(
                      child: Container(
                    decoration: BoxDecoration(
                        color: _UIColors.white,
                        borderRadius: BorderRadius.all(Radius.circular(4))),
                    padding: EdgeInsets.all(24),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Flexible(
                            child: Text(
                                NEMeetingUIKitLocalizations.of(context)!
                                    .networkDisconnectedTryingToReconnect,
                                softWrap: true,
                                style: TextStyle(
                                    fontSize: 16,
                                    decoration: TextDecoration.none,
                                    fontWeight: FontWeight.w400,
                                    color: _UIColors.color_337eff)))
                      ],
                    ),
                  )));
            }),
      ],
    );
  }

  bool isHeadset() {
    return _audioDeviceSelected.value ==
            NEAudioOutputDevice.kBluetoothHeadset ||
        _audioDeviceSelected.value == NEAudioOutputDevice.kWiredHeadset;
  }

  bool isEarpiece() {
    return _audioDeviceSelected.value == NEAudioOutputDevice.kEarpiece;
  }

  Widget buildCloudRecordState(_CloudRecordState state) {
    final text = state == _CloudRecordState.starting
        ? NEMeetingUIKitLocalizations.of(context)!.cloudRecordingStarting
        : NEMeetingUIKitLocalizations.of(context)!.cloudRecording;
    return GestureDetector(
      onTap: () {
        if (isSelfHostOrCoHost() && state == _CloudRecordState.started) {
          stopCloudRecord();
        }
      },
      child: Container(
          height: 32,
          padding: EdgeInsets.symmetric(horizontal: 12),
          margin: EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _UIColors.color2A2A31,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: _UIColors.black.withOpacity(0.25),
                offset: Offset(0, 4),
                blurRadius: 6,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                NEMeetingIconFont.icon_cloud_recording,
                color: _UIColors.colorFF4D4F,
                size: 14,
              ),
              SizedBox(width: 4),
              Text(
                text,
                style: TextStyle(
                    decoration: TextDecoration.none,
                    fontSize: 14,
                    color: state == _CloudRecordState.starting
                        ? _UIColors.white.withOpacity(0.6)
                        : _UIColors.white,
                    fontWeight: FontWeight.w400),
              ),
            ],
          )),
    );
  }

  Widget buildAppBar(data, height) {
    return Container(
      height: height,
      padding:
          EdgeInsets.only(left: 8.0, right: 8.0, top: data.viewPadding.top),
      child: SafeArea(
          top: false,
          bottom: false,
          child: Stack(
            children: [
              buildMeetingInfo(),
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isSelfScreenSharing()) buildMinimize(),
                    buildSwitchAudioMode(),
                    buildCameraMode(),
                    buildSwitchMode()
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    buildNetwork(),
                    buildLeave(),
                  ],
                ),
              ),
            ],
          )),
      decoration: BoxDecoration(
          gradient: LinearGradient(
        colors: [_UIColors.color_292933, _UIColors.color_212129],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      )),
    );
  }

  Widget buildNetwork() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onNetworkInfo,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: _meetingNetworkIconBuilder(context),
      ),
    );
  }

  void _handleGalleryModePageChange() {
    if (_galleryModePageController != null) {
      _isGalleryLayout.value = _galleryModePageController!.page! >= 1.0;
    }
  }

  Widget buildSwitchMode() =>
      _isPad && userCount > 1 ? buildSwitchLayoutBtn() : SizedBox();

  String getGalleryLayoutDes(bool isGallery) {
    return isGallery
        ? NEMeetingUIKitLocalizations.of(context)!.meetingSwitchFcusView
        : NEMeetingUIKitLocalizations.of(context)!.meetingSwitchGalleryView;
  }

  Widget buildSwitchLayoutBtn() {
    return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _galleryModePageController
              ?.jumpToPage(!isGalleryLayout.value ? 1 : 0);
        },
        child: SafeValueListenableBuilder(
          valueListenable: isGalleryLayout,
          builder: (BuildContext context, bool value, _) {
            return Container(
              margin: EdgeInsets.symmetric(horizontal: 8),
              width: 160,
              height: 38,
              decoration: BoxDecoration(
                  color: _UIColors.color_337eff,
                  borderRadius: BorderRadius.circular(19)),
              child: Align(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      value
                          ? NEMeetingIconFont.icon_yx_tv_layout_ax
                          : NEMeetingIconFont.icon_yx_tv_layout_bx,
                      size: 21,
                      color: _UIColors.white,
                    ),
                    SizedBox(width: 6),
                    Text(
                      getGalleryLayoutDes(value),
                      style: TextStyle(
                          decoration: TextDecoration.none,
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w400),
                    )
                  ],
                ),
              ),
            );
          },
        ));
  }

  Widget _meetingNetworkIconBuilder(BuildContext context) {
    return SafeValueListenableBuilder(
        valueListenable: meetingNetworkStatsListenable,
        builder: (BuildContext context, _NetworkStatus value, _) {
          return getNetWorkIcon(value);
        });
  }

  Widget getNetWorkIcon(_NetworkStatus status) {
    if (status == _NetworkStatus.good || status == _NetworkStatus.unknown) {
      return Icon(NEMeetingIconFont.icon_net_state,
          key: MeetingUIValueKeys.minimize, size: 21, color: Colors.green);
    } else if (status == _NetworkStatus.normal) {
      return Icon(NEMeetingIconFont.icon_net_state,
          key: MeetingUIValueKeys.minimize, size: 21, color: Colors.yellow);
    } else {
      return Icon(NEMeetingIconFont.icon_net_state,
          key: MeetingUIValueKeys.minimize, size: 21, color: Colors.red);
    }
  }

  Widget buildLeave() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: Container(
          margin: EdgeInsets.symmetric(horizontal: 8),
          width: 50,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: _UIColors.colorD93D35,
              borderRadius: BorderRadius.all(Radius.circular(13))),
          child: Text(
              isSelfHostOrCoHost()
                  ? NEMeetingUIKitLocalizations.of(context)!.meetingFinish
                  : NEMeetingUIKitLocalizations.of(context)!.meetingLeave,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: _UIColors.white,
                  fontSize: 13,
                  decoration: TextDecoration.none,
                  fontWeight: FontWeight.w400))),
      onTap: finishPage,
    );
  }

  Widget buildMeetingInfo() {
    final appbarItemSize = 21 + 16;
    final marginLeft = [
      !arguments.noSwitchAudioMode,
      !arguments.noSwitchCamera && !arguments.videoMute,
      true /*network always shown*/
    ].fold<double>(
        0,
        (previousValue, show) =>
            show ? appbarItemSize + previousValue : previousValue);

    var marginRight = 50.0 + 16.0;
    if (!arguments.noMinimize) {
      marginRight += appbarItemSize;
    }
    return SizedBox.expand(
      child: Container(
        // color: Colors.red,
        margin: EdgeInsets.symmetric(horizontal: max(marginLeft, marginRight)),
        child: GestureDetector(
          key: MeetingUIValueKeys.showMeetingInfo,
          behavior: HitTestBehavior.opaque,
          onTap: _onMeetingInfo,
          child: Stack(
            children: [
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        ' ${arguments.meetingTitle} ',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          decoration: TextDecoration.none,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white,
                      size: 15,
                    ),
                  ],
                ),
              ),
              Positioned(
                  bottom: 2,
                  left: 0,
                  right: 0,
                  child: ValueListenableBuilder<bool>(
                      valueListenable: isLiveStreaming,
                      builder: (context, show, _) {
                        return (show || arguments.showMeetingTime)
                            ? Container(
                                height: 17,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    if (arguments.showMeetingTime)
                                      MeetingDuration(
                                        DateTime.now().millisecondsSinceEpoch -
                                            roomContext.rtcStartTime,
                                      ),
                                    if (show && arguments.showMeetingTime)
                                      SizedBox(width: 12),
                                    if (show)
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                                color: _UIColors.colorD93D35,
                                                borderRadius: BorderRadius.all(
                                                    Radius.circular(3))),
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            NEMeetingUIKitLocalizations.of(
                                                    context)!
                                                .liveStreaming,
                                            style: TextStyle(
                                                color: _UIColors.colorD93D35,
                                                fontSize: 10,
                                                decoration: TextDecoration.none,
                                                fontWeight: FontWeight.w400),
                                            textAlign: TextAlign.center,
                                          )
                                        ],
                                      )
                                  ],
                                ))
                            : Container();
                      }))
            ],
          ),
        ),
      ),
    );
  }

  void _onMeetingInfo() async {
    trackPeriodicEvent(TrackEventName.meetingInfoClick,
        extra: {'meeting_num': arguments.meetingNum});
    if (!_isMinimized) {
      await DialogUtils.showChildNavigatorPopup(
        context,
        (context) => MeetingInfoPage(
          roomContext,
          arguments.meetingInfo,
          arguments.options,
          roomInfoUpdatedEventStream.stream,
        ),
        routeSettings: RouteSettings(name: 'MeetingInfo'),
      );
    }
  }

  Widget buildMinimize() {
    if (!arguments.noMinimize) {
      return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: minimizeCurrentMeeting,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: const Icon(NEMeetingIconFont.icon_narrow_line,
                key: MeetingUIValueKeys.minimize,
                size: 21,
                color: _UIColors.white),
          ));
    } else {
      return SizedBox.shrink();
    }
  }

  Widget buildCameraMode() {
    if (arguments.videoMute == true || arguments.noSwitchCamera) {
      return SizedBox.shrink();
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: const Icon(
          NEMeetingIconFont.icon_yx_tv_filpx,
          key: MeetingUIValueKeys.switchCamera,
          size: 21,
          color: _UIColors.white,
        ),
      ),
      onTap: _onSwitchCamera,
    );
  }

  Widget buildSwitchAudioMode() {
    if (arguments.noSwitchAudioMode ||
        !roomContext.localMember.isAudioConnected) {
      return const SizedBox.shrink();
    }
    return GestureDetector(
      key: MeetingUIValueKeys.switchAudioDevice,
      behavior: HitTestBehavior.opaque,
      onTap: _audioModeSwitch,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: ValueListenableBuilder<NEAudioOutputDevice>(
          valueListenable: _audioDeviceSelected,
          builder: (context, value, child) {
            return _buildAudioDeviceIcon(
              device: value,
              size: 21,
              color: _UIColors.white,
            );
          },
        ),
      ),
    );
  }

  DismissCallback? _audioDevicePickerDismissCallback;

  void showAudioDevicePicker(Set<NEAudioOutputDevice> devices) {
    if (Platform.isAndroid) {
      _audioDevicePickerDismissCallback?.call();
      _audioDevicePickerDismissCallback = BottomSheetUtils.showModalBottomSheet(
          context: context,
          routeSettings: RouteSettings(name: 'AudioDevicePicker'),
          backgroundColor: Colors.transparent,
          builder: (context) {
            return SafeArea(
                child: SingleChildScrollView(
                    child: StreamBuilder<AudioDeviceChangedEvent>(
                        initialData: (
                  _audioDeviceSelected.value,
                  devices,
                  true
                ),
                        stream: audioDeviceChangedStream,
                        builder: (context, snapshot) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildBottomSheetTitle(
                                  NEMeetingUIKitLocalizations.of(context)!
                                      .deviceOutput),
                              if (snapshot.data != null)
                                for (var e in snapshot.data!.$2) ...[
                                  Container(
                                      height: 1, color: _UIColors.globalBg),
                                  _buildAudioDeviceItem(
                                      e, e == snapshot.data!.$1),
                                ]
                            ],
                          );
                        })));
          });
    } else if (Platform.isIOS) {
      NEMeetingPlugin().audioService.showAudioDevicePicker();
    }
  }

  Widget _buildAudioDeviceItem(NEAudioOutputDevice device, bool isSelected) {
    final color = isSelected ? _UIColors.color_337eff : _UIColors.color_333333;
    return GestureDetector(
      onTap: () async {
        commonLogger.i('selectAudioDevice: $device');
        if (device == NEAudioOutputDevice.kBluetoothHeadset) {
          bool hasPermission = await requestAndroidBluetoothPermission();
          if (!mounted) return;
          if (!hasPermission) {
            showToast(
              NEMeetingUIKitLocalizations.of(context)!.globalNoPermission,
            );
            return;
          }
          NEMeetingPlugin().audioService.restartBluetooth();
        }
        _audioDevicePickerDismissCallback?.call();
        NEMeetingPlugin().audioService.selectAudioDevice(device);
      },
      child: Container(
        height: 48,
        color: _UIColors.white,
        padding: EdgeInsets.only(top: 12, bottom: 12, left: 20, right: 16),
        child: Row(
          children: [
            _buildAudioDeviceIcon(device: device, size: 24, color: color),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                _getAudioDeviceTitle(device),
                style: TextStyle(
                  fontSize: 16,
                  decoration: TextDecoration.none,
                  fontWeight: FontWeight.w400,
                  color: color,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                NEMeetingIconFont.icon_check_line,
                size: 24,
                color: color,
              )
          ],
        ),
      ),
    );
  }

  Widget _buildAudioDeviceIcon(
      {required NEAudioOutputDevice device,
      Key? key,
      double? size,
      Color? color}) {
    IconData? data;
    switch (device) {
      case NEAudioOutputDevice.kBluetoothHeadset:
        data = NEMeetingIconFont.icon_bluetooth;
        break;
      case NEAudioOutputDevice.kWiredHeadset:
        data = NEMeetingIconFont.icon_headset1x;
        break;
      case NEAudioOutputDevice.kEarpiece:
        data = NEMeetingIconFont.icon_earpiece1x;
        break;
      case NEAudioOutputDevice.kSpeakerPhone:
        data = NEMeetingIconFont.icon_amplify;
        break;
    }
    return Icon(
      data,
      key: key,
      size: size,
      color: color,
    );
  }

  String _getAudioDeviceTitle(NEAudioOutputDevice device) {
    switch (device) {
      case NEAudioOutputDevice.kBluetoothHeadset:
        return NEMeetingUIKitLocalizations.of(context)!.meetingBluetooth;
      case NEAudioOutputDevice.kWiredHeadset:
        return NEMeetingUIKitLocalizations.of(context)!.deviceHeadphones;
      case NEAudioOutputDevice.kEarpiece:
        return NEMeetingUIKitLocalizations.of(context)!.deviceReceiver;
      case NEAudioOutputDevice.kSpeakerPhone:
        return NEMeetingUIKitLocalizations.of(context)!.deviceSpeaker;
    }
  }

  Widget _buildBottomSheetTitle(String title) {
    final radius = Radius.circular(8);
    return Container(
      height: 48,
      decoration: BoxDecoration(
          color: _UIColors.white,
          borderRadius: BorderRadius.only(topLeft: radius, topRight: radius)),
      child: Stack(
        children: <Widget>[
          Center(
            child: Text(
              title,
              style: TextStyle(
                  color: _UIColors.black_333333,
                  fontWeight: FontWeight.w500,
                  fontSize: 16.0,
                  decoration: TextDecoration.none),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: GestureDetector(
                  child: Icon(
                    NEMeetingIconFont.icon_yx_tv_duankaix,
                    color: _UIColors.color_666666,
                    size: 14,
                    key: MeetingUIValueKeys.close,
                  ),
                  onTap: () => _audioDevicePickerDismissCallback?.call(),
                )),
          )
        ],
      ),
    );
  }

  void _audioModeSwitch() async {
    if (isAudioDeviceSwitchEnabled) {
      final devices = await NEMeetingPlugin().audioService.enumAudioDevices();
      if (!mounted) return;
      if (devices.contains(NEAudioOutputDevice.kBluetoothHeadset)) {
        showAudioDevicePicker(devices);
        return;
      }
    }
    if (isHeadset()) {
      showToast(NEMeetingUIKitLocalizations.of(context)!.deviceHeadsetState);
    } else if (_isPad) {
      showToast(
          NEMeetingUIKitLocalizations.of(context)!.meetingNoSupportSwitch);
    } else {
      _onSwitchLoudspeaker();
    }
  }

  bool _willToolbarMenuShow() {
    return arguments.injectedToolbarMenuItems
            .where(shouldShowMenu)
            .isNotEmpty ||
        _willMoreMenuShow();
  }

  Widget buildBottomAppBar() {
    if (!_willToolbarMenuShow()) {
      return SizedBox.shrink();
    }
    EdgeInsets padding = MediaQuery.viewPaddingOf(context);

    return SizedBox(
        height: 106 + padding.bottom,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              height: 46,
              margin: EdgeInsets.only(bottom: 6),
              padding:
                  EdgeInsets.only(left: padding.left, right: padding.right),
              child: Row(
                children: [
                  ...arguments.injectedToolbarMenuItems
                      .where(shouldShowMenu)
                      .map((menu) {
                    if (menu.itemId == NEMenuIDs.disconnectAudio) {
                      return SizedBox.shrink();
                    }
                    if (menu.itemId == NEMenuIDs.participants &&
                        roomContext.localMember.isRaisingHand) {
                      return Expanded(
                        child: buildHandsUp(
                          NEMeetingUIKitLocalizations.of(context)!
                              .meetingInHandsUp,
                          () => _lowerMyHand(),
                        ),
                      );
                    }
                    if (menu.itemId == NEMenuIDs.managerParticipants &&
                        hasHandsUp() &&
                        isSelfHostOrCoHost()) {
                      return Expanded(
                        child:
                            buildHandsUp(handsUpCount().toString(), _onMember),
                      );
                    }
                    return Spacer();
                  }).toList(growable: false),
                  if (_willMoreMenuShow()) Spacer()
                ],
              ),
            ),
            Expanded(
                child: Container(
              padding: EdgeInsets.only(
                  bottom: padding.bottom,
                  left: padding.left,
                  right: padding.right),
              child: Row(
                children: <Widget>[
                  ...arguments.injectedToolbarMenuItems
                      .where(shouldShowMenu)
                      .map(menuItem2Widget)
                      .whereType<Widget>()
                      .map((widget) => Expanded(child: widget))
                      .toList(growable: false),
                  if (_willMoreMenuShow())
                    Expanded(
                      child: SingleStateMenuItem(
                          isMoreMenuItem: false,
                          menuItem: InternalMenuItems.more,
                          callback: handleMenuItemClick,
                          tipBuilder:
                              getMenuItemTipBuilder(InternalMenuIDs.more)),
                    ),
                ],
              ),
              decoration: BoxDecoration(
                  border: Border(
                      top: BorderSide(
                          color: _UIColors.color_33FFFFFF, width: 0.5)),
                  gradient: LinearGradient(
                      colors: [_UIColors.color_292933, _UIColors.color_212129],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter)),
            ))
          ],
        ));
  }

  bool shouldShowMenu(NEMeetingMenuItem item, {bool isMoreMenuItem = false}) {
    if (!roomContext.localMember.isVisible) return false;
    final id = item.itemId;
    if (!item.isValid) return false;

    /// 根据自己的isAudioConnected选择展示连接音频按钮或者静音按钮
    if (item.itemId == NEMenuIDs.disconnectAudio &&
        !isMoreMenuItem &&
        roomContext.localMember.isAudioConnected) return false;
    if (item.itemId == NEMenuIDs.microphone &&
        !roomContext.localMember.isAudioConnected) return false;

    if (id == NEMenuIDs.screenShare && !_isScreenShareSupported()) return false;
    if (id == NEMenuIDs.chatroom && (arguments.noChat || !isChatroomEnabled()))
      return false;
    if (id == NEMenuIDs.invitation && arguments.noInvite) return false;
    if (id == InternalMenuIDs.beauty && !isBeautyFuncSupported) {
      return false;
    }
    if (id == InternalMenuIDs.virtualBackground &&
        !isVirtualBackgroundEnabled) {
      return false;
    }
    if (id == NEMenuIDs.sipCall && !roomContext.sipController.isSupported)
      return false;
    if (id == InternalMenuIDs.live &&
        (arguments.noLive || !roomContext.liveController.isSupported)) {
      return false;
    }

    if (id == InternalMenuIDs.sip && (arguments.noSip || !isSipSupported())) {
      return false;
    }
    if (id == NEMenuIDs.whiteBoard &&
        (arguments.noWhiteBoard || !whiteboardController.isSupported)) {
      return false;
    }
    if (id == NEMenuIDs.cloudRecord &&
        (!arguments.options.showCloudRecordMenuItem ||
            !sdkConfig.isCloudRecordSupported)) {
      return false;
    }
    if (id == NEMenuIDs.notifyCenter && arguments.options.noNotifyCenter)
      return false;
    switch (item.visibility) {
      case NEMenuVisibility.visibleToHostOnly:
        return isSelfHostOrCoHost();
      case NEMenuVisibility.visibleExcludeHost:
        return !isSelfHostOrCoHost();
      case NEMenuVisibility.visibleAlways:
        return true;
    }
  }

  /// 新增聊天室是否可用，对应原chatController内的isChatroomEnabled() 方法
  bool isChatroomEnabled() {
    return meetingUIState.inMeetingChatroom.hasJoin ||
        meetingUIState.waitingRoomChatroom.hasJoin;
  }

  bool isSipSupported() =>
      sdkConfig.isSipSupported && !TextUtils.isEmpty(roomContext.sipCid);

  final Map<int, NEMeetingMenuItem> menuId2Item = {};
  final Map<int, CyclicStateListController> menuId2Controller = {};

  Widget? menuItem2Widget(NEMeetingMenuItem item,
      {bool isMoreMenuItem = false}) {
    menuId2Item.putIfAbsent(item.itemId, () => item);
    final tipBuilder = getMenuItemTipBuilder(item.itemId);
    final iconBuilder = getMenuItemIconBuilder(item.itemId);
    if (item is NESingleStateMenuItem) {
      return SingleStateMenuItem(
        menuItem: item,
        callback: handleMenuItemClick,
        tipBuilder: tipBuilder,
        iconBuilder: iconBuilder,
        isMoreMenuItem: isMoreMenuItem,
      );
    } else if (item is NECheckableMenuItem) {
      final controller = menuId2Controller.putIfAbsent(item.itemId,
          () => getMenuItemStateController(item.itemId, item.checked));
      return CheckableMenuItem(
        menuItem: item,
        controller: controller,
        callback: handleMenuItemClick,
        tipBuilder: tipBuilder,
        iconBuilder: iconBuilder,
        isMoreMenuItem: isMoreMenuItem,
      );
    }
    return null;
  }

  void updateMenuItemState(NEMeetingMenuItem item) {
    if (item is NECheckableMenuItem) {
      menuId2Controller[item.itemId]?.moveStateTo(
          item.checked ? NEMenuItemState.checked : NEMenuItemState.uncheck);
      commonLogger.i(
          'updateMenuItemState ${item.itemId} ${menuId2Controller[item.itemId]?.value}');
    }
  }

  MenuItemTipBuilder? getMenuItemTipBuilder(int menuId) {
    switch (menuId) {
      case NEMenuIDs.participants:
      case NEMenuIDs.managerParticipants:
        return _meetingMemberCountBuilder;
      case NEMenuIDs.chatroom:
        return _circularNumberTipBuilder(
            _messageSource.unreadMessageListenable);
      case InternalMenuIDs.more:

        /// Only show unread tip when chat menu is in 'more' menu
        if (arguments.injectedMoreMenuItems.where(shouldShowMenu).any(
            (element) =>
                element.itemId == NEMenuIDs.chatroom ||
                element.itemId == NEMenuIDs.notifyCenter ||
                _isWebApp(element.itemId))) {
          return _circularNumberTipBuilder(moreMenuItemTipListenable,
              unreadMessageCountListenable: unreadMoreMenuItemTipListenable,
              tipUnreadCount: false);
        }
      case NEMenuIDs.notifyCenter:
        return _circularNumberTipBuilder(unreadMessageCountListenable);
    }
    if (_isWebApp(menuId)) {
      final item = getWebAppMenuItemByMenuId(menuId);
      return _circularNumberTipBuilder(
          getWebAppNotifyCountListenable(
              item.singleStateItem.customObject?.sessionId ?? ''),
          tipUnreadCount: false);
    }

    return null;
  }

  MenuItemIconBuilder? getMenuItemIconBuilder(int menuId) {
    if (menuId == NEMenuIDs.microphone) {
      return (context, state) {
        return buildRoomUserVolumeIndicator(roomContext.localMember.uuid);
      };
    }
    return null;
  }

  CyclicStateListController getMenuItemStateController(
      int menuId, bool checked) {
    var initialState =
        checked ? NEMenuItemState.checked : NEMenuItemState.uncheck;
    ValueListenable? listenTo;
    switch (menuId) {
      case NEMenuIDs.microphone:
        listenTo = arguments.audioMuteListenable;
        initialState = arguments.audioMute
            ? NEMenuItemState.checked
            : NEMenuItemState.uncheck;
        break;
      case NEMenuIDs.camera:
        listenTo = arguments.videoMuteListenable;
        initialState = arguments.videoMute
            ? NEMenuItemState.checked
            : NEMenuItemState.uncheck;
        break;
      case NEMenuIDs.screenShare:
        listenTo = screenShareListenable;
        initialState = isSelfScreenSharing()
            ? NEMenuItemState.checked
            : NEMenuItemState.uncheck;
        break;
      case NEMenuIDs.whiteBoard:
        listenTo = whiteBoardShareListenable;
        initialState = isSelfWhiteBoardSharing()
            ? NEMenuItemState.checked
            : NEMenuItemState.uncheck;
        break;
      case NEMenuIDs.cloudRecord:
        listenTo = cloudRecordListenable;
        initialState = roomContext.isCloudRecording
            ? NEMenuItemState.checked
            : NEMenuItemState.uncheck;
        break;
      case NEMenuIDs.disconnectAudio:
        listenTo = audioConnectListenable;
        initialState = NEMenuItemState.uncheck;
        break;
    }
    return CyclicStateListController(
      stateList: [NEMenuItemState.uncheck, NEMenuItemState.checked],
      initialState: initialState,
      listenTo: listenTo,
    );
  }

  Widget _meetingMemberCountBuilder(BuildContext context, Widget anchor) {
    return SafeValueListenableBuilder(
      valueListenable: memberTotalCountListenable,
      builder: (context, count, _) {
        return Container(
          height: 24,
          child: Stack(
            children: <Widget>[
              Center(
                child: anchor,
              ),
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  padding: EdgeInsets.only(left: 36),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$count',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              decoration: TextDecoration.none,
                              fontWeight: FontWeight.w400)),
                      SafeValueListenableBuilder<int>(
                          valueListenable:
                              waitingRoomManager.unreadMemberCountListenable,
                          builder: (context, unreadMemberCount, _) =>
                              Visibility(
                                visible: unreadMemberCount > 0,
                                child: ClipOval(
                                    child: Container(
                                        height: 6,
                                        width: 6,
                                        decoration: BoxDecoration(
                                            color: _UIColors.colorFE3B30))),
                              )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  MenuItemTipBuilder? _circularNumberTipBuilder(
    ValueListenable<int>? valueListenable, {
    int max = 99,
    bool tipUnreadCount = true,
    ValueListenable<int>? unreadMessageCountListenable,
  }) {
    if (valueListenable != null) {
      return (context, anchor) {
        getBuilder(int unread) => SafeValueListenableBuilder(
              valueListenable: valueListenable,
              builder: (_, int value, __) {
                if (value > 0 || unread > 0) {
                  return Container(
                      height: 24,
                      width: 36,
                      child:
                          Stack(alignment: Alignment.center, children: <Widget>[
                        anchor,
                        Align(
                            alignment: Alignment.topRight,
                            child: ClipOval(
                                child: Container(
                                    height: tipUnreadCount ? 16 : 10,
                                    width: tipUnreadCount ? 16 : 10,
                                    decoration: ShapeDecoration(
                                        color: _UIColors.colorFE3B30,
                                        shape: Border()),
                                    alignment: Alignment.center,
                                    child: Text(
                                      tipUnreadCount
                                          ? (value > max ? '$max+' : '$value')
                                          : '',
                                      style: const TextStyle(
                                          fontSize: 8,
                                          color: Colors.white,
                                          decoration: TextDecoration.none,
                                          fontWeight: FontWeight.w400),
                                    ))))
                      ]));
                } else {
                  return anchor;
                }
              },
            );
        return unreadMessageCountListenable == null
            ? getBuilder(0)
            : SafeValueListenableBuilder(
                valueListenable: unreadMessageCountListenable,
                builder: (_, int unreadCount, __) => getBuilder(unreadCount),
              );
      };
    } else {
      return null;
    }
  }

  /// 按钮事件回调
  void handleMenuItemClick(NEMenuClickInfo clickInfo) async {
    final itemId = clickInfo.itemId;
    commonLogger.i('handleMenuItemClick $itemId');
    if (_fullMoreMenuItemList.any((element) => element.itemId == itemId)) {
      await _hideMorePopupMenu();
    }
    switch (itemId) {
      case NEMenuIDs.microphone:
        _muteMyAudio(!arguments.audioMute);
        return;
      case NEMenuIDs.camera:
        _muteMyVideo(!arguments.videoMute);
        return;
      case NEMenuIDs.screenShare:
        _onScreenShare();
        return;
      case NEMenuIDs.managerParticipants:
      case NEMenuIDs.participants:
        _onMember();
        return;
      case NEMenuIDs.chatroom:
        onChat();
        return;
      case NEMenuIDs.invitation:
        _onInvite();
        return;
      case InternalMenuIDs.sip:
        Navigator.of(context).push(MaterialMeetingPageRoute(builder: (context) {
          return MeetingInvitePage(roomUuid: roomContext.roomUuid);
        }));
        return;
      case InternalMenuIDs.more:
        commonLogger.i('handleMenuItemClick InternalMenuIDs.more before');
        if (arguments.options.extras['useCompatibleMoreMenuStyle'] == true) {
          _showCompatibleMoreMenu();
          commonLogger.i(
              'handleMenuItemClick InternalMenuIDs.more  _showCompatibleMoreMenu');
        } else {
          _showMorePopupMenu();
          commonLogger.i(
              'handleMenuItemClick InternalMenuIDs.more  _showMorePopupMenu');
        }
        return;
      case InternalMenuIDs.beauty:
        _onBeauty();
        return;
      case InternalMenuIDs.live:
        _onLive();
        return;
      case NEMenuIDs.whiteBoard:
        _onWhiteBoard();
        return;
      case InternalMenuIDs.virtualBackground:
        _onVirtualBackground();
        return;
      case NEMenuIDs.cloudRecord:
        _onCloudRecord();
        return;
      case NEMenuIDs.security:
        _onSecurity();
        return;
      case NEMenuIDs.notifyCenter:
        _onNotifyCenter();
        return;
      case NEMenuIDs.disconnectAudio:
        _onDisconnectAudio();
        return;
      case NEMenuIDs.sipCall:
        _onSipCall();
        return;
    }
    if (itemId >= firstInjectableMenuId) {
      final transitionFuture =
          NEMeetingUIKit()._notifyOnInjectedMenuItemClick(context, clickInfo);
      menuId2Controller[itemId]?.didStateTransition(transitionFuture);
    } else if (_isWebApp(itemId)) {
      /// 小应用
      final item = getWebAppMenuItemByMenuId(itemId);
      _updateNotifyMessageTip(MeetingNotifyDialogCountTipType.hide);
      MeetingNotifyCenterActionUtil.openPlugin(
        context,
        roomContext,
        item,
        clearAllMessage: (String? sessionId) {
          if (sessionId != null) {
            _unreadNotifyMessageListenable.value
                .removeWhere((element) => element.sessionId == sessionId);
          }
          if (_unreadNotifyMessageListenable.value.length <= 0) {
            _unReadMoreMenuItemUnreadCountNotifier?.value = 0;
          }
        },
      );
    }
  }

  bool _isWebApp(int itemId) {
    return itemId >= webAppItemIdMin && itemId <= webAppItemIdMax;
  }

  NESingleStateMenuItem<NEMeetingWebAppItem> getWebAppMenuItemByMenuId(
      int itemId) {
    return webAppList.firstWhere((element) => element.itemId == itemId);
  }

  /// 更新自定义菜单项的状态
  Future<NEResult<void>> updateInjectedMenuItem(NEMeetingMenuItem item) {
    commonLogger.i('updateInjectedMenuItem $item');
    final updateToolbar =
        _updateMenuItem(arguments.injectedToolbarMenuItems, item);
    final updateMore = _updateMenuItem(arguments.injectedMoreMenuItems, item);

    var result =
        NEResult(code: NEErrorCode.failure, msg: 'Cannot find the menu item');
    if (updateMore || updateToolbar) {
      updateMenuItemState(item);
      result = NEResult.success();
    }
    if (updateToolbar) {
      setState(() {});
    }
    if (updateMore) {
      moreMenuItemUpdatedEventStream.add(Object());
    }
    return Future.value(result);
  }

  bool _updateMenuItem(
      List<NEMeetingMenuItem> menuItemList, NEMeetingMenuItem newItem) {
    final index = menuItemList.firstIndexOf((e) => e == newItem);
    if (index == -1) return false;
    menuItemList[index] = newItem;
    return true;
  }

  bool hasHandsUp() {
    return userList.any((user) => user.isRaisingHand);
  }

  int handsUpCount() {
    return userList.where((user) => user.isRaisingHand).length;
  }

  Widget buildHandsUp(String desc, VoidCallback callback) {
    return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: callback,
        child: Container(
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  height: 40,
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                      color: _UIColors.color_337eff,
                      border: Border.all(color: Colors.transparent, width: 2),
                      borderRadius: BorderRadius.all(Radius.circular(2))),
                  child: IntrinsicWidth(
                    child: Column(
                      children: [
                        Icon(NEMeetingIconFont.icon_raisehands,
                            key: MeetingUIValueKeys.raiseHands,
                            size: 20,
                            color: Colors.white),
                        Expanded(
                            child: Center(
                          child: Text(desc,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  decoration: TextDecoration.none,
                                  fontWeight: FontWeight.w400)),
                        ))
                      ],
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Icon(NEMeetingIconFont.icon_triangle_down,
                    size: 7, color: _UIColors.color_337eff),
              ),
            ],
          ),
        ));
  }

  bool _isMenuItemShowing(int itemId) => _fullMenuItemList
      .any((element) => element.itemId == itemId && shouldShowMenu(element));

  Iterable<NEMeetingMenuItem> get _fullMenuItemList =>
      arguments.injectedToolbarMenuItems.followedBy(_fullMoreMenuItemList);

  Iterable<NEMeetingMenuItem> get _fullMoreMenuItemList =>
      arguments.injectedMoreMenuItems
          .followedBy(InternalMenuItems.dynamicFeatureMenuItemList)
          .followedBy(webAppList);

  /// 小应用列表
  List<NESingleStateMenuItem<NEMeetingWebAppItem>> webAppList = List.empty();

  bool _willMoreMenuShow() => _fullMoreMenuItemList.any(shouldShowMenu);

  bool _isMoreMenuOpen = false;
  ValueNotifierAdapter<int, int>? _moreMenuItemUnreadCountNotifier;

  ValueListenable<int>? get moreMenuItemTipListenable {
    _moreMenuItemUnreadCountNotifier ??= ValueNotifierAdapter<int, int>(
      source: _messageSource.unreadMessageListenable,
      mapper: (value) => value,
    );
    return _moreMenuItemUnreadCountNotifier;
  }

  /// 自增itemID用于小应用
  var webAppItemId = webAppItemIdMin;

  int genWebAppItemId() {
    webAppItemId++;
    if (webAppItemId > webAppItemIdMax) {
      webAppItemId = webAppItemIdMin;
    }
    return webAppItemId;
  }

  void _showMorePopupMenu() {
    /// 打开更多弹窗时，关闭聊天消息气泡
    cancelInComingTips();
    commonLogger.i('_showMorePopupMenu');
    _isMoreMenuOpen = true;
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        routeSettings: RouteSettings(name: _moreMenuRouteName),
        isScrollControlled: true,
        builder: (context) {
          bool isLandscape =
              MediaQuery.orientationOf(context) == Orientation.landscape;
          context.watch<MeetingUIState>();
          return SingleChildScrollView(
              child: StreamBuilder(
                  stream: fullMoreMenuChangedStream,
                  builder: (context, value) {
                    return Container(
                        padding: EdgeInsets.only(
                            top: 20,
                            left: isLandscape ? 76 : 28,
                            right: isLandscape ? 76 : 28,
                            bottom: 50),
                        decoration: BoxDecoration(
                          color: _UIColors.color23232C,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: _divideGroupBySize(
                              size: isLandscape ? 6 : 4,
                              space: isLandscape ? 30 : 16),
                        ));
                  }));
        }).whenComplete(() => _isMoreMenuOpen = false);
  }

  List<Widget> _divideGroupBySize({required int size, double? space}) {
    final widgets = _fullMoreMenuItemList
        .where((e) => shouldShowMenu(e, isMoreMenuItem: true))
        .map((e) => menuItem2Widget(e, isMoreMenuItem: true))
        .whereType<Widget>()
        .toList(growable: false);
    final result = <Widget>[];
    for (var i = 0; i < widgets.length; i += size) {
      final children = widgets
          .sublist(i, min(i + size, widgets.length))
          .map((e) => SizedBox(child: e, width: 60, height: 68))
          .toList();

      /// 不能整除则补齐
      if (children.length < size) {
        children.addAll(List.generate(size - children.length,
            (index) => SizedBox(width: 60, height: 68)));
      }
      result.add(Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: children,
      ));
      if (i + size < widgets.length) {
        result.add(SizedBox(height: space));
      }
    }
    return result;
  }

  Stream get fullMoreMenuChangedStream => StreamGroup.merge([
        roomInfoUpdatedEventStream.stream,
        sdkConfig.onConfigUpdated,
        moreMenuItemUpdatedEventStream.stream,
        webAppListUpdatedEventStream.stream,
      ]);

  Future<bool> _hideMorePopupMenu() {
    commonLogger.i('_hideMorePopupMenu _isMoreMenuOpen: $_isMoreMenuOpen');
    if (!_isMoreMenuOpen) return Future.value(true);
    return Navigator.of(context)
        .maybePop(ModalRoute.withName(_moreMenuRouteName));
  }

  void onChat() {
    cancelInComingTips();
    showMeetingPopupPageRoute(
        context: context,
        routeSettings: RouteSettings(name: MeetingChatRoomPage.routeName),
        builder: (context) {
          return wrapWithWatermark(
              child: MeetingChatRoomPage(
            arguments: ChatRoomArguments(
              roomContext: roomContext,
              messageSource: _messageSource,
              waitingRoomManager: waitingRoomManager,
              chatRoomManager: chatRoomManager,
              roomInfoUpdatedEventStream: roomInfoUpdatedEventStream.stream,
            ),
          ));
        });
  }

  void _onSecurity() {
    showMeetingPopupPageRoute(
      context: context,
      builder: (context) {
        return MeetingSecurityPage(
          SecurityArguments(
            roomContext,
            waitingRoomManager,
            isMySelfManagerListenable,
            sdkConfig.isGuestJoinSupported,
          ),
        );
      },
      routeSettings: RouteSettings(name: MeetingSecurityPage.routeName),
    );
  }

  void _onSipCall() {
    showMeetingPopupPageRoute(
        context: context,
        routeSettings: RouteSettings(name: MeetingSipCallPage.routeName),
        builder: (context) {
          return MeetingSipCallPage(
            SipCallArguments(
              roomContext,
              isMySelfManagerListenable,
              sdkConfig.outboundPhoneNumber,
            ),
          );
        });
  }

  void _onDisconnectAudio() {
    if (roomContext.localMember.isAudioConnected) {
      roomContext.rtcController.disconnectMyAudio();
    } else {
      roomContext.rtcController.reconnectMyAudio();
    }
  }

  void _showCompatibleMoreMenu() {
    showCupertinoModalPopup<int>(
        context: context,
        builder: (BuildContext context) => CupertinoActionSheet(
              title: Text(NEMeetingUIKitLocalizations.of(context)!.meetingMore,
                  style: TextStyle(color: _UIColors.grey_8F8F8F, fontSize: 13)),
              actions: _fullMoreMenuItemList
                  .where(shouldShowMenu)
                  .map((element) {
                    String? title;
                    if (element is NESingleStateMenuItem) {
                      title = element.singleStateItem.text;
                    } else if (element is NECheckableMenuItem) {
                      title = element.uncheckStateItem.text;
                    }
                    if (element.itemId == NEMenuIDs.chatroom) {
                      title =
                          "${NEMeetingUIKitLocalizations.of(context)!.chat}${_messageSource.unread > 0 ? '(${_messageSource.unread})' : ''}";
                    }
                    return title != null
                        ? buildActionSheetItem(
                            context, false, title, element.itemId)
                        : null;
                  })
                  .whereType<Widget>()
                  .toList(growable: false),
              cancelButton: buildActionSheetItem(
                  context,
                  true,
                  NEMeetingUIKitLocalizations.of(context)!.globalCancel,
                  InternalMenuIDs.cancel),
            )).then((itemId) {
      if (itemId != null) {
        handleMenuItemClick(NEMenuClickInfo(itemId));
      }
    });
  }

  Future<void> _onLive() async {
    final result = await roomContext.liveController.getLiveInfo();
    var currentLiveInfo = result.data;
    if (currentLiveInfo == null) return;
    showMeetingPopupPageRoute(
      context: context,
      builder: (context) {
        return MeetingLivePage(LiveArguments(
            roomContext,
            currentLiveInfo,
            roomInfoUpdatedEventStream.stream,
            arguments.meetingInfo.settings?.liveConfig?.liveAddress));
      },
      routeSettings: RouteSettings(name: "MeetingLivePage"),
    );
  }

  /// 加入中状态
  Widget buildJoiningUI() {
    final joiningTipText = Text(
      NEMeetingUIKitLocalizations.of(context)!.meetingJoinTips,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white,
        fontSize: 14,
        decoration: TextDecoration.none,
        fontWeight: FontWeight.w400,
      ),
    );

    return Container(
      decoration: BoxDecoration(
          gradient:
              buildGradient([_UIColors.grey_292933, _UIColors.grey_1E1E25])),
      child: Column(
        children: _isMinimized
            ? [
                Spacer(),
                joiningTipText,
                Spacer(),
              ]
            : [
                Spacer(),
                Image.asset(NEMeetingImages.meetingJoin,
                    package: NEMeetingImages.package),
                SizedBox(height: 16),
                joiningTipText,
                Spacer(),
              ],
      ),
    );
  }

  void finishPage() {
    commonLogger.i(
      'finishPage isHost:${isHost()}, isCoHost:${isSelfCoHost()} tap leave.',
    );
    if (_isMinimized) return;
    DialogUtils.showChildNavigatorPopup<int>(
      context,
      (context) => CupertinoActionSheet(
        actions: <Widget>[
          buildActionSheetItem(
              context,
              false,
              NEMeetingUIKitLocalizations.of(context)!.meetingLeaveFull,
              InternalMenuIDs.leaveMeeting),
          if (isSelfHostOrCoHost())
            buildActionSheetItem(
                context,
                false,
                NEMeetingUIKitLocalizations.of(context)!.meetingQuit,
                InternalMenuIDs.closeMeeting,
                textColor: _UIColors.colorFE3B30),
        ],
        cancelButton: buildActionSheetItem(
            context,
            true,
            NEMeetingUIKitLocalizations.of(context)!.globalCancel,
            InternalMenuIDs.cancel),
      ),
      routeSettings: RouteSettings(name: 'ExitPopup'),
    ).then<void>((int? itemId) async {
      if (itemId != null && itemId != InternalMenuIDs.cancel) {
        _meetingState = MeetingState.closing;
        final requestClose = itemId == InternalMenuIDs.closeMeeting;
        final result;
        if (requestClose) {
          result = await roomContext.endRoom();
          debugPrintAlog('End room result: $result');
        } else {
          roomContext.leaveRoom();
          result = VoidResult.success();
        }
        if (!mounted) return;
        if (requestClose && !result.isSuccess()) {
          roomContext.leaveRoom();
          showToast(NEMeetingUIKitLocalizations.of(context)!
              .networkUnavailableCloseFail);
        }
        switch (itemId) {
          case InternalMenuIDs.leaveMeeting:
            reportMeetingEndEvent(NERoomEndReason.kLeaveBySelf);
            _onCancel(
                reason:
                    NEMeetingUIKitLocalizations.of(context)!.meetingLeaveFull,
                exitCode: NEMeetingCode.self);
            break;
          case InternalMenuIDs.closeMeeting:
            reportMeetingEndEvent(NERoomEndReason.kCloseByMember);
            _onCancel(
                reason: NEMeetingUIKitLocalizations.of(context)!.meetingClosed,
                exitCode: NEMeetingCode.closeBySelfAsHost);
            break;
          default:
            break;
        }
      }
    });
  }

  Widget buildActionSheetItem(
      BuildContext context, bool defaultAction, String title, int itemId,
      {Color textColor = _UIColors.color_007AFF}) {
    return CupertinoActionSheetAction(
        isDefaultAction: defaultAction,
        child: Text(title, style: TextStyle(color: textColor)),
        onPressed: () {
          Navigator.pop(context, itemId);
        });
  }

  bool isSelf(String? userId) {
    return userId != null && roomContext.isMySelf(userId);
  }

  bool isSelfScreenSharing() {
    return roomContext.localMember.isSharingScreen;
  }

  bool isOtherScreenSharing() {
    final member = roomContext.getMember(getScreenShareUserId());
    return member != null &&
        !roomContext.isMySelf(member.uuid) &&
        member.isInRtcChannel;
  }

  bool isWhiteboardTransparentModeEnabled() {
    return whiteboardController.isTransparentModeEnabled();
  }

  bool isSelfWhiteBoardSharing() {
    return whiteboardController.isSharingWhiteboard();
  }

  bool isWhiteBoardSharing() {
    return whiteboardController.getWhiteboardSharingUserUuid() != null;
  }

  bool isScreenSharing() {
    return rtcController.getScreenSharingUserUuid() != null;
  }

  bool isOtherWhiteBoardSharing() {
    final uuid = whiteboardController.getWhiteboardSharingUserUuid();
    return uuid != null && !roomContext.isMySelf(uuid);
  }

  bool isWhiteBoardSharingAndIsHost() {
    return isSelfWhiteBoardSharing() ||
        (isWhiteBoardSharing() && isSelfHostOrCoHost());
  }

  Widget buildAudioModeUserItem(NERoomMember user) {
    return ValueListenableBuilder(
        valueListenable: user.isInCallListenable,
        builder: (context, isInCall, _) {
          return Container(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                SizedBox(height: 16),
                Stack(
                  children: [
                    _buildMeetingInviteWrapper(
                      child: NEMeetingAvatar.xxlarge(
                        name: user.name,
                        url: user.avatar,
                      ),
                      user: user,
                    ),
                    if (isInCall)
                      CircleAvatar(
                        backgroundColor: Colors.black54,
                        radius: 32,
                        child: Icon(
                          Icons.phone,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 8),
                if (!_isMinimized)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          user.name,
                          maxLines: 1,
                          textWidthBasis: TextWidthBasis.longestLine,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _UIColors.white,
                            fontSize: 14,
                            decoration: TextDecoration.none,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      if (user.isAudioConnected &&
                          !user.isInSIPInviting &&
                          !user.isInAppInviting) ...[
                        SizedBox(width: 4),
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: _UIColors.color54575D,
                          child: buildRoomUserVolumeIndicator(
                            user.uuid,
                            size: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                Visibility.maintain(
                  visible: isInCall,
                  child: Text(
                    NEMeetingUIKitLocalizations.of(context)!.meetingIsInCall,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 12,
                      color: _UIColors.color_999999,
                      decoration: TextDecoration.none,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          );
        });
  }

  /// 主讲人视觉，
  Widget buildHostUI() {
    // 小窗口模式下，会议结束，展示文本提示
    if (_isAlreadyMeetingDisposeInMinimized) {
      return buildMeetingWasInterrupted();
    }

    if (isSelfScreenSharing()) {
      return buildScreenShareUI();
    }
    if (isOtherScreenSharing()) {
      return buildRemoteScreenShare();
    }
    if (isWhiteBoardSharing() && !_isMinimized) {
      return buildWhiteBoardShareUI();
    }
    final bigViewUser = bigUid != null ? roomContext.getMember(bigUid!) : null;
    if (bigViewUser == null) return Container();
    Widget hostUI = Stack(
      children: <Widget>[
        if (!isAudioGridLayoutMode || _isMinimized) ...[
          buildBigVideoView(bigViewUser),
          if (bigViewUser.canRenderVideo || _isMinimized)
            buildCornerTipView(
              bigViewUser,
              useSafeArea: !_isMinimized,
              extraMargin: _isMinimized ? 4 : 12,
            ),
          if (smallUid != null && !_isMinimized)
            buildDraggableSmallVideoView(buildSmallView(smallUid!)),
          if (!_isMinimized) buildLockVideoIcon(bigViewUser),
        ],
        if (!_isMinimized) ...[
          if (isAudioGridLayoutMode) buildGrid(0),
          _buildWaitingRoomCountTip(),
          _buildNotifyMessageTip(),
        ],
      ],
    );
    return hostUI;
  }

  /// 锁定视频/解锁视频
  Widget buildLockVideoIcon(NERoomMember bigViewUser) {
    return ListenableBuilder(
        listenable:
            Listenable.merge([pageViewCurrentIndex, appBarAnimController]),
        builder: (context, _) {
          if (pageViewCurrentIndex.value != 0 ||
              appBarAnimController.status != AnimationStatus.dismissed ||
              roomContext.getFocusUuid() != null)
            return const SizedBox.shrink();
          return Positioned(
            bottom:
                bottomBarHeight + MediaQuery.viewPaddingOf(context).bottom + 16,
            right: 20,
            child: Selector<MeetingUIState, String?>(
              selector: (_, state) => state.lockedUser,
              builder: (context, lockedUser, __) {
                if (focusUid != null && focusUid == bigViewUser.uuid)
                  return const SizedBox.shrink();
                final isLocked = lockedUser == bigViewUser.uuid;
                if (!isLocked && !bigViewUser.isVideoOn)
                  return const SizedBox.shrink();
                return GestureDetector(
                  onTap: () {
                    context
                        .read<MeetingUIState>()
                        .lockUserVideo(isLocked ? null : bigViewUser.uuid);
                    showToast(isLocked
                        ? meetingUiLocalizations.meetingUnpinViewTip
                        : meetingUiLocalizations.meetingPinViewTip(
                            meetingUiLocalizations.meetingBottomRightCorner));
                  },
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: ShapeDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Icon(
                      NEMeetingIconFont.icon_pin,
                      color: isLocked ? Colors.white : Colors.white60,
                      size: 24,
                    ),
                  ),
                );
              },
            ),
          );
        });
  }

  Widget buildDraggableSmallVideoView(Widget child) {
    return DraggablePositioned(
        size: _isPad ? kIPadSmallVideoViewSize : kSmallVideoViewSize,
        initialAlignment: smallVideoViewAlignment,
        paddings: smallVideoViewPaddings,
        pinAnimationDuration: const Duration(milliseconds: 500),
        pinAnimationCurve: Curves.easeOut,
        builder: (context) => child,
        onPinStart: (alignment) {
          smallVideoViewAlignment = alignment;
        });
  }

  bool get shouldShowWhiteboardShareUserVideo {
    final member = roomContext
        .getMember(whiteboardController.getWhiteboardSharingUserUuid());
    if (member != null && member.isVideoOn) {
      return isSelfWhiteBoardSharing() ||
          arguments.options.showWhiteboardShareUserVideo;
    }
    return false;
  }

  void lockWhiteboardCameraContent(String uid, int width, int height) {
    if (!mounted || uid != bigUid) return;
    whiteboardController.lockCameraWithContent(width, height);
  }

  ///白板共享
  Widget buildWhiteBoardShareUI() {
    debugPrint('buildWhiteBoardShareUI');
    // _isEditStatus = whiteboardController.isDrawWhiteboardEnabled();
    final whiteboardPage = WhiteBoardWebPage(
      key: ValueKey(whiteboardController.getWhiteboardSharingUserUuid()),
      roomContext: roomContext,
      whiteBoardPageStatusCallback: (isEditStatus) {
        whiteBoardEditingState.value = isEditStatus;
      },
      valueNotifier: whiteBoardInteractionStatusNotifier,
      backgroundColor:
          whiteboardController.isSupported ? Colors.transparent : null,
      isMinimized: _isMinimized,
    );
    final bigViewUser = bigUid != null ? roomContext.getMember(bigUid!) : null;
    return _isMinimized
        ? whiteboardPage
        : Stack(
            children: <Widget>[
              if (isWhiteboardTransparentModeEnabled())
                buildBigVideoView(bigViewUser,
                    videoViewListener: _LockCameraVideoViewListener(
                        lockWhiteboardCameraContent),
                    isWhiteboardTransparent: true),
              whiteboardPage,
              if (shouldShowWhiteboardShareUserVideo &&
                  !isWhiteboardTransparentModeEnabled())
                ValueListenableBuilder(
                  valueListenable: whiteBoardEditingState,
                  builder:
                      (BuildContext context, bool isEditing, Widget? child) {
                    if (isEditing) return Container();
                    return buildDraggableSmallVideoView(buildSmallView(
                        whiteboardController.getWhiteboardSharingUserUuid()));
                  },
                ),
              if (!_isMinimized) _buildNotifyMessageTip(),
            ],
          );
  }

  ///屏幕共享
  Widget buildScreenShareUI() {
    final mySelf = roomContext.localMember;
    return Stack(
      children: [
        Container(
          color: _UIColors.color_181820,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                NEMeetingIconFont.icon_yx_tv_sharescreen,
                size: 40,
                color: _UIColors.colorD8D8D8.withOpacity(0.1),
              ),
              SizedBox(height: 12),
              Text(
                NEMeetingUIKitLocalizations.of(context)!
                    .screenShareLocalTips(roomContext.localMember.name),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  decoration: TextDecoration.none,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_isAudioShareSupported()) ...[
                SizedBox(height: 24),
                ValueListenableBuilder<bool>(
                  valueListenable: audioSharingListenable,
                  builder: (context, audioSharing, child) {
                    return TextButton.icon(
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.all(
                          Colors.white.withOpacity(0.2),
                        ),
                        padding: MaterialStateProperty.all(
                          const EdgeInsets.symmetric(horizontal: 24.0),
                        ),
                        shape: MaterialStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(38 / 2),
                          ),
                        ),
                        fixedSize: MaterialStateProperty.all(
                            const Size.fromHeight(38)),
                      ),
                      onPressed: () => enableAudioShare(!audioSharing),
                      icon: Icon(
                        NEMeetingIconFont.icon_device_audio,
                        size: 16,
                        color:
                            audioSharing ? Colors.white : _UIColors.colorD93D35,
                      ),
                      label: Text(
                        audioSharing
                            ? NEMeetingUIKitLocalizations.of(context)!
                                .meetingStopAudioShare
                            : NEMeetingUIKitLocalizations.of(context)!
                                .meetingStartAudioShare,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        if (mySelf.canRenderVideo && !_isMinimized)
          buildDraggableSmallVideoView(buildSmallView(mySelf.uuid)),
        if (!_isMinimized) _buildNotifyMessageTip(),
        // if (shouldShowFloatingMicrophone())
        //   buildSelfVolumeIndicator(),
      ],
    );
  }

  bool shouldShowFloatingMicrophone() {
    return !isWhiteBoardSharing() &&
        !isSelfScreenSharing() &&
        !isOtherScreenSharing() &&
        roomContext.localMember.isAudioConnected &&
        roomContext.localMember.isVisible &&
        arguments.options.showFloatingMicrophone;
  }

  String? getScreenShareUserId() {
    return rtcController.getScreenSharingUserUuid();
  }

  bool shouldShowScreenShareUserVideo(String? shareUser) {
    if (!arguments.options.showScreenShareUserVideo) {
      return false;
    }
    final member = roomContext.getMember(shareUser);
    if (member != null && !member.isVideoOn) {
      return false;
    }
    return true;
  }

  Widget buildRemoteScreenShare() {
    _showScreenShareInteractionTip();
    final roomUid = getScreenShareUserId();
    final user = roomContext.getMember(roomUid);
    return Stack(
      children: <Widget>[
        if (user == null)
          Container(color: _UIColors.color_181820)
        else ...[
          GestureDetector(
            onDoubleTap: () {
              _screenShareController.value = Matrix4.identity();
            },
            child: Align(
              child: InteractiveViewer(
                maxScale: 4.0,
                minScale: 1.0,
                transformationController: _screenShareController,
                child: !shareUserIsPIP(roomUid!)
                    ? ListenableBuilder(
                        listenable: enableVideoPreviewPageIndex,
                        builder: (context, _) {
                          return enableVideoPreviewForUser(user, 0)
                              ? NERoomUserVideoView.subStream(
                                  roomUid,
                                  // keepAlive: true,
                                  debugName:
                                      roomContext.getMember(roomUid)?.name,
                                  listener: this,
                                )
                              : Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Text(
                                    NEMeetingUIKitLocalizations.of(context)!
                                        .screenShareUser(user.name),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      decoration: TextDecoration.none,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                        },
                      )
                    : Container(),
              ),
              alignment: Alignment.center,
            ),
          ),
          if (shouldShowScreenShareUserVideo(roomUid) &&
              smallUid != null &&
              !_isMinimized)
            buildDraggableSmallVideoView(buildSmallView(smallUid!)),
          if (!_isMinimized)
            buildCornerTipView(
              user,
              label: NEMeetingUIKitLocalizations.of(context)!
                  .screenShareUser(user.name),
              extraMargin: 12,
            ),
          if (!_isMinimized) _buildNotifyMessageTip(),
        ],
        if (!_isMinimized)
          [roomContext.getMember(speakingUid)].map((user) {
            return user != null
                ? buildCornerTipView(
                    user,
                    label: NEMeetingUIKitLocalizations.of(context)!
                            .meetingSpeakingPrefix +
                        user.name,
                    alignment: Alignment.topRight,
                    useSafeArea: true,
                  )
                : SizedBox.shrink();
          }).first,
      ],
    );
  }

  /// 画廊模式
  Widget buildGalleyUI() {
    updateGridLayoutMode();
    determineBigSmallUser();
    var pageSize = calculatePageSize();
    if (!_isMinimized) {
      var curPage = _galleryModePageController?.hasClients == true
          ? _galleryModePageController?.page?.round() ?? 0
          : 0;
      if (curPage >= pageSize) {
        curPage = pageSize - 1;
        _galleryModePageController?.animateToPage(curPage,
            duration: Duration(milliseconds: 50), curve: Curves.easeInOut);
      }
    }
    // var _ratio = _userAspectRatioMap[getScreenShareUserId() != null
    //     ? getScreenShareUserId()
    //     : bigUid!];
    return _isMinimized
        ? wrapWithWatermark(
            child: buildHostUI(),
          )
        : Stack(
            children: <Widget>[
              wrapWithWatermark(
                  child: NotificationListener<ScrollNotification>(
                onNotification: handlePageViewScrollNotification,
                child: ValueListenableBuilder<bool>(
                    valueListenable: pageViewScrollableListenable,
                    builder: (context, scrollable, child) {
                      return PageView.builder(
                        itemBuilder: (BuildContext context, int index) {
                          if (index > 0) {
                            return buildGrid(
                                isAudioGridLayoutMode ? index : index - 1);
                          }
                          return buildHostUI();
                        },
                        physics: scrollable
                            ? PageScrollPhysics()
                            : NeverScrollableScrollPhysics(),
                        controller: _galleryModePageController,
                        allowImplicitScrolling: false,
                        itemCount: pageSize,
                        onPageChanged: (index) {
                          pageViewCurrentIndex.value = index;
                        },
                      );
                    }),
              )),
              if (pageSize > 1)
                Padding(
                  padding: EdgeInsets.only(bottom: bottomBarHeight + 8),
                  child: PointerEventAware(
                    key: ValueKey(pageSize),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: DotsIndicator(
                        itemCount: pageSize,
                        selectedIndex: pageViewCurrentIndex,
                      ),
                    ),
                  ),
                ),
              if (shouldShowFloatingMicrophone()) buildSelfVolumeIndicator(),
            ],
          );
  }

  LinearGradient buildGradient(List<Color> colors) {
    return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        tileMode: TileMode.clamp,
        colors: colors);
  }

  void updateGridLayoutParams() {
    final size = MediaQuery.sizeOf(context);
    final paddings = MediaQuery.paddingOf(context);
    [
      audioGridLayout,
      videoGridLayout,
    ].forEach((layout) {
      layout
        ..ensureLayoutParams(size, paddings)
        ..portrait = MediaQuery.orientationOf(context) == Orientation.portrait;
    });
  }

  /// build
  Widget buildGrid(int page) {
    final gridLayout = currentGridLayout;
    List<NERoomMember?> pageUsers = List.of(getUserListByPage(page));

    /// 如果是视频模式，为了复用布局的代码，需要确保每页都是填满布局行和列，不足则填充假的数据
    if (!isAudioGridLayoutMode) {
      final size = gridLayout.pageSize - pageUsers.length;
      for (var i = 0; i < size; i++) {
        pageUsers.add(null);
      }
    }
    final users = pageUsers
        .map((user) {
          final child = user != null
              ? (isAudioGridLayoutMode
                  ? buildAudioModeUserItem(user)
                  : buildVideoModeUserItem(user, page + 1))
              : SizedBox.shrink();
          return Container(
            width: gridLayout.itemW,
            height: gridLayout.itemH,
            alignment: Alignment.center,
            foregroundDecoration: isHighLight(user?.uuid)
                ? BoxDecoration(
                    border: Border.all(
                      color: _UIColors.color_59F20C,
                      width: 2,
                    ),
                  )
                : null,
            child: child,
          );
        })
        .toSet()
        .toList();
    return Container(
      color: isAudioGridLayoutMode ? _UIColors.color_292933 : Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: Iterable.generate(gridLayout.rows).map((index) {
            int start = index * gridLayout.columns;
            if (start >= users.length) return SizedBox.shrink();
            int end = min(users.length, start + gridLayout.columns);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: users.getRange(start, end).toList(),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget buildVideoModeUserItem(NERoomMember user, int page) {
    Widget child = ValueListenableBuilder<bool>(
      valueListenable: user.isInCallListenable,
      builder: (context, isInCall, child) {
        final child = buildSmallNameView(user, isInCall);
        return isInCall
            ? child
            : buildUserVideoView(
                user,
                streamType: NEVideoStreamType.kLow,
                ifVideoOff: child,
                page: page,
              );
      },
    );
    child = Stack(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.all(2),
          child: child,
        ),
        buildCornerTipView(user),
      ],
    );
    return GestureDetector(
      onDoubleTap: () {
        if (roomContext.getFocusUuid() != null ||
            isWhiteBoardSharing() ||
            isScreenSharing() ||
            !user.isVideoOn) return;
        meetingUIState.lockUserVideo(user.uuid);
        _galleryModePageController?.jumpToPage(0);
        showToast(meetingUiLocalizations.meetingPinViewTip(
            meetingUiLocalizations.meetingBottomRightCorner));
      },
      child: child,
    );
  }

  // 是否需要高亮
  bool isHighLight(String? userId) {
    if (userId == null) return false;
    if (focusUid != null) return userId == focusUid;
    return activeUid == userId && !isSelf(userId);
    //return roomUid == (switchBigAndSmall ? smallUid : bigUid);
  }

  Widget buildCornerTipView(
    NERoomMember user, {
    String? label,
    Alignment alignment = Alignment.bottomLeft,
    double size = 12,
    double extraMargin = 0,
    bool useSafeArea = false,
  }) {
    Widget child = Align(
      alignment: alignment,
      child: Container(
        margin: EdgeInsets.all(4 + extraMargin),
        padding: EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.all(Radius.circular(2))),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!user.isInSIPInviting && !user.isInAppInviting)
              buildRoomUserVolumeIndicator(
                user.uuid,
                size: size,
              ),
            Flexible(
              child: Text(
                label ?? StringUtil.truncate(user.name),
                softWrap: false,
                maxLines: 1,
                textAlign: TextAlign.start,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size,
                  decoration: TextDecoration.none,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return useSafeArea ? SafeArea(child: child) : child;
  }

  Iterable<NERoomMember> get userList => roomContext.getAllUsers(
      isViewOrder: roomContext.isFollowHostVideoOrderOn(),
      isIncludeInviteMember: true,
      isIncludeInviteWaitingJoinMember: false);

  int get userCount => roomContext
      .getAllUsers(isViewOrder: roomContext.isFollowHostVideoOrderOn())
      .length;

  /// add 1 focus ui
  int calculatePageSize() {
    /// 增加被邀请成员
    final memberSize = userList.length;
    if (arguments.noGallery || memberSize < 2 || _isMinimized) {
      return 1;
    }

    final whiteboardSharing = isWhiteBoardSharing();
    // 白板编辑模式下，不支持右滑动，因为与PageView的滑动手势有冲突
    if (whiteboardSharing && whiteBoardEditingState.value) {
      return 1;
    }

    final screenSharing = isSelfScreenSharing() || isOtherScreenSharing();
    // 虽然只有两个人，但小画面是被共享者占用了，所以本端自己的小画面只能放到第二页去显示
    if (!screenSharing &&
        !whiteboardSharing &&
        (_isPad ? memberSize <= 1 : memberSize <= 2)) {
      return 1;
    }
    // 如果是其他人在屏幕共享，需要调整memberSize
    // 如果共享者已经在第一页小画面中显示，其他页需要过滤掉 共享者；如果第一页没有显示，则需要显示。
    // if (otherMemberScreenSharing && shouldShowScreenShareUserVideo(rtcController.getScreenSharingUserUuid())) {
    //   memberSize = memberSize - 1;
    // }
    final pages = (memberSize / currentGridLayout.pageSize).ceil();
    return isAudioGridLayoutMode ? pages : pages + 1;
  }

  Widget buildBigVideoView(NERoomMember? bigViewUser,
      {NERoomUserVideoViewListener? videoViewListener,
      bool isWhiteboardTransparent = false}) {
    if (bigViewUser == null) return Container();
    if (isWhiteboardTransparent) {
      lockWhiteboardCameraContent(
          bigViewUser.uuid,
          MediaQuery.sizeOf(context).width.toInt(),
          MediaQuery.sizeOf(context).height.toInt());
    }
    return ValueListenableBuilder<bool>(
      valueListenable: bigViewUser.isInCallListenable,
      builder: (context, isInCall, child) {
        final child = buildBigNameView(bigViewUser);
        return isInCall
            ? child
            : buildUserVideoView(
                bigViewUser,
                streamType: NEVideoStreamType.kHigh,
                ifVideoOff: child,
                videoViewListener: videoViewListener,
              );
      },
    );
  }

  Widget buildUserVideoView(
    NERoomMember user, {
    NEVideoStreamType streamType = NEVideoStreamType.kLow,
    Widget? ifVideoOff,
    Color? backgroundColor,
    NERoomUserVideoViewListener? videoViewListener,
    int page = 0,
  }) {
    return ListenableBuilder(
      listenable: enableVideoPreviewPageIndex,
      builder: (context, child) {
        final enableVideoPreview = enableVideoPreviewForUser(user, page);
        return user.canRenderVideo &&
                enableVideoPreview &&
                (Platform.isIOS ? !userIsPIP(user.uuid) : true)
            ? ValueListenableBuilder<bool>(
                valueListenable:
                    isSelf(user.uuid) ? localMirrorState : alwaysUnMirrorState,
                builder: (context, mirror, child) {
                  return _buildMeetingInviteWrapper(
                      child: NERoomUserVideoView(
                        user.uuid,
                        debugName: user.name,
                        backgroundColor: backgroundColor,
                        streamType: streamType,
                        mirror: mirror,
                        listener: videoViewListener ?? this,
                        isPIPActive: pictureInPictureState,
                      ),
                      user: user);
                },
              )
            : (ifVideoOff ?? Container());
      },
    );
  }

  bool get appMinimized => arguments.backgroundWidget != null && _isMinimized;

  Widget buildItemTab(VoidCallback callback, bool state, IconData enableIcon,
      IconData disableIcon, String enableStr, String disableStr,
      {Color? enableColor, Color? disableColor}) {
    return Expanded(
        child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: callback,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(state ? enableIcon : disableIcon,
              color: state
                  ? (enableColor ?? _UIColors.colorFE3B30)
                  : (disableColor ?? _UIColors.colorECEDEF)),
          Padding(padding: EdgeInsets.only(top: 2)),
          Text(
            state ? enableStr : disableStr,
            style: TextStyle(
                color: _UIColors.colorECEDEF,
                fontSize: 10,
                decoration: TextDecoration.none,
                fontWeight: FontWeight.w400),
          )
        ],
      ),
    ));
  }

  Widget buildSmallView(String? userId) {
    final user = roomContext.getMember(userId);
    if (user == null) return Container();
    Widget child = Container(
      decoration: BoxDecoration(
          border: Border.all(
        color: Colors.white,
        width: 1.0,
      )),
      child: ValueListenableBuilder<bool>(
        valueListenable: user.isInCallListenable,
        builder: (context, isInCall, child) {
          final nameView =
              buildSmallNameView(user, isInCall, showInCallTip: false);
          return Stack(
            children: <Widget>[
              isInCall
                  ? nameView
                  : buildUserVideoView(
                      user,
                      ifVideoOff: nameView,
                    ),
              buildCornerTipView(user, size: 10),
            ],
          );
        },
      ),
    );
    return GestureDetector(
      onTap: () {
        if (!_isSwitchBigSmallViewsEnable()) return;
        if (meetingUIState.lockedUser != null) {
          meetingUIState.lockUserVideo(null);
          showToast(meetingUiLocalizations.meetingUnpinViewTip);
        }
        setState(() {
          switchBigAndSmall = !switchBigAndSmall;
        });
      },
      child: child,
    );
  }

  Future<void> _lowerMyHand() async {
    if (_isMinimized) return;
    if (roomContext.localMember.isRaisingHand) {
      final cancel = await DialogUtils.showCommonDialog(
          context,
          NEMeetingUIKitLocalizations.of(context)!.meetingCancelHandsUp,
          NEMeetingUIKitLocalizations.of(context)!.meetingCancelHandsUpConfirm,
          () {
        Navigator.of(context).pop();
      }, () {
        Navigator.of(context).pop(true);
      });
      if (!mounted || _isAlreadyCancel) return;
      if (cancel != true) return;
      trackPeriodicEvent(TrackEventName.handsUp,
          extra: {'value': 0, 'meeting_num': arguments.meetingNum});
      final result = await roomContext.lowerMyHand();
      if (!result.isSuccess()) {
        showToast(result.msg ??
            NEMeetingUIKitLocalizations.of(context)!.meetingCancelHandsUpFail);
      }
    }
  }

  bool get enableMediaPubOnAudioMute {
    final shouldUnpub =
        arguments.options.unpubAudioOnMute && settings.shouldUnpubOnAudioMute();
    return !shouldUnpub;
  }

  Object? audioActionToken;

  Future<void> _muteMyAudio(bool mute) async {
    if (mute || roomContext.canUnmuteMyAudio() || _invitingToOpenAudio) {
      _invitingToOpenAudio = false;
      trackPeriodicEvent(TrackEventName.switchAudio,
          extra: {'value': mute ? 0 : 1, 'meeting_num': arguments.meetingNum});
      muteDetectStartedTimer?.cancel();
      final token = Object();
      audioActionToken = token;
      if (mute) {
        rtcController.muteMyAudio().onSuccess(() {
          muteDetectStartedTimer = Timer(muteMyAudioDelay, () {
            muteDetectStarted = true;
          });
        }).onFailure((code, msg) {
          if (!mounted || audioActionToken != token) return;
          showToast(msg ??
              NEMeetingUIKitLocalizations.of(context)!
                  .participantMuteAudioFail);
        });
      } else {
        rtcController
            .unmuteMyAudioWithCheckPermission(context, arguments.meetingTitle)
            .onFailure((code, msg) {
          if (!mounted || audioActionToken != token) return;
          showToast(msg ??
              NEMeetingUIKitLocalizations.of(context)!
                  .participantUnMuteAudioFail);
        });
      }
    } else {
      if (roomContext.localMember.isRaisingHand) {
        showToast(
            NEMeetingUIKitLocalizations.of(context)!.meetingAlreadyHandsUpTips);
        return;
      }
      final willRaise = await DialogUtils.showCommonDialog(
        context,
        NEMeetingUIKitLocalizations.of(context)!.participantMuteAudioAll,
        NEMeetingUIKitLocalizations.of(context)!.participantMuteAllHandsUpTips,
        () {
          Navigator.of(context).pop();
        },
        () {
          Navigator.of(context).pop(true);
        },
        acceptText:
            NEMeetingUIKitLocalizations.of(context)!.meetingHandsUpApply,
        contextNotifier: raiseAudioContextNotifier,
      );
      if (!mounted || _isAlreadyCancel) return;
      if (willRaise != true || !arguments.audioMute) return;
      // check again
      if (roomContext.canUnmuteMyAudio()) {
        return;
      }
      trackPeriodicEvent(TrackEventName.handsUp, extra: {
        'value': 1,
        'meeting_num': arguments.meetingNum,
        'type': 'audio'
      });
      final result = await roomContext.raiseMyHand();
      showToast(result.isSuccess()
          ? NEMeetingUIKitLocalizations.of(context)!.meetingHandsUpSuccess
          : (result.msg ??
              NEMeetingUIKitLocalizations.of(context)!.meetingHandsUpFail));
    }
  }

  void enableAudioShare(bool enable) async {
    // 需要先申请权限
    if (enable) {
      final isInCall = await NEMeetingPlugin().phoneStateService.isInCall;
      if (isInCall) {
        showToast(NEMeetingUIKitLocalizations.of(context)!
            .meetingFuncNotAvailableWhenInCallState);
        return;
      }

      final hasPermission =
          await PermissionHelper.enableLocalAudioAndCheckPermission(
              context, true, arguments.meetingTitle);
      if (!hasPermission) {
        commonLogger.i(
            'enableLoopbackRecording($enable) cancelled due to no permission');
        return;
      }
    }
    if (modifyingAudioShareState) return;
    modifyingAudioShareState = true;
    rtcController.enableLoopbackRecording(enable).then((value) {
      commonLogger.i('enableLoopbackRecording($enable) $value');
      modifyingAudioShareState = false;
      if (value.isSuccess()) {
        audioSharingListenable.value = enable;
      }
    });
  }

  void _onScreenShare() async {
    final isSharing = isSelfScreenSharing();
    commonLogger.i('_onScreenShare isShare=$isSharing');

    /// 如果不为空且不等于自己，已经有人共享了
    if (isSharing) {
      await _stopScreenShare();
    } else if (await ifScreenShareAvailable()) {
      confirmStartScreenShare();
    }
  }

  Future<void> _stopScreenShare() async {
    trackPeriodicEvent(TrackEventName.screenShare,
        extra: {'value': 0, 'meeting_num': arguments.meetingNum});
    final result = await rtcController.stopScreenShare();
    if (!result.isSuccess()) {
      showToast(result.msg ??
          NEMeetingUIKitLocalizations.of(context)!.screenShareStopFail);
    } else if (audioSharingListenable.value) {
      enableAudioShare(false);
    }

    ///分享结束后，同步会议状态.组件内部处理
    if (arguments.backgroundWidget != null)
      MeetingCore()
          .notifyStatusChange(NEMeetingStatus(NEMeetingEvent.inMeeting));
  }

  Future<bool> ifScreenShareAvailable() async {
    if (isWhiteBoardSharing()) {
      showToast(
          NEMeetingUIKitLocalizations.of(context)!.meetingHasWhiteBoardShare);
      return false;
    }
    if (isOtherScreenSharing()) {
      showToast(NEMeetingUIKitLocalizations.of(context)!.screenShareOverLimit);
      return false;
    }
    // if (await NEMeetingPlugin().phoneStateService.isInCall) {
    //   showToast(NEMeetingUIKitLocalizations.of(context)!.shareOverLimit);
    //   return false;
    // }
    return true;
  }

  Future<void> confirmStartScreenShare() async {
    if (_isMinimized) return;
    if (_meetingState.index >= MeetingState.closing.index) {
      return;
    }

    var tips = arguments.getOptionExtraValue('shareScreenTips');
    if (tips == null || tips.isEmpty) {
      tips = NEMeetingUIKitLocalizations.of(context)!.screenShareTips;
    }
    _isShowOpenScreenShareDialog = true;
    DialogUtils.showShareScreenDialog(
        context, NEMeetingUIKitLocalizations.of(context)!.screenShare, tips,
        () async {
      Navigator.of(context).pop();
      //wait until dialog dismiss
      await Future.delayed(Duration(milliseconds: 250), () {});

      if (!(await ifScreenShareAvailable())) {
        return;
      }

      trackPeriodicEvent(TrackEventName.screenShare,
          extra: {'value': 1, 'meeting_num': arguments.meetingNum});
      if (arguments.backgroundWidget != null) {
        MeetingCore().notifyStatusChange(NEMeetingStatus(
            NEMeetingEvent.inMeeting,
            arg: NEMeetingCode.screenShare));
      }
      final result = await rtcController.startScreenShare(
          iosAppGroup: arguments.iosBroadcastAppGroup);
      if (!mounted) return;
      if (Platform.isAndroid && arguments.backgroundWidget != null) {
        MeetingCore().notifyStatusChange(NEMeetingStatus(
            NEMeetingEvent.inMeeting,
            arg: result.isSuccess()
                ? NEMeetingCode.screenShare
                : NEMeetingCode.undefined));
      }
      if (!result.isSuccess()) {
        commonLogger
            .i('engine startScreenCapture error: ${result.code} ${result.msg}');
        if (result.code == NEErrorCode.screenSharingLimitError) {
          showToast(
              NEMeetingUIKitLocalizations.of(context)!.screenShareOverLimit);
          return;
        } else if (result.code == NEErrorCode.noScreenSharingPermission) {
          showToast(
              NEMeetingUIKitLocalizations.of(context)!.screenShareNoPermission);
          return;
        }
        showToast(result.msg ??
            NEMeetingUIKitLocalizations.of(context)!.screenShareStartFail);
      } else if (arguments.options.enableAudioShare &&
          _isAudioShareSupported()) {
        enableAudioShare(true);
      }
      _isShowOpenScreenShareDialog = false;
    }, _isShowOpenScreenShareDialog);
  }

  ///白板分享模式处理
  Future<void> _onWhiteBoard() async {
    commonLogger.e('onWhiteBoard windowMode=$_windowMode');

    /// 屏幕共享时暂不支持白板共享
    if (rtcController.getScreenSharingUserUuid() != null) {
      showToast(
          NEMeetingUIKitLocalizations.of(context)!.meetingHasScreenShareShare);
      return;
    }

    if (isOtherWhiteBoardSharing()) {
      showToast(NEMeetingUIKitLocalizations.of(context)!.screenShareOverLimit);
      return;
    }

    if (whiteboardController.isSharingWhiteboard()) {
      await _stopWhiteboardShare();
    } else {
      await whiteboardController.updateWhiteboardConfig(
          isTransparent: arguments.isWhiteboardTransparent);
      if (!mounted) return;
      var result = await whiteboardController.startWhiteboardShare();
      if (result.code != MeetingErrorCode.success && mounted) {
        if (result.code == MeetingErrorCode.meetingWBExists) {
          showToast(
              NEMeetingUIKitLocalizations.of(context)!.screenShareOverLimit);
          return;
        }
        showToast(result.msg ??
            NEMeetingUIKitLocalizations.of(context)!.whiteBoardShareStartFail);
      }
    }
  }

  Future<void> _stopWhiteboardShare() async {
    var result = await whiteboardController.stopWhiteboardShare();
    if (!result.isSuccess()) {
      showToast(result.msg ??
          NEMeetingUIKitLocalizations.of(context)!.whiteBoardShareStopFail);
    }
  }

  void _trackMuteVideoEvent(bool mute) {
    trackPeriodicEvent(TrackEventName.switchCamera,
        extra: {'value': mute ? 0 : 1, 'meeting_num': arguments.meetingNum});
  }

  Object? videoActionToken;

  Future<void> _muteMyVideo(bool mute) async {
    if (_isMinimized) return;
    if (mute || roomContext.canUnmuteMyVideo() || _invitingToOpenVideo) {
      _trackMuteVideoEvent(mute);
      _invitingToOpenVideo = false;
      // var enable = await  PermissionHelper.enableLocalVideoAndCheckPermission(context,!mute,arguments.meetingTitle);
      // if(!enable) return;
      final token = Object();
      videoActionToken = token;
      if (mute) {
        rtcController.muteMyVideo().onFailure((code, msg) {
          if (!mounted || videoActionToken != token) return;
          showToast(msg ??
              NEMeetingUIKitLocalizations.of(context)!
                  .participantMuteVideoFail);
        });
      } else {
        rtcController
            .unmuteMyVideoWithCheckPermission(context, arguments.meetingTitle)
            .onFailure((code, msg) {
          if (!mounted || videoActionToken != token) return;
          showToast(msg ??
              NEMeetingUIKitLocalizations.of(context)!
                  .participantUnMuteVideoFail);
        });
      }
    } else {
      if (roomContext.localMember.isRaisingHand) {
        showToast(
            NEMeetingUIKitLocalizations.of(context)!.meetingAlreadyHandsUpTips);
        return;
      }
      final willRaise = await DialogUtils.showCommonDialog(
        context,
        NEMeetingUIKitLocalizations.of(context)!.participantTurnOffVideos,
        NEMeetingUIKitLocalizations.of(context)!
            .participantTurnOffAllVideoHandsUpTips,
        () {
          Navigator.of(context).pop();
        },
        () {
          Navigator.of(context).pop(true);
        },
        acceptText:
            NEMeetingUIKitLocalizations.of(context)!.meetingHandsUpApply,
        contextNotifier: raiseVideoContextNotifier,
      );
      if (!mounted || _isAlreadyCancel) return;
      if (willRaise != true || !arguments.videoMute) return;
      // check again
      if (roomContext.canUnmuteMyVideo()) {
        return;
      }
      trackPeriodicEvent(TrackEventName.handsUp, extra: {
        'value': 1,
        'meeting_num': arguments.meetingNum,
        'type': 'video'
      });
      final result = await roomContext.raiseMyHand();
      showToast(result.isSuccess()
          ? NEMeetingUIKitLocalizations.of(context)!.meetingHandsUpSuccess
          : (result.msg ??
              NEMeetingUIKitLocalizations.of(context)!.meetingHandsUpFail));
    }
  }

  /// 从下往上显示
  void _onMember({_MembersPageType? pageType}) {
    if (_isMinimized) return;
    trackPeriodicEvent(TrackEventName.manageMember,
        extra: {'meeting_num': arguments.meetingNum});
    showMeetingPopupPageRoute(
      context: context,
      builder: (context) => wrapWithWatermark(
        child: MeetMemberPage(
          MembersArguments(
            options: arguments.options,
            roomInfoUpdatedEventStream: roomInfoUpdatedEventStream.stream,
            audioVolumeStreams: audioVolumeStreams,
            roomContext: roomContext,
            meetingTitle: arguments.meetingTitle,
            waitingRoomManager: waitingRoomManager,
            isMySelfManagerListenable: isMySelfManagerListenable,
          ),
          initialPageType: pageType,
          onMemberItemClick: _onMemberItemClick,
        ),
      ),
      routeSettings: RouteSettings(name: 'MeetMemberPage'),
    );
  }

  /// 参会者管理点击成员操作事件处理
  void _onMemberItemClick(dynamic actionType, NEBaseRoomMember user) {
    if (actionType == MemberActionType.chatPrivate ||
        actionType == WaitingRoomMemberActionType.chatPrivate) {
      chatRoomManager.updateSendTarget(newTarget: user, userSelected: true);
      onChat();
    }
  }

  SDKConfig get sdkConfig {
    if (roomContext.isCrossAppJoining) {
      if (crossAppSDKConfig == null) {
        crossAppSDKConfig =
            SDKConfig(roomContext.crossAppAuthorization!.appKey);
        crossAppSDKConfig!.initialize();
      }
      return crossAppSDKConfig!;
    }
    return SDKConfig.current;
  }

  Future<dynamic> _initWithSDKConfig() async {
    void action(dynamic) {
      if (!mounted || _isAlreadyCancel) return;
      _initBeauty();
      _initVirtualBackground();
      focusSwitchInterval = Duration(seconds: sdkConfig.focusSwitchInterval);
      final galleryPageSize = sdkConfig.galleryPageSize;
      if (galleryPageSize != galleryItemSize) {
        setState(() {
          galleryItemSize = galleryPageSize;
        });
      }
    }

    streamSubscriptions.add(sdkConfig.onConfigUpdated.listen(action));
    sdkConfig.initialize().then((value) => action(null));
  }

  bool get isBeautyFuncSupported {
    return sdkConfig.isBeautyFaceSupported;
  }

  bool isBeautyEnabled = false;

  Future<dynamic> _initBeauty() async {
    if (!isBeautyFuncSupported) return;
    var result = await roomContext.rtcController.startBeauty();
    if (result.isSuccess()) {
      isBeautyEnabled = true;
      beautyLevel = await settings.getBeautyFaceValue();
      await setBeautyEffect(beautyLevel);
    } else {
      commonLogger.i('start beauty fail: ${result.msg}');
    }
  }

  bool get isVirtualBackgroundEnabled {
    return sdkConfig.isVirtualBackgroundSupported;
  }

  Future<dynamic> _initVirtualBackground() async {
    if (!isVirtualBackgroundEnabled) return;
    var currentSelected = await settings.getCurrentVirtualBackgroundSelected();
    if (currentSelected != 0) {
      Directory? cache;
      if (Platform.isAndroid) {
        cache = await getExternalStorageDirectory();
      } else {
        cache = await getApplicationDocumentsDirectory();
      }
      var virtualList = await settings.getExternalVirtualBackgrounds();
      var list = await settings.getBuiltinVirtualBackgrounds();
      String source = '';
      //组件传入
      if (list.isNotEmpty) {
        virtualList.forEach((element) {
          list.add(NEMeetingVirtualBackground(element));
        });
        source =
            replaceBundleIdByStr(list[currentSelected - 1].path, cache!.path);
      } else {
        if (currentSelected > virtualListMax) {
          source = replaceBundleIdByStr(
              virtualList[currentSelected - virtualListMax - 1], cache!.path);
        } else {
          source = '${cache?.path}/virtual/$currentSelected.png';
          File file = File(source);
          var exist = await file.exists();
          if (!exist) {
            source = virtualList[currentSelected - 1];
          }
        }
      }
      commonLogger.e('enableVirtualBackground source:$source ');
      if (source != '') {
        rtcController.enableVirtualBackground(
            true,
            NERoomVirtualBackgroundSource(
                backgroundSourceType:
                    NERoomVirtualBackgroundType.kBackgroundImg,
                source: source,
                color: 0,
                blurDegree: NERoomVirtualBackgroundType.kBlurDegreeHigh));
      } else {
        commonLogger.e(
          'enableVirtualBackground virtualList=$virtualList ,currentSelected=$currentSelected',
        );
      }
    }
  }

  void _onBeauty() {
    trackPeriodicEvent(TrackEventName.beauty,
        extra: {'meeting_num': arguments.meetingNum});
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (BuildContext context) => SliderWidget(
              onChange: (value) async {
                beautyLevel = value;
                await Future.delayed(Duration(milliseconds: 200));
                if (beautyLevel == value) {
                  NEMeetingKit.instance
                      .getSettingsService()
                      .setBeautyFaceValue(value);
                  setBeautyEffect(value);
                }
              },
              level: beautyLevel,
            ));
  }

  /// 成员是否正在被呼叫
  bool _memberIsInCalling(String uuid) {
    return arguments.roomContext.inSIPInvitingMembers.any((member) =>
            member.uuid == uuid &&
            member.inviteState == NERoomMemberInviteState.calling) ||
        arguments.roomContext.inAppInvitingMembers.any((member) =>
            member.uuid == uuid &&
            member.inviteState == NERoomMemberInviteState.calling);
  }

  /// 超出会议最大人数
  bool _memberOverMaxCount(int selectedContactsCount) {
    return selectedContactsCount +
            arguments.roomContext.remoteMembers.length +
            arguments.roomContext.inAppInvitingMembers.length +
            arguments.roomContext.inSIPInvitingMembers.length >=
        arguments.roomContext.maxMembers - 1;
  }

  void _onInvite() {
    trackPeriodicEvent(TrackEventName.invite,
        extra: {'meeting_num': arguments.meetingNum});
    if (!isSelfHostOrCoHost() || !roomContext.appInviteController.isSupported) {
      DialogUtils.showInviteDialog(
          context, (context) => _buildInviteInfo(context));
    } else {
      List<NEScheduledMember> scheduledMemberList = [];
      BottomSheetUtils.showInviteModalBottomSheet(
        context,
        meetingUiLocalizations.meetingInvite,
        onInviteContact: () {
          showMeetingPopupPageRoute(
            context: context,
            routeSettings: RouteSettings(name: 'MeetingInviteContact'),
            builder: (context) => ContactsAddPopup(
              titleBuilder: (int size) =>
                  '${meetingUiLocalizations.meetingInvitePageTitle}${size > 0 ? '( ${size.toString()})' : ''}',
              scheduledMemberList: scheduledMemberList,
              myUserUuid: roomContext.localMember.uuid,
              itemClickCallback: (NEContact contact, int currentSelectedSize,
                  String? currentMaxSizeTip) {
                if (contact.userUuid == roomContext.localMember.uuid) {
                  ToastUtils.showToast(
                      context, meetingUiLocalizations.sipCallIsInMeeting);
                  return false;
                }
                if (arguments.roomContext.remoteMembers
                    .any((member) => member.uuid == contact.userUuid)) {
                  /// 已经在房间中的用户不允许再次呼叫
                  ToastUtils.showToast(
                      context, meetingUiLocalizations.sipCallIsInMeeting);
                  return false;
                }

                if (_memberIsInCalling(contact.userUuid)) {
                  /// 已经在呼叫中的用户不允许再次呼叫
                  ToastUtils.showToast(
                      context, meetingUiLocalizations.sipCallIsInInviting);
                  return false;
                }

                /// 选择人数超限
                if (_memberOverMaxCount(currentSelectedSize)) {
                  ToastUtils.showToast(context, currentMaxSizeTip!);
                  return false;
                }
                return true;
              },
            ),
          ).then((value) {
            if (scheduledMemberList.isNotEmpty) {
              roomContext.appInviteController
                  .callByUserUuids(
                      scheduledMemberList.map((e) => e.userUuid).toList())
                  .then((value) => {
                        if (!value.isSuccess())
                          {
                            handleInviteCodeError(
                                context, value.code, meetingUiLocalizations)
                          }
                      });
            }
          });
        },
        inviteContactTitle: meetingUiLocalizations.meetingInvitePageTitle,
        onInviteLinkInfo: () {
          DialogUtils.showInviteDialog(
              context, (context) => _buildInviteInfo(context));
        },
        linkInfoTitle: meetingUiLocalizations.meetingCopyInvite,
        cancelTitle: NEMeetingUIKitLocalizations.of(context)!.globalCancel,
      );
    }
  }

  String _buildInviteInfo(BuildContext context) {
    final localizations = NEMeetingUIKitLocalizations.of(context)!;
    var info = '${localizations.meetingInviteTitle}\n\n';

    final meetingInfo = arguments.meetingInfo;
    info += '${localizations.meetingSubject} ${meetingInfo.subject}\n';
    if (meetingInfo.type == NEMeetingType.kReservation) {
      info +=
          '${localizations.meetingTime} ${meetingInfo.startTime.formatToTimeString('yyyy/MM/dd HH:mm')} - ${meetingInfo.endTime.formatToTimeString('yyyy/MM/dd HH:mm')}\n';
    }

    info += '\n';
    if (!arguments.options.isShortMeetingIdEnabled ||
        TextUtils.isEmpty(meetingInfo.shortMeetingNum)) {
      info +=
          '${localizations.meetingNum} ${meetingInfo.meetingNum.toMeetingNumFormat()}\n';
    } else if (!arguments.options.isLongMeetingIdEnabled) {
      info += '${localizations.meetingNum} ${meetingInfo.shortMeetingNum}\n';
    } else {
      info +=
          '${localizations.meetingShortNum} ${meetingInfo.shortMeetingNum}(${localizations.meetingInternalSpecial})\n';
      info +=
          '${localizations.meetingNum} ${meetingInfo.meetingNum.toMeetingNumFormat()}\n';
    }
    if (roomContext.isGuestJoinEnabled) {
      info += '${localizations.meetingGuestJoinSupported}\n';
    }
    if (!TextUtils.isEmpty(roomContext.password)) {
      info += '${localizations.meetingPassword} ${roomContext.password}\n';
    }
    if (!TextUtils.isEmpty(roomContext.sipCid)) {
      info += '\n';
      info += '${localizations.meetingSipNumber} ${roomContext.sipCid}\n';
    }
    if (!TextUtils.isEmpty(meetingInfo.inviteUrl)) {
      info += '\n';
      info += '${localizations.meetingInviteUrl} ${meetingInfo.inviteUrl}\n';
    }
    return info;
  }

  Widget buildBigNameView(NERoomMember user) {
    return Container(
      color: _UIColors.grey_292933,
      child: Center(
        child: SizedBox(
          width: 100,
          child: buildAudioModeUserItem(user),
        ),
      ),
    );
  }

  Widget buildSmallNameView(NERoomMember user, bool isInCall,
      {bool showInCallTip = true}) {
    return Container(
      color: _UIColors.color_292933,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              _buildMeetingInviteWrapper(
                  child: NEMeetingAvatar.xlarge(
                    name: user.name,
                    url: user.avatar,
                  ),
                  user: user),
              if (isInCall)
                CircleAvatar(
                  backgroundColor: Colors.black54,
                  radius: 24,
                  child: Icon(
                    Icons.phone,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
          if (showInCallTip) ...[
            SizedBox(
              height: 4,
            ),
            Visibility.maintain(
              visible: isInCall,
              child: Text(
                NEMeetingUIKitLocalizations.of(context)!.meetingIsInCall,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  color: _UIColors.color_999999,
                  decoration: TextDecoration.none,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<NERoomMember> getUserListByPage(int page) {
    assert(page >= 0);
    var temp = userList.toList();
    if (!roomContext.isFollowHostVideoOrderOn()) {
      // 如果不是跟随主持人视频顺序，调整本地成员位置至第一个位置
      temp
        ..remove(roomContext.localMember)
        ..insert(0, roomContext.localMember);
    }
    final pageSize = currentGridLayout.pageSize;
    int start = pageSize * page;
    if (start >= temp.length) {
      return [];
    }
    return temp.sublist(start, min(start + pageSize, temp.length));
  }

  bool isHost() {
    return roomContext.isMySelfHost();
  }

  /// 自己是否是主持人或者联席主持人
  bool isSelfHostOrCoHost() {
    return isHost() || isSelfCoHost();
  }

  /// 自己是否是联席主持人
  bool isSelfCoHost() {
    return roomContext.isMySelfCoHost();
  }

  /// 是否是联席主持人
  bool isCoHost(String? uuid) {
    return roomContext.isCoHost(uuid);
  }

  /// [uuid] 是否是主持人或者联席主持人
  bool isHostOrCoHost(String? uuid) {
    return roomContext.isHostOrCoHost(uuid);
  }

  void handleWaitingRoomMemberJoin(NEWaitingRoomMember member, int reason) {
    commonLogger.i(
      'handleWaitingRoomMemberJoin: member=$member, reason=$reason',
    );
    _updateWaitingRoomCountTip(MeetingNotifyDialogCountTipType.show);
  }

  Future<void> navigateToWaitingRoom({NERoomContext? roomContext}) async {
    /// 清理当前界面不在meeting_page.dart的情况
    Navigator.popUntil(context, ModalRoute.withName(_RouterName.inMeeting));
    closeCloudRecordingStartedDialog();
    closeCloudRecordingStoppedDialog();

    /// 重置扬声器选择状态为开启
    rtcController.setSpeakerphoneOn(true);

    /// 路由到等候室页面
    final floating = NEMeetingPlugin().getFloatingService();
    final _initialIsInPIPView =
        Platform.isIOS && _isMinimized && arguments.backgroundWidget == null ||
            await floating.pipStatus == PiPStatus.enabled;
    meetingNavigator.navigateToWaitingRoomFromInMeeting(
      arguments: arguments.copyWith(
        roomContext: roomContext,
        initialAudioMute: arguments.audioMute,
        initialVideoMute: arguments.videoMute,
        initialIsInPIPView: _initialIsInPIPView,
      ),
    );
  }

  void _onCancel({int exitCode = 0, String? reason = ''}) async {
    if (_isAlreadyCancel) return;
    _currentExitCode = exitCode;
    _currentReason = reason;
    if (_isMinimized &&
        (arguments.backgroundWidget == null || await floating.isInPipMode())) {
      setState(() {
        _isAlreadyMeetingDisposeInMinimized = true;
      });
      return;
    }
    commonLogger.i(
      '_onCancel exitCode=$exitCode ,reason=$reason',
    );
    if (_meetingState.index < MeetingState.joined.index) {
      showToast(NEMeetingUIKitLocalizations.of(context)!.meetingJoinFail);
    }
    _meetingState = MeetingState.closed;
    _dispose();
    _isAlreadyCancel = true;
    meetingNavigator.pop(disconnectingCode: _currentExitCode);
  }

  void _dispose() {
    if (_isAlreadyCancel) {
      return;
    }
    NEMeetingPlugin().volumeController.removeListener();
    iOSDisposePIP();
    networkTaskExecutor.dispose();
    NERoomKit.instance.messageChannelService
        .removeMessageChannelCallback(messageCallback);
    roomContext.removeEventCallback(roomEventCallback);
    roomContext.removeRtcStatsCallback(roomStatsCallback);
    _galleryModePageController?.removeListener(_handleGalleryModePageChange);
    _galleryModePageController?.dispose();
    _galleryModePageController = null;
    userVideoStreamSubscriber.dispose();
    roomInfoUpdatedEventStream.close();
    _waitingRoomManager?.dispose();
    waitingRoomManager.dispose();
    _chatRoomManager?.dispose();
    webAppListUpdatedEventStream.close();
    restorePreferredOrientations();
    InMeetingService()
      .._updateHistoryMeetingItem(historyMeetingItem)
      .._minimizeDelegate = null
      .._audioDelegate = null
      .._menuItemDelegate = null;
    joinTimeOut?.cancel();
    muteDetectStartedTimer?.cancel();
    streamSubscriptions.forEach((subscription) {
      subscription.cancel();
    });
    _unlistenStreams();
    cancelInComingTips();
    if (Platform.isAndroid) {
      NEMeetingPlugin().getNotificationService().stopForegroundService();
      NEMeetingPlugin().audioService.stop();
    }
    if (!_appBarAnimControllerDisposed) {
      appBarAnimController.dispose();
      _appBarAnimControllerDisposed = true;
    }
    activeSpeakerManager?.dispose();
    audioVolumeStreams.forEach((key, value) {
      value.close();
    });
    crossAppSDKConfig?.dispose();

    /// 清空 Map 中的所有对象引用
    _userAspectRatioMap.clear();
    NEMeetingKit.instance.removeReceiveSessionMessageListener(this);
  }

  void restorePreferredOrientations() {
    if (arguments.restorePreferredOrientations != null) {
      SystemChrome.setPreferredOrientations(
          [...arguments.restorePreferredOrientations!]);
    }
  }

  late final _screenShareController = TransformationController();
  bool _screenShareInteractionTipShown = false;
  int _screenShareWidth = 0, _screenShareHeight = 0;
  Orientation? _screenOrientation;

  void _showScreenShareInteractionTip() {
    if (!_screenShareInteractionTipShown && !_isMinimized) {
      _screenShareInteractionTipShown = true;
      showToast(
          NEMeetingUIKitLocalizations.of(context)!.screenShareInteractionTip);
    }
  }

  ValueNotifier<bool> get screenShareListenable {
    _screenShareListenable ??= ValueNotifier(isSelfScreenSharing());
    return _screenShareListenable!;
  }

  ValueNotifier<bool> get whiteBoardShareListenable {
    _whiteBoardShareListenable ??= ValueNotifier(isSelfWhiteBoardSharing());
    return _whiteBoardShareListenable!;
  }

  ValueNotifier<bool> get cloudRecordListenable {
    _cloudRecordListenable ??= ValueNotifier(roomContext.isCloudRecording);
    return _cloudRecordListenable!;
  }

  ValueNotifier<_CloudRecordState> get cloudRecordStateListenable {
    _cloudRecordStateListenable ??= ValueNotifier(roomContext.isCloudRecording
        ? _CloudRecordState.started
        : _CloudRecordState.notStarted);
    return _cloudRecordStateListenable!;
  }

  ValueNotifier<bool> get audioConnectListenable {
    _audioConnectStateListenable ??=
        ValueNotifier(roomContext.localMember.isAudioConnected);
    return _audioConnectStateListenable!;
  }

  void memberNameChanged(
      NERoomMember member, String name, NERoomMember? operateBy) {
    if (isSelf(member.uuid)) {
      historyMeetingItem?.nickname = name;
      InMeetingService()._updateHistoryMeetingItem(historyMeetingItem);
      if (mounted && operateBy?.uuid != roomContext.localMember.uuid) {
        showToast(NEMeetingUIKitLocalizations.of(context)!
            .meetingHostChangeYourMeetingName);
      }
    }
    _onRoomInfoChanged();
  }

  void chatroomMessagesReceived(List<NERoomChatMessage> message) {
    /// 普通观众过滤等候室消息
    if (!isSelfHostOrCoHost()) {
      message = message.where((element) {
        return element.chatroomType != NEChatroomType.waitingRoom;
      }).toList();
    }
    message.forEach((msg) {
      if (_messageSource.handleReceivedMessage(msg)) {
        if (ModalRoute.of(context)!.isCurrent) {
          showInComingMessage(msg);
        }
      } else {
        commonLogger.i(
            'chatroomMessagesReceived: unsupported message type of ${msg.runtimeType}');
      }
    });
  }

  void memberAudioMuteChanged(
      NERoomMember member, bool mute, NERoomMember? operator) {
    if (roomContext.isInWaitingRoom()) return;
    if (isSelf(member.uuid)) {
      arguments.audioMute = mute;

      /// 老版本会对成员直接进行mute的操作，新版本不会
      if (!member.isAudioConnected) {
        /// 音频断开的情况下要记录静音状态，以便在音频恢复时恢复
        _shouldUnmuteAfterAudioConnect = !mute;
      } else {
        if (mute && !isSelf(operator?.uuid) && isHostOrCoHost(operator?.uuid)) {
          showToast(NEMeetingUIKitLocalizations.of(context)!
              .participantHostMuteAudio);
        }
        if (!mute && member.isRaisingHand && roomContext.isAllAudioMuted) {
          /// roomContext.isAllAudioMuted 增加这个判断是为了 如果视频开启全体关闭 用户举手，而此时用户自行打开音频的时候，手会放下的异常
          roomContext.lowerMyHand();
          showToast(NEMeetingUIKitLocalizations.of(context)!
              .participantMuteAudioHandsUpOnTips);
        }
      }

      if (!mute) {
        startAndroidForegroundService(forMicrophone: true);
      }
    }
    if (speakingUid == member.uuid && mute) {
      speakingUid = null;
    }
    _onRoomInfoChanged();
    iOSMemberAudioChange(member.uuid, member.isAudioOn);
  }

  Future<void> showOpenMicDialog() async {
    if (_isMinimized) return;
    if (!_isShowOpenMicroDialog) {
      _isShowOpenMicroDialog = true;
      final agree = await DialogUtils.showOpenAudioDialog(
          context,
          NEMeetingUIKitLocalizations.of(context)!.participantOpenMicrophone,
          NEMeetingUIKitLocalizations.of(context)!.participantHostOpenMicroTips,
          () {
        Navigator.of(context).pop();
      }, () {
        Navigator.of(context).pop(true);
      });
      if (!mounted || _isAlreadyCancel) return;
      _isShowOpenMicroDialog = false;
      if (agree == true && arguments.audioMute) {
        await _muteMyAudio(false);
      }
    }
  }

  Future<void> showOpenVideoDialog() async {
    if (_isMinimized) return;
    if (!_isShowOpenVideoDialog) {
      _isShowOpenVideoDialog = true;
      final agree = await DialogUtils.showOpenVideoDialog(
          context,
          NEMeetingUIKitLocalizations.of(context)!.participantOpenCamera,
          NEMeetingUIKitLocalizations.of(context)!
              .participantHostOpenCameraTips, () {
        Navigator.of(context).pop(false);
      }, () {
        Navigator.of(context).pop(true);
      });
      if (!mounted || _isAlreadyCancel) return;
      _isShowOpenVideoDialog = false;
      if (agree == true && arguments.videoMute) {
        await _muteMyVideo(false);
      }
    }
  }

  void memberVideoMuteChanged(
      NERoomMember member, bool mute, NERoomMember? operator) async {
    if (roomContext.isInWaitingRoom()) return;
    if (roomContext.isMySelf(member.uuid)) {
      if (mute && !isSelf(operator?.uuid) && isHostOrCoHost(operator?.uuid)) {
        showToast(
            NEMeetingUIKitLocalizations.of(context)!.participantHostMuteVideo);
      }
      if (!mute && member.isRaisingHand && roomContext.isAllVideoMuted) {
        ///  roomContext.isAllVideoMuted 增加这个判断是为了 如果音频开启全体静音 用户举手，而此时用户自行打开视频的时候，手会放下的异常
        roomContext.lowerMyHand();
      }
      arguments.videoMute = mute;
    }
    _onRoomInfoChanged();
    iOSMemberVideoChange(member.uuid, member.isVideoOn);
  }

  void memberRoleChanged(
      NERoomMember member, NERoomRole before, NERoomRole after) {
    if (isSelf(member.uuid)) {
      isMySelfHostListenable.value = isHost();
      isMySelfManagerListenable.value = isSelfHostOrCoHost();

      /// 角色变更的用户是自己
      waitingRoomManager.reset();
      _updateMemberTotalCount();
      if (isHost() || isSelfCoHost()) {
        /// 被设置为主持人、联席主持人
        if (member.isRaisingHand) {
          roomContext.lowerMyHand();
        }
        showToast(isHost()
            ? meetingUiLocalizations.participantAssignedHost
            : meetingUiLocalizations.participantAssignedCoHost);
      } else if (before.name == MeetingRoles.kCohost &&
          after.name == MeetingRoles.kMember) {
        /// 被取消联席主持人
        showToast(meetingUiLocalizations.participantUnassignedCoHost);
        _updateWaitingRoomCountTip(MeetingNotifyDialogCountTipType.hide);
      } else if (before.name == MeetingRoles.kHost &&
          after.name == MeetingRoles.kMember) {
        _updateWaitingRoomCountTip(MeetingNotifyDialogCountTipType.hide);
        ensureNewHostActive();
      }
    }
    _onRoomInfoChanged();
  }

  /// 被收回主持人、转移主持人后，确保新的主持人生效
  /// 事件可能乱序到达，需要延迟等待新主持人生效
  void ensureNewHostActive() async {
    for (var i = 0; i < 3; i++) {
      final nowHost = roomContext.getHostMember(refresh: true);
      if (nowHost == null) {
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) break;
      } else {
        showToast(meetingUiLocalizations.meetingUserIsNowTheHost(nowHost.name));
      }
    }
  }

  @override
  void dispose() {
    assert(() {
      // debugPrintScheduleBuildForStacks = false;
      debugPrintRebuildDirtyWidgets = false;
      debugRepaintTextRainbowEnabled = debugRepaintRainbowEnabled = false;
      return true;
    }());
    _dispose();
    _isAlreadyCancel = true;
    PaintingBinding.instance.imageCache.clear();
    //FilePicker.platform.clearTemporaryFiles();
    super.dispose();
  }

  /// 被踢出, 没有操作3秒自动退出
  void onKicked() {
    commonLogger.i('onKicked');
    _currentExitCode = NEMeetingCode.removedByHost;
    _currentReason =
        NEMeetingUIKitLocalizations.of(context)?.meetingRemovedByHost;
    if (_isMinimized) {
      setState(() {
        _isAlreadyMeetingDisposeInMinimized = true;
      });
      return;
    }
    showKickedDialog(context);
  }

  void showKickedDialog(BuildContext context) {
    VoidCallback onTimeout = () {
      if (!mounted) return;
      _onCancel(
          reason: NEMeetingUIKitLocalizations.of(context)?.meetingRemovedByHost,
          exitCode: NEMeetingCode.removedByHost);
    };
    final countDown = Timer(const Duration(seconds: 3), onTimeout);
    DialogUtils.showChildNavigatorDialog(
      context,
      (context) => CupertinoAlertDialog(
        title:
            Text(NEMeetingUIKitLocalizations.of(context)!.meetingBeKickedOut),
        content: Text(
            NEMeetingUIKitLocalizations.of(context)!.meetingBeKickedOutByHost),
        actions: <Widget>[
          CupertinoDialogAction(
              child: Text(
                NEMeetingUIKitLocalizations.of(context)!.globalClose,
                key: MeetingUIValueKeys.closeMeetingNotification,
              ),
              onPressed: () {
                countDown.cancel();
                onTimeout();
              })
        ],
      ),
      routeSettings: RouteSettings(name: 'KickedOutDialog'),
    );
  }

  void initChatRoom() async {
    if (!arguments.noChat && chatController.isSupported) {
      chatRoomManager.hasJoinInMeetingChatroom =
          () => meetingUIState.inMeetingChatroom.hasJoin;
      chatRoomManager.hasJoinWaitingRoomChatroom =
          () => meetingUIState.waitingRoomChatroom.hasJoin;
      _messageSource
        ..inMeetingChatroomJoined =
            meetingUIState.inMeetingChatroom.ensureJoined
        ..waitingRoomChatroomJoined =
            meetingUIState.waitingRoomChatroom.ensureJoined;

      meetingUIState.inMeetingChatroom.join().then((result) {
        if (!result.isSuccess() &&
            result.code != NEMeetingErrorCode.chatroomNotExists) {
          showToast(NEMeetingUIKitLocalizations.of(context)!.chatJoinFail);
        }
      });
      if (isSelfHostOrCoHost() &&
          roomContext.waitingRoomController.isSupported) {
        meetingUIState.waitingRoomChatroom.join();
      }
      isMySelfManagerListenable.addListener(() {
        if (isSelfHostOrCoHost() &&
            roomContext.waitingRoomController.isSupported) {
          meetingUIState.waitingRoomChatroom.join();
        } else {
          meetingUIState.waitingRoomChatroom.leave();
        }
      });
    }
  }

  /// 提示聊天室接受消息
  void showInComingMessage(NERoomChatMessage chatRoomMessage) {
    if (_isMinimized) return;
    // 聊天菜单不显示时，不出现聊天气泡
    if (!_isMenuItemShowing(NEMenuIDs.chatroom)) {
      return;
    }

    String? content;
    if (chatRoomMessage is NERoomChatTextMessage) {
      content = chatRoomMessage.text;
    } else if (chatRoomMessage is NERoomChatImageMessage) {
      content = NEMeetingUIKitLocalizations.of(context)!.chatImageMessageTip;
    } else if (chatRoomMessage is NERoomChatFileMessage) {
      content = NEMeetingUIKitLocalizations.of(context)!.chatFileMessageTip;
    }
    if (content == null) {
      return;
    }

    cancelInComingTips();
    _overlayEntry = OverlayEntry(builder: (context) {
      /// 宽度为屏幕宽度减去24后的3/4
      final width = (MediaQuery.of(context).size.width - 24) * 3 / 4;
      return SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomLeft,
          child: GestureDetector(
              onTap: onChat,
              child: AnimatedBuilder(
                animation: incomingMessageAnim,
                builder: (context, child) => Container(
                    margin: EdgeInsets.only(
                        bottom: incomingMessageAnim.value + 16, left: 12),
                    padding: EdgeInsets.all(12),
                    decoration: ShapeDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              _UIColors.grey_292933,
                              _UIColors.color_212129
                            ]),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8))),
                    width: width,
                    child: Row(children: <Widget>[
                      NEMeetingAvatar.medium(
                        name: chatRoomMessage.fromNick,
                        url: chatRoomMessage.fromAvatar,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                            buildMessageFrom(chatRoomMessage),
                            SizedBox(height: 3),
                            buildContent(content)
                          ]))
                    ])),
              )),
        ),
      );
    });
    Overlay.of(context).insert(_overlayEntry!);
    _inComingTipsTimer = Timer(const Duration(seconds: 5), () {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  void cancelInComingTips() {
    _inComingTipsTimer?.cancel();
    _inComingTipsTimer = null;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  /// 收到新消息，显示消息来源
  Widget buildMessageFrom(NERoomChatMessage message) {
    final meetingUiLocalizations = NEMeetingUIKitLocalizations.of(context)!;
    String? from;
    if (message.isPrivateMessage) {
      from = meetingUiLocalizations.chatSaidToMe('');
    } else if (message.chatroomType == NEChatroomType.waitingRoom) {
      from = meetingUiLocalizations.chatSaidToWaitingRoom('');
    }
    final style = TextStyle(
      color: _UIColors.greyCCCCCC,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      decoration: TextDecoration.none,
    );
    final name = Text(
      message.fromNick,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
    return Row(
      children: [
        /// 私聊类型，名字的最大宽度60
        if (message.isPrivateMessage)
          Container(
            constraints: BoxConstraints(maxWidth: 60),
            child: name,
          )
        else
          Flexible(child: name),
        if (from != null)
          Text(
            from,
            maxLines: 1,
            style: style,
          ),
        if (message.isPrivateMessage)
          Flexible(child: buildMessageType(message)),
      ],
    );
  }

  Widget buildMessageType(NERoomChatMessage message) {
    final meetingUiLocalizations = NEMeetingUIKitLocalizations.of(context)!;
    final text = message.chatroomType == NEChatroomType.waitingRoom
        ? meetingUiLocalizations.chatPrivateInWaitingRoom
        : meetingUiLocalizations.chatPrivate;
    return Text(
      '($text)',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: _UIColors.color_337eff,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        decoration: TextDecoration.none,
      ),
    );
  }

  Widget buildContent(String? content) {
    return Text(
      content ?? '',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
          color: _UIColors.white,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          decoration: TextDecoration.none),
    );
  }

  void _onSwitchLoudspeaker() async {
    final targetDevice = isEarpiece()
        ? NEAudioOutputDevice.kSpeakerPhone
        : NEAudioOutputDevice.kEarpiece;
    if (Platform.isAndroid && isAudioDeviceSwitchEnabled) {
      commonLogger.i('selectAudioDevice: $targetDevice');
      NEMeetingPlugin().audioService.selectAudioDevice(targetDevice);
    } else {
      rtcController
          .setSpeakerphoneOn(targetDevice == NEAudioOutputDevice.kSpeakerPhone);
    }
  }

  void _onSwitchCamera() async {
    final result = await rtcController.switchCamera();
    if (result.isSuccess()) {
      if (!arguments.options.enableFrontCameraMirror) return;
      bool current = localMirrorState.value;
      localMirrorState.value = !current;
    }
  }

  Widget _onNetworkView(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            alignment: Alignment.topRight,
            margin: EdgeInsets.only(top: appBarHeight - 12, right: 50),
            child: SafeArea(
              child: getNetworkInfoBuilder(context),
            ),
          )),
    );
  }

  Future<PiPStatus> enablePip(
      BuildContext context, Rational aspectRatio) async {
    // if (!arguments.enablePictureInPicture) {
    //   commonLogger.i('in background enablePip  false');
    //   return;
    // }
    // final rational = Rational.landscape();
    final screenSize =
        MediaQuery.of(context).size * MediaQuery.of(context).devicePixelRatio;
    final height = screenSize.width ~/ aspectRatio.aspectRatio;

    final status = await floating.enable(
      aspectRatio: aspectRatio,
      sourceRectHint: Rectangle<int>(
        0,
        (screenSize.height ~/ 2) - (height ~/ 2),
        screenSize.width.toInt(),
        height,
      ),
    );
    debugPrint('PiP enabled? $status');
    return status;
  }

  void _onNetworkInfo() {
    dialogRoute = DialogRoute(
      context: context,
      builder: (context) {
        return _onNetworkView(context);
      },
      barrierColor: Colors.transparent,
    );
    Navigator.of(context).push(dialogRoute!);
  }

  Widget getNetworkInfoBuilder(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: meetingNetworkInfoListenable,
      builder: (BuildContext context, NetWorkRttInfo value, Widget? child) {
        return showNetworkInfo(context, value);
      },
    );
  }

  Widget showNetworkInfo(BuildContext context, NetWorkRttInfo value) {
    double position = 34;
    return Container(
        child: IntrinsicWidth(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
          Align(
            alignment: Alignment.topRight,
            child: Container(
                margin: EdgeInsets.only(right: position),
                child: Image.asset(NEMeetingImages.arrow,
                    package: NEMeetingImages.package)),
          ),
          Align(
              alignment: Alignment.centerRight,
              child: Container(
                  padding: EdgeInsets.all(12),
                  constraints: BoxConstraints(minWidth: 140),
                  decoration: ShapeDecoration(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      color: Colors.white),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(getNetworkStatusDesc(_networkStats.value),
                          textAlign: TextAlign.left,
                          style: TextStyle(
                              fontSize: 16,
                              decoration: TextDecoration.none,
                              fontWeight: FontWeight.bold,
                              color: _UIColors.black)),
                      SizedBox(height: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                              NEMeetingUIKitLocalizations.of(context)!
                                      .networkLocalLatency +
                                  ":",
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                  fontSize: 14,
                                  decoration: TextDecoration.none,
                                  fontWeight: FontWeight.w400,
                                  color: _UIColors.black)),
                          Expanded(child: SizedBox()),
                          Text(value.networkDownRtt.toString() + "ms",
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 14,
                                  decoration: TextDecoration.none,
                                  fontWeight: FontWeight.w400,
                                  color: _UIColors.black))
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                                NEMeetingUIKitLocalizations.of(context)!
                                        .networkPacketLossRate +
                                    ":",
                                textAlign: TextAlign.left,
                                style: TextStyle(
                                    fontSize: 14,
                                    decoration: TextDecoration.none,
                                    fontWeight: FontWeight.w400,
                                    color: _UIColors.black)),
                            Expanded(child: SizedBox()),
                            Container(
                              padding: EdgeInsets.only(top: 2),
                              child: Column(
                                children: <Widget>[
                                  Row(children: [
                                    Icon(Icons.arrow_upward,
                                        color: Colors.green, size: 16.0),
                                    Text(value.upLossRate.toString() + '%',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                            fontSize: 14,
                                            decoration: TextDecoration.none,
                                            fontWeight: FontWeight.w400,
                                            color: _UIColors.black))
                                  ]),
                                  SizedBox(height: 8),
                                  Row(children: [
                                    Icon(
                                      Icons.arrow_downward,
                                      color: Colors.blue,
                                      size: 16.0,
                                    ),
                                    Text(value.downLossRate.toString() + '%',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                            fontSize: 14,
                                            decoration: TextDecoration.none,
                                            fontWeight: FontWeight.w400,
                                            color: _UIColors.black)),
                                  ])
                                ],
                              ),
                            )
                          ]),
                    ],
                  ))),
        ])));
  }

  //成员进入房间 跟[onRoomUserJoin]逻辑保持一致
  void memberJoinRoom(List<NERoomMember> userList) {
    for (var user in userList) {
      if (isSelfHostOrCoHost() && user.isVisible) {
        showToast(NEMeetingUIKitLocalizations.of(context)!
            .meetingUserJoin(user.name));
      }
      // if (isVisible && autoSubscribeAudio) {
      //   inRoomService.getInRoomAudioController().subscribeRemoteAudioStream(user.userId);
      // }
      audioVolumeStreams.putIfAbsent(
          user.uuid, () => StreamController<int>.broadcast());
    }
    onMemberInOrOut();
  }

  // 成员离开房间 与[onRoomUserLeave] 一致
  void memberLeaveRoom(List<NERoomMember> userList) {
    userList.forEach((user) {
      trackPeriodicEvent(TrackEventName.memberLeaveMeeting, extra: {
        'member_uid': user.uuid,
        'meeting_num': arguments.meetingNum
      });
      commonLogger.i('onUserLeave ${user.name}');
      if (isSelfHostOrCoHost() &&
          user.isVisible &&
          !user.isInSIPInviting &&
          !user.isInAppInviting) {
        showToast(NEMeetingUIKitLocalizations.of(context)!
            .meetingUserLeave(user.name));
      }
      if (activeUid == user.uuid) {
        activeUid = null;
      }
      audioVolumeStreams.remove(user.uuid)?.close();
    });
    onMemberInOrOut();
    if (!roomContext.localMember.isVisible && userCount == 0) {
      commonLogger.i('No other members in meeting, leave meeting');
      roomContext.leaveRoom();
      return;
    }
  }

  void handleActiveSpeakerListChanged(List<String> activeSpeakers) {
    final oldSpeakingUid = speakingUid;
    final oldActiveUserId = activeUid;
    speakingUid = activeUid = activeSpeakers.firstOrNull;
    if (oldActiveUserId != activeUid || oldSpeakingUid != speakingUid) {
      setState(() {});
    }
  }

  void _onRoomInfoChanged() {
    _meetingMemberCount.value = userCount;
    if (!roomInfoUpdatedEventStream.isClosed) {
      roomInfoUpdatedEventStream.add(const Object());
    }
    if (_isAppInBackground && Platform.isIOS) {
      determineBigSmallUser();
    }
    setState(() {});
  }

  void swapBigSmallUid() {
    commonLogger.i('swapBigSmallUid $switchBigAndSmall');
    if (bigUid != null && smallUid != null) {
      var temp = bigUid;
      bigUid = smallUid;
      smallUid = temp;
    } else {
      /// 只有一个大画面了, 退回切换
      switchBigAndSmall = false;
    }
  }

  bool _isSwitchBigSmallViewsEnable() {
    // 共享情况下，小画面不允许切换
    if (isOtherScreenSharing() ||
        isSelfScreenSharing() ||
        roomContext.getFocusUuid() != null ||
        isWhiteBoardSharing()) return false;
    return true;
  }

  void determineBigSmallUser() {
    final oldFocus = focusUid;
    final oldActive = activeUid;
    final oldBig = bigUid;
    final oldSmall = smallUid;
    final localLockedUser = meetingUIState.lockedUser;

    final users = userList.toList();
    if (users.length == 1) {
      // 特殊处理 房间只有我
      bigUid = users.first.uuid;
      smallUid = null;
    } else if (users.length >= 2) {
      final screenSharingUid = getScreenShareUserId();
      final selfUid = roomContext.localMember.uuid;
      // 别人在共享屏幕，则大屏是共享内容画面，小屏是共享者画面
      if (screenSharingUid != null && selfUid != screenSharingUid) {
        bigUid = null;
        smallUid = screenSharingUid;
      } else if (focusUid != null || localLockedUser != null) {
        // 房间有其他人
        // 有focus big可以确定, 如果焦点是自己因此大画面是自己， 小画面选择一个， 否则小画面是自己
        bigUid = focusUid ?? localLockedUser;
        smallUid = bigUid == selfUid ? _pickRoomUid(users) : selfUid;
        if (bigUid == oldSmall || smallUid == oldBig || oldSmall == null) {
          switchBigAndSmall = !switchBigAndSmall;
        }
      } else {
        // 开始计算big，无focus，右下角肯定是自己，small可以确定是自己
        bigUid = _pickRoomUid(users);
        smallUid = selfUid;
        if (switchBigAndSmall) {
          swapBigSmallUid();
        }
      }
    }
    iOSUpdatePIPVideo(bigUid ?? '');
    if (oldFocus != focusUid ||
        oldActive != activeUid ||
        oldBig != bigUid ||
        oldSmall != smallUid) {
      commonLogger.i(
          'BigSmall: focus=$focusUid locked=$localLockedUser active=$activeUid big=$bigUid small=$smallUid');
    }
    updatePIPAspectRatio();
  }

  String _pickRoomUid(Iterable<NERoomMember> users) {
    // active > host > joined
    if (activeUid != null) {
      return activeUid!;
    }
    final hostUid = roomContext.getHostUuid();
    if (!roomContext.isMySelfHost() && roomContext.getMember(hostUid) != null) {
      // 主持人在这个会议中
      return hostUid!;
    }
    String? userId;
    for (var user in users) {
      if (!isSelf(user.uuid)) {
        userId ??= user.uuid;
        if (user.canRenderVideo) {
          return user.uuid;
        }
      }
    }
    return userId!;
  }

  void onRtcAudioOutputDeviceChanged(NEAudioOutputDevice selected) async {
    commonLogger.i('onRtcAudioOutputDeviceChanged selected=$selected');
    if (Platform.isAndroid && isAudioDeviceSwitchEnabled) return;
    _audioDeviceSelected.value = selected;
  }

  void onRtcVirtualBackgroundSourceEnabled(bool enabled, int reason) {
    commonLogger.i(
        'onRtcVirtualBackgroundSourceEnabled enabled=$enabled,reason:$reason');

    /// 预览虚拟背景不进行提示
    if (!isPreviewVirtualBackground) return;
    switch (reason) {
      case NERoomVirtualBackgroundSourceStateReason.kImageNotExist:
        showToast(NEMeetingUIKitLocalizations.of(context)!
            .virtualBackgroundImageNotExist);
        break;
      case NERoomVirtualBackgroundSourceStateReason.kImageFormatNotSupported:
        showToast(NEMeetingUIKitLocalizations.of(context)!
            .virtualBackgroundImageFormatNotSupported);
        break;
      case NERoomVirtualBackgroundSourceStateReason.kDeviceNotSupported:
        showToast(NEMeetingUIKitLocalizations.of(context)!
            .virtualBackgroundImageDeviceNotSupported);
        break;
    }
  }

  void onRoomDurationRenewed(int remainingSeconds) {
    _remainingSeconds.value = remainingSeconds;
  }

  void onRoomConnectStateChanged(int state) {
    if (state == NEMeetingConnectState.disconnect) {
      _isMeetingReconnecting.value = true;
    } else if (state == NEMeetingConnectState.reconnect) {
      _isMeetingReconnecting.value = false;
      showToast(NEMeetingUIKitLocalizations.of(context)!
          .networkReconnectionSuccessful);
    }
  }

  void onRoomCloudRecordStateChanged(
      NERoomCloudRecordState state, NERoomMember? operateBy) {
    final isCloudRecordStart = state == NERoomCloudRecordState.recordingStart;
    cloudRecordListenable.value = isCloudRecordStart;
    cloudRecordStateListenable.value = isCloudRecordStart
        ? _CloudRecordState.started
        : _CloudRecordState.notStarted;
    final showCloudRecordingUI = arguments.options.showCloudRecordingUI;
    final isMySelf = isSelf(operateBy?.uuid);

    /// 非自己开始或结束录制，提示弹窗
    if (!isMySelf && showCloudRecordingUI) {
      showCloudRecordingStateChangeDialog();
    }
  }

  /// 记录自己在断开音频的时候的静音状态
  var _isAudioOnBeforeAudioDisconnect = false;

  /// 断开音频后经过主持人操作之后的最终静音状态，用于在连接音频后进行恢复
  var _shouldUnmuteAfterAudioConnect = false;

  void onMemberAudioConnectStateChanged(
      NERoomMember? member, bool isAudioConnected) {
    if (isSelf(member?.uuid)) {
      audioConnectListenable.value = isAudioConnected;
      if (!isAudioConnected) {
        /// 音频断开，记录当前的静音状态
        _isAudioOnBeforeAudioDisconnect = roomContext.localMember.isAudioOn;
        _shouldUnmuteAfterAudioConnect = roomContext.localMember.isAudioOn;
      } else {
        /// 如果断开音频前非静音状态，但是连接音频的时候已经是静音状态，则进行Toast提示
        if (_isAudioOnBeforeAudioDisconnect &&
            !_shouldUnmuteAfterAudioConnect) {
          showToast(NEMeetingUIKitLocalizations.of(context)!
              .participantHostMuteAudio);
        }

        /// 音频连接，根据记录的静音状态去恢复
        if (_shouldUnmuteAfterAudioConnect) {
          roomContext.rtcController.unmuteMyAudio();
        } else {
          roomContext.rtcController.muteMyAudio();
        }
      }
    }
    _onRoomInfoChanged();
  }

  void onMemberSipStateChanged(NERoomMember? member, NERoomMember? operator) {
    /// 通过排 roomInfoUpdatedEventStream 通知到 meeting_members_page
    _onRoomInfoChanged();
  }

  void onMemberAppStateChanged(NERoomMember? member, NERoomMember? operator) {
    /// 通过排 roomInfoUpdatedEventStream 通知到 meeting_members_page
    _onRoomInfoChanged();
  }

  void handleRoomRtcStats(NERoomRtcStats stats) {
    final screenShareUuid =
        roomContext.rtcController.getScreenSharingUserUuid();
    bool isLocalVideoOn = roomContext.localMember.isVideoOn;
    bool isLocalScreenShareOn = screenShareUuid == roomContext.localMember.uuid;

    int upLossRate = (isLocalVideoOn || isLocalScreenShareOn)
        ? stats.txVideoPacketLossRate
        : stats.txAudioPacketLossRate;

    bool isRemoteVideoOn =
        roomContext.remoteMembers.any((member) => member.isVideoOn);
    bool isRemoteScreenShareOn = roomContext.remoteMembers
        .any((member) => member.uuid == screenShareUuid);

    int downLossRate = (isRemoteVideoOn || isRemoteScreenShareOn)
        ? stats.rxVideoPacketLossRate
        : stats.rxAudioPacketLossRate;

    _networkInfo.value =
        NetWorkRttInfo(stats.downRtt, downLossRate, upLossRate);

    // assert(() {
    //   debugPrint(
    //       'downRtt: ${stats.downRtt}, upLossRate: $upLossRate, downLossRate: $downLossRate');
    //   return true;
    // }());
  }

  void handleRoomNetworkQuality(List<NERoomRtcNetworkQualityInfo> statsArray) {
    var stats = statsArray
        .where((stats) => stats.userId == roomContext.localMember.uuid)
        .firstOrNull;
    if (stats != null) {
      _networkStats.value = getNetworkStatus(stats.upStatus, stats.downStatus);
      // assert(() {
      //   debugPrint(
      //       'userId: ${stats.userId},upStatus: ${stats.upStatus}, downStatus: ${stats.downStatus}');
      //   return true;
      // }());

      /// 每连续三次网络异常，则toast提示
      if (_networkStats.value == _NetworkStatus.poor) {
        _networkPoorCount++;
        if (_networkPoorCount >= 3) {
          /// 如果正在重连loading则不显示网络异常toast
          if (!_isMeetingReconnecting.value) {
            showToast(NEMeetingUIKitLocalizations.of(context)!
                .networkAbnormalityPleaseCheckYourNetwork);
          }
          _networkPoorCount -= 3;
        }
      } else {
        _networkPoorCount = 0;
      }
    }
  }

  _NetworkStatus getNetworkStatus(NERoomRtcNetworkStatusType upStatus,
      NERoomRtcNetworkStatusType downStatus) {
    if ((upStatus == NERoomRtcNetworkStatusType.kStatusGood ||
            upStatus == NERoomRtcNetworkStatusType.kStatusExcellent) &&
        (downStatus == NERoomRtcNetworkStatusType.kStatusGood ||
            downStatus == NERoomRtcNetworkStatusType.kStatusExcellent)) {
      return _NetworkStatus.good;
    } else if ((upStatus == NERoomRtcNetworkStatusType.kStatusBad ||
            upStatus == NERoomRtcNetworkStatusType.kStatusVeryBad ||
            upStatus == NERoomRtcNetworkStatusType.kStatusDown) ||
        (downStatus == NERoomRtcNetworkStatusType.kStatusBad ||
            downStatus == NERoomRtcNetworkStatusType.kStatusVeryBad ||
            downStatus == NERoomRtcNetworkStatusType.kStatusDown)) {
      return _NetworkStatus.poor;
    } else if (upStatus == NERoomRtcNetworkStatusType.kStatusUnknown ||
        downStatus == NERoomRtcNetworkStatusType.kStatusUnknown) {
      return _NetworkStatus.unknown;
    } else {
      return _NetworkStatus.normal;
    }
  }

  String getNetworkStatusDesc(_NetworkStatus status) {
    switch (status) {
      case _NetworkStatus.good:
      case _NetworkStatus.unknown:
        return NEMeetingUIKitLocalizations.of(context)!.networkConnectionGood;
      case _NetworkStatus.normal:
        return NEMeetingUIKitLocalizations.of(context)!
            .networkConnectionGeneral;
      default:
        return NEMeetingUIKitLocalizations.of(context)!.networkConnectionPoor;
    }
  }

  @override
  void onFirstFrameRendered(String uid) {
    commonLogger.i('onFirstFrameRendered uid=$uid');
  }

  @override
  void onFrameResolutionChanged(
      String uid, int width, int height, int rotation) {
    commonLogger.i(
      'onFrameResolutionChanged uid=$uid width=$width height=$height rotation=$rotation',
    );
    if (uid == getScreenShareUserId() &&
        (_screenShareWidth != width || _screenShareHeight != height)) {
      _screenShareWidth = width;
      _screenShareHeight = height;
      _screenShareController.value = Matrix4.identity();
    }

    ///记录所有uid宽高
    _userAspectRatioMap[uid] =
        width.toDouble() / height.toDouble() > 9 / 16 ? 16 / 9 : 9 / 16;
    updatePIPAspectRatio();
  }

  Future<NEResult<void>> fullCurrentMeeting() {
    setState(() {
      _isMinimized = false;
    });
    // iOS 组件进入全屏应先销毁，在重新初始化
    iOSDisposePIP().then((value) {
      if (!isSelfScreenSharing() && arguments.enablePictureInPicture) {
        iOSSetupPIP(roomContext.roomUuid);
      }
    });
    checkMeetingEnd(false);
    // 房间未结束，发送状态通知
    if (!_isAlreadyMeetingDisposeInMinimized) {
      MeetingCore()
          .notifyStatusChange(NEMeetingStatus(NEMeetingEvent.inMeeting));
    }
    commonLogger.i('fullCurrentMeeting');
    return Future.value(NEResult(code: NEErrorCode.success));
  }

  Future<NEResult<void>> minimizeCurrentMeeting() {
    if (_isMinimized != true) {
      _isMinimized = true;
      EventBus().emit(NEMeetingUIEvents.flutterPageDisposed, 'minimize');
      MeetingCore().notifyStatusChange(
          NEMeetingStatus(NEMeetingEvent.inMeetingMinimized));

      /// 开启小窗，跳转到首页
      _galleryModePageController?.jumpTo(0);

      /// 关闭消息通知弹窗
      cancelInComingTips();

      /// iOS 退后台前，先默认setup，解决退后台时无法显示画中画
      iOSSetupPIP(roomContext.roomUuid);
      if (arguments.backgroundWidget != null) {
        PIPView.of(pipContext)
            ?.presentBelow(arguments.backgroundWidget!, pipViewAspectRatio);
      } else {
        if (Platform.isAndroid) {
          enablePip(
                  context,
                  pipViewAspectRatio! > 1.0
                      ? Rational.landscape()
                      : Rational.vertical())
              .then((value) {
            if (value != PiPStatus.enabled) {
              // 不支持画中画，使用常规最小化方式(直接销毁原生容器)
              EventBus().emit(NEMeetingUIEvents.flutterPageDisposed);
            }
          });
        }
      }
    }
    setState(() {});
    commonLogger.i('minimized');
    return Future.value(NEResult(code: NEErrorCode.success));
  }

  @override
  Future<NEResult<void>> subscribeAllRemoteAudioStreams(bool subscribe) {
    return Future.value(
        NEResult(code: NEErrorCode.failure, msg: 'NotSupported'));
  }

  @override
  Future<NEResult<void>> startAudioDump() {
    final result = rtcController.startAudioDump(NEAudioDumpType.kPCM);
    commonLogger.i('startAudioDump: $result');
    return result;
  }

  @override
  Future<NEResult<void>> stopAudioDump() {
    final result = rtcController.stopAudioDump();
    commonLogger.i(
      'stopAudioDump: $result',
    );
    return result;
  }

  @override
  Future<NEResult<List<String>>> subscribeRemoteAudioStreams(
      List<String> userList, bool subscribe) {
    return Future.value(
        NEResult(code: NEErrorCode.failure, msg: 'NotSupported'));
  }

  @override
  Future<NEResult<void>> subscribeRemoteAudioStream(
      String userId, bool subscribe) {
    return Future.value(
        NEResult(code: NEErrorCode.failure, msg: 'NotSupported'));
  }

  void changeToolBarStatus() {
    // print("changeToolBarStatus :$_isEditStatus");
    if (appBarAnimController.status == AnimationStatus.completed) {
      appBarAnimController.reverse();
    } else if (appBarAnimController.status == AnimationStatus.dismissed) {
      appBarAnimController.forward();
    }
  }

  bool get isToolbarShowing =>
      appBarAnimController.status == AnimationStatus.dismissed ||
      appBarAnimController.status == AnimationStatus.reverse;

  void createHistoryMeetingItem() {
    if (historyMeetingItem == null) {
      final meetingInfo = arguments.meetingInfo;
      final self = roomContext.localMember;
      historyMeetingItem = NEHistoryMeetingItem(
        meetingId: meetingInfo.meetingId,
        meetingNum: meetingInfo.meetingNum,
        shortMeetingNum: meetingInfo.shortMeetingNum,
        subject: meetingInfo.subject,
        password: roomContext.password,
        nickname: self.name,
        sipId: roomContext.sipCid,
      );
    }
  }

  void memberJoinRtcChannel(List<NERoomMember> members) {
    for (var user in members) {
      audioVolumeStreams.putIfAbsent(
          user.uuid, () => StreamController<int>.broadcast());
      if (user.uuid == roomContext.localMember.uuid) {
        onConnected();
      } else {
        onMemberInOrOut();
      }
    }
  }

  void onConnected() {
    commonLogger.i(
      'onConnected elapsed=${DateTime.now().millisecondsSinceEpoch - meetingBeginTime}ms, state=$_meetingState',
    );
    if (_meetingState != MeetingState.joining) return;
    reportMeetingJoinResultEvent(0);
    meetingDuration = Stopwatch()..start();
    _isEverConnected = true;
    _meetingState = MeetingState.joined;
    joinTimeOut?.cancel();
    InMeetingService()
      .._audioDelegate = this
      .._minimizeDelegate = this
      .._menuItemDelegate = this;
    createHistoryMeetingItem();
    MeetingCore().notifyStatusChange(NEMeetingStatus(NEMeetingEvent.inMeeting));
    handleAppLifecycleChangeEvent();
    setupAudioAndVideo();
    _initWithSDKConfig();
    waitingRoomManager.reset();

    activeSpeakerManager?.dispose();
    activeSpeakerManager = ActiveSpeakerManager(
      roomContext: roomContext,
      config: ActiveSpeakerConfig.fromJson(
          sdkConfig.getConfig('activeSpeakerConfig') as Map?),
      onActiveSpeakerActiveChanged: handleActiveSpeakerActiveChanged,
      onActiveSpeakerListChanged: handleActiveSpeakerListChanged,
    );
    audioVolumeStreams[roomContext.localMember.uuid] =
        StreamController<int>.broadcast();
    startAndroidForegroundService(forMediaProjection: true);

    initChatRoom();
    if (arguments.defaultWindowMode == WindowMode.whiteBoard.value &&
        _isMenuItemShowing(NEMenuIDs.whiteBoard) &&
        !whiteboardController.isSharingWhiteboard()) {
      unawaited(_onWhiteBoard());
    }
    whiteBoardEditingState.addListener(() {
      debugPrint('whiteboard editing state=${whiteBoardEditingState.value}');
      if (whiteBoardEditingState.value) {
        appBarAnimController.forward();
      } else {
        appBarAnimController.reverse();
      }
    });
    if (mounted) {
      setState(() {});
    }
    if (roomContext.isMySelfCoHost()) {
      showToast(
          NEMeetingUIKitLocalizations.of(context)!.participantAssignedCoHost);
    }
    showReclaimHostDialogIfNeeded();
    Timer(muteDetectDelay, () {
      if (muteDetectStarted == null) {
        muteDetectStarted = true;
      }
    });
    _remainingSecondsAdjustment.stop();
    var remain = Duration(seconds: _remainingSeconds.value) -
        _remainingSecondsAdjustment.elapsed;
    scheduleMeetingEndTipTask(remain);
    iOSSetupPIP(roomContext.roomUuid);
    _screenShareController.addListener(() {
      // 判断是否缩放已经重置，这里判断是否为单元矩阵
      // 如果和单元矩阵相差不大，也认为是单元矩阵
      final matrix = _screenShareController.value - Matrix4.identity();
      final floats = List<num>.filled(16, 0.0);
      matrix.copyIntoArray(floats);
      pageViewScrollableListenable.value = floats.every((element) {
        return element.abs() <= 1e-5;
      });
    });
  }

  void startAndroidForegroundService({
    bool forMediaProjection = false,
    bool forMicrophone = false,
  }) {
    /// Android 显示前台服务通知
    if (Platform.isAndroid) {
      MeetingCore().getForegroundConfig().then((foregroundConfig) {
        if (foregroundConfig != null) {
          final service = NEMeetingPlugin().getNotificationService();
          if (forMediaProjection) {
            service.startForegroundService(
              foregroundConfig,
              NENotificationService.serviceTypeMediaProjection,
            );
            commonLogger.i('start media projection foreground service');
          }
          if (forMicrophone) {
            service.startForegroundService(
              foregroundConfig,
              NENotificationService.serviceTypeMicrophone,
            );
            commonLogger.i('start microphone foreground service');
          }
        }
      });
    }
  }

  void memberLeaveRtcChannel(List<NERoomMember> members) {
    onMemberInOrOut();
  }

  void onMemberInOrOut() {
    focusUid = roomContext.getFocusUuid();
    final user = meetingUIState.lockedUser;
    if (user != null && roomContext.getMember(user) == null) {
      meetingUIState.lockUserVideo(null);
      showToast(meetingUiLocalizations.meetingUnpinViewTip);
    }
    _onRoomInfoChanged();
  }

  void onRtcChannelError(int code) {
    commonLogger.i('onRtcChannelError: code=$code');
  }

  void onRoomDisconnected(NERoomEndReason reason) {
    if (_meetingState.index >= MeetingState.closing.index) {
      return;
    }
    commonLogger.i('onDisconnect reason=$reason');
    reportMeetingEndEvent(reason);
    switch (reason) {
      case NERoomEndReason.kCloseByBackend:
        _onCancel(
            exitCode: NEMeetingCode.closeByHost,
            reason:
                NEMeetingUIKitLocalizations.of(context)!.meetingCloseByHost);
        break;
      case NERoomEndReason.kCloseByMember:
        _onCancel(
            exitCode: isSelfHostOrCoHost()
                ? NEMeetingCode.closeBySelfAsHost
                : NEMeetingCode.closeByHost,
            reason: NEMeetingUIKitLocalizations.of(context)!.meetingClosed);
        break;
      case NERoomEndReason.kKickOut:
        onKicked();
        break;
      case NERoomEndReason.kKickBySelf:
        _onCancel(
            exitCode: NEMeetingCode.loginOnOtherDevice,
            reason:
                NEMeetingUIKitLocalizations.of(context)!.loginOnOtherDevice);
        break;
      case NERoomEndReason.kLoginStateError:
        _onCancel(
            exitCode: NEMeetingCode.authInfoExpired,
            reason: NEMeetingUIKitLocalizations.of(context)!.authInfoExpired);
        break;
      case NERoomEndReason.kLeaveBySelf:
        _onCancel(
            exitCode: NEMeetingCode.self,
            reason: NEMeetingUIKitLocalizations.of(context)!.meetingLeaveFull);
        break;
      case NERoomEndReason.kEndOfLife:
        _onCancel(
            exitCode: NEMeetingCode.endOfLife,
            reason: NEMeetingUIKitLocalizations.of(context)!.meetingEndOfLife);
        break;
      case NERoomEndReason.kSyncDataError:
      case NERoomEndReason.kEndOfRtc:
        if (reason == NERoomEndReason.kSyncDataError) {
          showToast(NEMeetingUIKitLocalizations.of(context)!.networkNotStable);
        }
        if (_isMinimized) {
          _isMeetingReconnecting.value = false;
          isShowNetworkAbnormalityAlertDialog = true;
        } else {
          _showNetworkAbnormalityAlertDialog();
        }
        break;
      default:
        showToast(NEMeetingUIKitLocalizations.of(context)!.networkNotStable);
        _onCancel(exitCode: NEMeetingCode.undefined, reason: reason.name);
        break;
    }
  }

  /// 如果已经开启了屏幕共享,则关闭屏幕共享,如果已经开启了白板共享,则关闭白板共享
  Future _stopScreenShareAndWhiteboardShare() async {
    return Future.wait([
      if (isSelfScreenSharing()) _stopScreenShare(),
      if (isSelfWhiteBoardSharing()) _stopWhiteboardShare()
    ]);
  }

  _showNetworkAbnormalityAlertDialog({int retryTime = 4}) {
    if (retryTime <= 0) {
      if (!_isMinimized) {
        Navigator.of(context).pop();
        _onCancel();
      } else {
        isShowNetworkAbnormalityAlertDialog = true;
        return;
      }
    }
    if (isExistRejoinDialog) return;
    isExistRejoinDialog = true;
    NEMeetingPlugin().audioService.stop();
    DialogUtils.showNetworkAbnormalityAlertDialog(
        context: context,
        onLeaveMeetingCallback: () {
          Navigator.of(context).pop();
          _onCancel();
        },
        onRejoinMeetingCallback: () {
          _isMeetingReconnecting.value = true;
          isExistRejoinDialog = false;
          Navigator.of(context).pop();
          final trackingEvent = IntervalEvent(kEventJoinMeeting)
            ..addParam(kEventParamMeetingNum, roomContext.meetingNum)
            ..addParam(kEventParamType, 'rejoin');
          NEMeetingKit.instance
              .getMeetingService()
              .joinMeeting(
                  NEJoinMeetingParams(
                      meetingNum: roomContext.meetingNum,
                      password: roomContext.password,
                      displayName: roomContext.localMember.name)
                    ..trackingEvent = trackingEvent,
                  NEJoinMeetingOptions(
                    enableMyAudioDeviceOnJoinRtc:
                        arguments.options.detectMutedMic,
                  ))
              .onSuccess((newRoomContext) async {
            if (!mounted) return;
            meetingNavigator.initMeeting(arguments.copyWith(
              roomContext: newRoomContext,
              initialAudioMute: arguments.audioMute,
              initialVideoMute: arguments.videoMute,
            ));
          }).onFailure((code, msg) {
            _isMeetingReconnecting.value = false;
            if (_isMinimized) {
              isShowNetworkAbnormalityAlertDialog = true;
              return;
            }
            showToast('$msg');

            /// 如果会议已结束/会议不存在/会议已锁定，非最小化模式 则直接退出至首页
            if (code == NEMeetingErrorCode.meetingRecycled ||
                code == NEMeetingErrorCode.meetingNotExist ||
                code == NEMeetingErrorCode.meetingLocked) {
              _onCancel();
            } else {
              _showNetworkAbnormalityAlertDialog(retryTime: retryTime - 1);
            }
          });
        });
  }

  /// ****************** InRoomServiceListener ******************

  /// status 对应缺少主持人操作相关
  /// 此处通过 对比 被操作人member，和操作人operateMember的id，来区分是自己操作，还是管理者操作
  void memberScreenShareStateChanged(
      NERoomMember member, bool isSharing, NERoomMember? operator) {
    trackPeriodicEvent(
        isSharing
            ? TrackEventName.memberScreenShareStart
            : TrackEventName.memberScreenShareStop,
        extra: {
          'member_uid': member.uuid,
          'meeting_num': arguments.meetingNum
        });

    if (isSharing) {
      _isGalleryLayout.value = false;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        // _myScrollController.jumpTo(1);
        _galleryModePageController?.jumpTo(1);
      });

      appBarAnimController.forward();
    }

    if (isSelf(member.uuid)) {
      _updateWatermarkInfo();
      if (!isSharing &&
          !isSelf(operator?.uuid) &&
          isHostOrCoHost(operator?.uuid) &&
          !_isMinimized) {
        showToast(NEMeetingUIKitLocalizations.of(context)!
            .participantHostStoppedShare);
      }
      // 被停止共享，音频共享也要停止
      if (!isSharing && audioSharingListenable.value) {
        enableAudioShare(false);
      }

      bool isSelfSharing = isSelfScreenSharing();
      screenShareListenable.value = isSelfSharing;
      if (isSelfSharing && member.isRaisingHand) {
        roomContext.lowerMyHand();
      }
      // iOS 自己共享，不开启画中画
      if (isSharing) {
        iOSDisposePIP();
      } else {
        iOSSetupPIP(roomContext.roomUuid);
      }
    } else {
      _screenShareController.value = Matrix4.identity();
    }
    _onRoomInfoChanged();
    if (Platform.isAndroid) {
      updatePIPAspectRatio();
    } else {
      iOSUpdatePIPVideo(bigUid ?? '');
    }
  }

  // 白板分享状态变更回调
  void memberWhiteboardShareStateChanged(
      NERoomMember member, bool isSharing, NERoomMember? operator) {
    if (isSharing) {
      _isGalleryLayout.value = false;
      _galleryModePageController?.jumpTo(1);
      appBarAnimController.forward();
    }
    if (!isSharing &&
        isSelf(member.uuid) &&
        !isSelf(operator?.uuid) &&
        isHostOrCoHost(operator?.uuid)) {
      // 被操作的是自己，操作人是非自己，isSharing false 时认为是被主持人或者管理者停止了共享
      showToast(NEMeetingUIKitLocalizations.of(context)!
          .participantHostStopWhiteboard);
    }
    whiteBoardShareListenable.value = isSelfWhiteBoardSharing();
    if (!isSharing) {
      appBarAnimController.reverse();
      if (isSelf(member.uuid)) {
        whiteboardController.deleteWhiteboardConfig();
      }
    }
    _onRoomInfoChanged();
    if (whiteboardController.isDrawWhiteboardEnabled() && !isSharing) {
      whiteboardController.revokePermission(roomContext.myUuid);
    }
    whiteBoardEditingState.value = isSelfWhiteBoardSharing();
    whiteBoardInteractionStatusNotifier.value = isSelfWhiteBoardSharing();
  }

  void handleRoomPropertiesEvent(
      Map<String, String> properties, bool isDelete) {
    var updated = updateViewOrder(properties, isDelete);
    updated = updateFocus();
    updated = updateAllMuteState(properties, isDelete) || updated;
    updated = properties.containsKey(NEChatPermissionProperty.key) || updated;
    if (updated) {
      _onRoomInfoChanged();
    }
    if (properties.containsKey(WatermarkProperty.key)) {
      _updateWatermarkInfo();
    }
  }

  bool updateFocus() {
    final oldFocus = focusUid;
    final newFocus = roomContext.getFocusUuid();
    if (oldFocus != newFocus) {
      commonLogger.i(
        'focus user changed: old=$oldFocus, new=$newFocus',
      );
      if (isSelf(oldFocus)) {
        showToast(NEMeetingUIKitLocalizations.of(context)!
            .participantUnassignedActiveSpeaker);
      }
      if (isSelf(newFocus)) {
        // 联席主持人，主持人都有可被其他人设置为焦点视频，去掉 非主持人才提示的判断
        showToast(NEMeetingUIKitLocalizations.of(context)!
            .participantAssignedActiveSpeaker);
      }
      focusUid = newFocus;
      return true;
    }
    return false;
  }

  /// 更新视图模式
  ///
  bool updateViewOrder(Map<String, String> properties, bool propertiesDeleted) {
    var updated = false;
    if (properties.containsKey(ViewOrderConfigProperty.key)) {
      if (propertiesDeleted) {
        updated = true;
        videoStrategyContext.setStrategy(
            NERoomVideoStrategyRegistry.getStrategy(
                NormalStrategy.strategyName)!);
        hostVideoOrderList.clear();
      } else {
        if (hostVideoOrderList.isNotEmpty && hostVideoOrderList.length <= 0) {
          hostVideoOrderList = roomContext.hostVideoOrderList;
          updated = true;
        } else {
          updated = hostVideoOrderList.toString() !=
              roomContext.hostVideoOrderList.toString();
        }
        if (updated) {
          videoStrategyContext.setStrategy(
              NERoomVideoStrategyRegistry.getStrategy(
                  NERoomVideoOrderStrategy.strategyName)!);
        }
      }
    }
    if (updated) {
      setState(() {});
    }
    return updated;
  }

  bool updateAllMuteState(Map<String, String> properties, bool isDelete) {
    _invitingToOpenAudio = false;
    _invitingToOpenVideo = false;
    var updated = false;
    if (properties.containsKey(AudioControlProperty.key)) {
      if (!isSelfHostOrCoHost() && roomContext.isAllAudioMuted) {
        if (roomContext.localMember.isAudioConnected) {
          if (roomContext.localMember.isAudioOn) {
            showToast(NEMeetingUIKitLocalizations.of(context)!
                .participantHostMuteAllAudio);
            rtcController.muteMyAudio();
          }
        } else {
          _shouldUnmuteAfterAudioConnect = false;
        }
      }
      if (!isSelfHostOrCoHost() && !roomContext.isAllAudioMuted) {
        if (roomContext.localMember.isAudioConnected) {
          if (!roomContext.localMember.isAudioOn) {
            /// 解除全体静音时，如果当前用户处于举手状态不需要弹出dialog，直接打开音频
            /// 如果没有举手 就弹出dialog
            if (roomContext.localMember.isRaisingHand) {
              _muteMyAudio(false);
            } else {
              if (raiseAudioContextNotifier?.value != null) {
                Navigator.of(raiseAudioContextNotifier!.value!).pop();
              }
              showOpenMicDialog();
            }
          }
        } else if (_isAudioOnBeforeAudioDisconnect) {
          /// 如果断开音频前自己是非静音状态，那么收到开麦请求时直接处理为要打开即可
          _shouldUnmuteAfterAudioConnect = true;
        }
      }
      updated = true;
      if (roomContext.localMember.isRaisingHand &&
          roomContext.canUnmuteMyAudio()) {
        roomContext.lowerMyHand();
      }
    }
    if (properties.containsKey(VideoControlProperty.key)) {
      if (!isSelfHostOrCoHost() &&
          roomContext.isAllVideoMuted &&
          roomContext.localMember.isVideoOn) {
        showToast(NEMeetingUIKitLocalizations.of(context)!
            .participantHostMuteAllVideo);
        rtcController.muteMyVideo();
      }
      if (!isSelfHostOrCoHost() &&
          !roomContext.isAllVideoMuted &&
          !roomContext.localMember.isVideoOn) {
        if (raiseVideoContextNotifier?.value != null) {
          Navigator.of(raiseVideoContextNotifier!.value!).pop();
        }
        showOpenVideoDialog();
      }
      updated = true;
      if (roomContext.localMember.isRaisingHand &&
          roomContext.canUnmuteMyVideo()) {
        roomContext.lowerMyHand();
      }
    }
    return updated;
  }

  void handleMemberPropertiesEvent(
      NERoomMember member, Map<String, String> properties) {
    updateMemberIncall(member, properties);
    var updated = updateSelfWhiteboardDrawableState(member.uuid, properties);
    updated = updateSelfHandsUpState(member.uuid, properties) || updated;
    if (updated) {
      _onRoomInfoChanged();
    }
  }

  updateMemberIncall(NERoomMember member, Map<String, String> properties) {
    if (!properties.containsKey(PhoneStateProperty.key)) return;
    iOSMemberInCall(member.uuid, member.isInCall);
  }

  // 白板权限变更回调 与onRoomUserWhiteBoardInteractionStatusChanged 逻辑一致
  bool updateSelfWhiteboardDrawableState(
      String userId, Map<String, String> properties) {
    if (!isSelf(userId) ||
        !properties.containsKey(WhiteboardDrawableProperty.key)) return false;
    final isDrawEnabled = whiteboardController.isDrawWhiteboardEnabled();
    whiteBoardInteractionStatusNotifier.value = isDrawEnabled;
    whiteBoardEditingState.value = isDrawEnabled;
    whiteboardController.showWhiteboardTools(isDrawEnabled);
    if (isWhiteBoardSharing() && !isSelfWhiteBoardSharing()) {
      showToast(isDrawEnabled
          ? NEMeetingUIKitLocalizations.of(context)!.whiteBoardInteractionTip
          : NEMeetingUIKitLocalizations.of(context)!
              .whiteBoardUndoInteractionTip);
    }
    return true;
  }

  bool updateSelfHandsUpState(String userId, Map<String, String> properties) {
    if (!properties.containsKey(HandsUpProperty.key)) return false;
    if (isSelf(userId) && roomContext.localMember.isHandDownByHost) {
      showToast(NEMeetingUIKitLocalizations.of(context)!
          .meetingHostRejectAudioHandsUp); // Strings.hostAgreeAudioHandsUp
    }
    return isSelfHostOrCoHost() || isSelf(userId);
  }

  void liveStateChanged(NERoomLiveState state) {
    commonLogger.i(
      'liveStateChanged:state ${state.name}',
    );
    _isLiveStreaming.value = state == NERoomLiveState.started;
  }

  void handlePassThroughMessage(NECustomMessage message) {
    if (message.roomUuid != roomContext.roomUuid) {
      return;
    }
    commonLogger.i(
      'handlePassThroughMessage: ${message.data}',
    );
    final controlAction = MeetingControlMessenger.parseMessage(message.data);
    if (controlAction == MeetingControlMessenger.inviteToOpenAudio ||
        controlAction == MeetingControlMessenger.inviteToOpenAudioVideo) {
      if (!roomContext.localMember.isAudioConnected) {
        if (_isAudioOnBeforeAudioDisconnect) {
          /// 如果断开音频前自己是非静音状态，那么收到开麦请求时直接处理为要打开即可
          _shouldUnmuteAfterAudioConnect = true;
        }
      } else if (roomContext.localMember.isRaisingHand ||
          isSelfHostOrCoHost()) {
        if (!roomContext.localMember.isAudioOn) {
          rtcController.unmuteMyAudioWithCheckPermission(
              context, arguments.meetingTitle);
        }
      } else if (!roomContext.localMember.isAudioOn) {
        _invitingToOpenAudio = true;
        showOpenMicDialog().whenComplete(() => _invitingToOpenAudio = false);
      }
    }
    if (controlAction == MeetingControlMessenger.inviteToOpenVideo ||
        controlAction == MeetingControlMessenger.inviteToOpenAudioVideo) {
      // 邀请打开视频，总是需要弹窗确认
      if (!roomContext.localMember.isVideoOn) {
        _invitingToOpenVideo = true;
        if (roomContext.localMember.isRaisingHand) {
          roomContext.lowerMyHand();
        }
        showOpenVideoDialog().whenComplete(() => _invitingToOpenVideo = false);
      }
    }
  }

  bool get isInActiveSpeakerView => pageViewCurrentIndex.value == 0;

  void handleActiveSpeakerActiveChanged(String user, bool active) {
    /// 未开启“视频提前订阅”
    if (activeSpeakerManager?.config.enableVideoPreSubscribe != true) return;

    /// 成员不存在
    final member = roomContext.getMember(user);
    if (member == null) return;

    /// 处于“演讲者模式”，无焦点视频，成员加入“正在讲话”列表，且视频打开，则提前订阅该用户的视频大流
    if (active && focusUid == null && meetingUIState.lockedUser == null) {
      /// 更新到画中画
      iOSUpdatePIPVideo(user);
      if (member.isVideoOn && isInActiveSpeakerView) {
        userVideoStreamSubscriber.preSubscribeVideoStream(
            user, NEVideoStreamType.kHigh);
      }
    }

    /// 成员离开“正在讲话”列表，则取消订阅用户视频大流
    if (!active) {
      userVideoStreamSubscriber.preUnsubscribeVideoStream(user);
    }
  }

  void onRemoteAudioVolumeIndication(
      List<NEMemberVolumeInfo> volumeList, int totalVolume) {
    if (_isAlreadyCancel) return;
    volumeList.forEach((item) {
      audioVolumeStreams[item.userUuid]?.add(item.volume);
    });
  }

  void onLocalAudioVolumeIndicationWithVad(int volume, bool enableVad) {
    // assert((){
    //   debugPrint('onLocalAudioVolumeIndicationWithVad: volume=$volume, enableVad=$enableVad');
    //   return true;
    // }());
    audioVolumeStreams[roomContext.localMember.uuid]?.add(volume);
    if (!arguments.options.detectMutedMic) {
      return;
    }
    if (!arguments.audioMute) {
      muteDetectStarted = false;
      resetMuteDetectInfo();
      return;
    }
    var res = false;
    if (muteDetectStarted == true) {
      res = detectContinueSpeak(volume, enableVad);
      if (res) {
        _showTurnOnMicPhoneTipDialog();
        muteDetectStarted = false;
        return;
      }
    }
  }

  void resetMuteDetectInfo() {
    volumeInfo.clear();
    vadInfo.clear();
  }

  bool detectContinueSpeak(int volume, bool enableVad) {
    int count = 0;
    bool res = false;
    volumeInfo.add(volume);
    vadInfo.add(enableVad);
    final wndSize =
        activeSpeakerManager?.config.volumeIndicationWindowSize ?? 15;
    if (volumeInfo.length == wndSize) {
      for (int i = 0; i < wndSize; i++) {
        if ((volumeInfo[i] > 40) && vadInfo[i]) {
          count++;
        }
      }
      res = count >= wndSize / 2;
      resetMuteDetectInfo();
    }
    return res;
  }

  /// “打开扬声器”提醒弹窗
  void _showTurnOnMicPhoneTipDialog() {
    // 小窗模式下，不展示静音检测提示
    if (_isMinimized) return;
    commonLogger.i(
      'showTurnOnMicphoneTipDialog',
    );
    Timer? cancelTimer;
    final dismissCallback = DialogUtils.showOneButtonDialogWithDismissCallback(
      context,
      NEMeetingUIKitLocalizations.of(context)!
          .meetingMicphoneNotWorksDialogTitle,
      NEMeetingUIKitLocalizations.of(context)!
          .meetingMicphoneNotWorksDialogMessage,
      () {
        commonLogger.i('dismissTurnOnMicPhoneTipDialog');
        if (cancelTimer?.isActive == true) {
          cancelTimer?.cancel();
        }
        Navigator.of(context).pop();
      },
    );
    cancelTimer = Timer(Duration(seconds: 3), () {
      commonLogger.i('dismissTurnOnMicPhoneTipDialog');
      dismissCallback.call();
    });
  }

  void setupAudioProfile() async {
    var userSetAudioProfile = arguments.options.audioProfile;
    final settingsAudioAINs =
        await NEMeetingKit.instance.getSettingsService().isAudioAINSEnabled();
    final audio = roomContext.localMember.role.params?.audio;

    /// 用户通过options.audioProfile设置
    if (userSetAudioProfile != null) {
      if (userSetAudioProfile.profile >= 0 &&
          userSetAudioProfile.scenario >= 0) {
        _setAudioProfile(
            userSetAudioProfile.profile, userSetAudioProfile.scenario);
      }
    }

    /// 初始化本地RtcConfig AudioProfile配置并同步到NEMeetingPlugin中
    else if (audio != null) {
      final profile = RtcUtils.getRtcAudioProfile(audio.profile);
      final scenario = RtcUtils.getRtcAudioScenario(audio.scenario);
      _setAudioProfile(profile, scenario);
    }
    final enableAudioAINs =
        userSetAudioProfile?.enableAINS ?? settingsAudioAINs;
    roomContext.rtcController.enableAudioAINS(enableAudioAINs);
  }

  /// Android设备且允许音频设备切换时，调用NEMeetingPlugin里的接口
  /// NEMeetingPlugin里会同步一些状态
  void _setAudioProfile(int profile, int scenario) {
    if (Platform.isAndroid && isAudioDeviceSwitchEnabled) {
      NEMeetingPlugin().audioService.setAudioProfile(profile, scenario);
    } else {
      roomContext.rtcController.setAudioProfile(profile, scenario);
    }
  }

  Future<void> setupAudioAndVideo() async {
    final bool isInCall = await NEMeetingPlugin().phoneStateService.isInCall;

    var willOpenAudio = false, willOpenVideo = false;
    if (!arguments.initialAudioMute) {
      if (roomContext.isAllAudioMuted && !isSelfHostOrCoHost()) {
        /// 设置了全体静音，并且自己不是主持人时 提示主持人设置全体静音
        showToast(NEMeetingUIKitLocalizations.of(context)!
            .participantHostMuteAllAudio);
      } else if (!isInCall) {
        willOpenAudio = true;
      }
    }

    if (!arguments.initialVideoMute) {
      if (roomContext.isAllVideoMuted && !isSelfHostOrCoHost()) {
        /// 设置了全体关闭视频，并且自己不是主持人时 提示主持人设置全体关闭视频
        showToast(NEMeetingUIKitLocalizations.of(context)!
            .participantHostMuteAllVideo);
      } else if (!isInCall) {
        willOpenVideo = true;
      }
    }

    commonLogger.i(
      'setup audio and video: $willOpenAudio $willOpenVideo',
    );

    if (willOpenAudio) {
      await rtcController.unmuteMyAudioWithCheckPermission(
          context, arguments.meetingTitle,
          needAwaitResult: false);
    }

    if (willOpenVideo) {
      await rtcController.unmuteMyVideoWithCheckPermission(
          context, arguments.meetingTitle,
          needAwaitResult: false);
    }
  }

  Widget buildSelfVolumeIndicator() {
    return AnimatedBuilder(
      animation: localAudioVolumeIndicatorAnim,
      builder: (context, child) => Positioned(
          bottom: localAudioVolumeIndicatorAnim.value,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 50,
              height: 50,
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                color: Colors.black.withAlpha(77),
                shape: CircleBorder(),
              ),
              child: GestureDetector(
                onTap: () => _muteMyAudio(!arguments.audioMute),
                child: buildRoomUserVolumeIndicator(
                  roomContext.localMember.uuid,
                  opacity: 0.8,
                  size: 30,
                ),
              ),
            ),
          )),
    );
  }

  Widget buildRoomUserVolumeIndicator(String userId,
      {double? size, double? opacity}) {
    final user = roomContext.getMember(userId);
    if (user == null || !user.isAudioConnected) {
      return SizedBox.shrink();
    }
    if (!user.isAudioOn) {
      return Icon(
        NEMeetingIconFont.icon_yx_tv_voice_offx,
        color: _UIColors.colorFE3B30,
        size: size,
      );
    } else {
      audioVolumeStreams.putIfAbsent(
          userId, () => StreamController<int>.broadcast());
      Widget child = AnimatedMicphoneVolume.light(
          opacity: opacity, volume: audioVolumeStreams[userId]!.stream);
      if (size != null) {
        child = SizedBox(
          width: size,
          height: size,
          child: child,
        );
      }
      return child;
    }
  }

//线性参数
  Future<void> setBeautyEffect(int beautyLevel) async {
    if (!isBeautyEnabled) {
      return;
    }
    final shouldEnable = beautyLevel > 0;
    rtcController.enableBeauty(shouldEnable);
    if (!shouldEnable) {
      return;
    }
    final level = beautyLevel.toDouble() / 10;
    rtcController
      ..setBeautyEffect(NERoomBeautyEffectType.kWhiten, level)
      ..setBeautyEffect(NERoomBeautyEffectType.kSmooth, level)
      ..setBeautyEffect(NERoomBeautyEffectType.kFaceRuddy, level)
      ..setBeautyEffect(NERoomBeautyEffectType.kFaceSharpen, level);
  }

  void _onVirtualBackground() {
    isPreviewVirtualBackground = true;
    Navigator.of(context)
        .push(
      MaterialMeetingPageRoute(
        builder: (context) => VirtualBackgroundPage(
          roomContext: roomContext,
          mirrorListenable: localMirrorState,
          videoStreamSubscriber: userVideoStreamSubscriber,
        ),
      ),
    )
        .whenComplete(() {
      isPreviewVirtualBackground = false;
    });
  }

  void _onCloudRecord() {
    if (roomContext.isCloudRecording) {
      stopCloudRecord();
    } else {
      startCloudRecord();
    }
  }

  Widget buildMeetingEndTip(height) {
    return Row(
      // mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          alignment: Alignment.center,
          margin: EdgeInsets.only(top: height + 10),
          padding: EdgeInsets.only(left: 13),
          height: 45,
          decoration: BoxDecoration(
            color: _UIColors.tipStartBg,
            border: Border.fromBorderSide(BorderSide(
              color: _UIColors.tipEndBg,
              width: 1,
              style: BorderStyle.solid,
            )),
            borderRadius: BorderRadius.all(Radius.circular(4.0)),
          ),
          child: Row(
            children: [
              Container(
                  alignment: Alignment.center,
                  child: Text(
                      '${NEMeetingUIKitLocalizations.of(context)!.meetingEndTip}$meetingEndTipMin${NEMeetingUIKitLocalizations.of(context)!.globalMinutes}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: _UIColors.black,
                          fontSize: 15,
                          decoration: TextDecoration.none,
                          fontWeight: FontWeight.w400))),
              Container(
                padding: EdgeInsets.only(top: 2),
                child: RawMaterialButton(
                  constraints:
                      const BoxConstraints(minWidth: 40.0, minHeight: 40.0),
                  child: Icon(
                    NEMeetingIconFont.icon_yx_tv_duankaix,
                    color: _UIColors.color_666666,
                    size: 15,
                    key: MeetingUIValueKeys.close,
                  ),
                  onPressed: () {
                    setState(() {
                      showMeetingEndTip = false;
                    });
                  },
                ),
              )
            ],
          ),
        ),
      ],
    );
  }

  bool isMeetingEndTimeTiSupported() =>
      sdkConfig.isMeetingEndTimeTipSupported &&
      arguments.showMeetingRemainingTip;

  void setupMeetingEndTip() {
    if (!isMeetingEndTimeTiSupported()) {
      return;
    }

    /// _remainingSeconds变更，刷新计时器
    _remainingSeconds.value = roomContext.remainingSeconds;
    _remainingSeconds.addListener(() {
      scheduleMeetingEndTipTask(Duration(seconds: _remainingSeconds.value));
    });
  }

  void debugPrintAlog(String message) {
    assert(() {
      commonLogger.i(message);
      return true;
    }());
  }

  Stream<int> meetingEndTipEventStream(Duration remain, int count) async* {
    assert(() {
      debugPrintAlog('meeting end tip stream started');
      return true;
    }());
    if (!remain.isNegative) {
      // 10分钟、5分钟、1分钟各提醒一次；提醒时间为 1 分钟
      final checkPoints = const [10, 5, 1];
      for (var index = 0; index < checkPoints.length; ++index) {
        final value = checkPoints[index];
        final next = Duration(minutes: value);
        var durationToRemind = remain - next;
        if (!durationToRemind.isNegative || index == checkPoints.length - 1) {
          if (!durationToRemind.isNegative) {
            await Future.delayed(durationToRemind);
          }
          if (count == _countForEndTip) {
            yield value;
          } else {
            break;
          }
          remain = next;
        }
      }
    }
  }

  void scheduleMeetingEndTipTask(Duration remain) {
    streamSubscriptions.remove(_meetingEndTipEventSubscription);
    _meetingEndTipEventSubscription?.cancel();

    /// 关闭会议结束提醒
    if (showMeetingEndTip) {
      setState(() {
        _oneMinuteTimer?.cancel();
        showMeetingEndTip = false;
      });
    }
    int count = ++_countForEndTip;
    _meetingEndTipEventSubscription =
        meetingEndTipEventStream(remain, count).listen((minutes) async {
      assert(() {
        debugPrintAlog('meeting end tip $minutes minutes remain');
        return true;
      }());
      if (mounted) {
        /// 开启会议结束提醒，并在 1 分钟后关闭
        setState(() {
          meetingEndTipMin = minutes;
          showMeetingEndTip = true;
        });
        if (minutes > 1) {
          _oneMinuteTimer = Timer(Duration(minutes: 1), () {
            if (mounted && count == _countForEndTip) {
              setState(() {
                showMeetingEndTip = false;
              });
            }
          });
        }
      }
    });
    streamSubscriptions.add(_meetingEndTipEventSubscription!);
  }

  void reportMeetingJoinResultEvent([dynamic result]) {
    final event = arguments.trackingEvent;
    arguments.trackingEvent = null;
    print('reportMeetingJoinResultEvent: $result');
    if (event != null) {
      roomContext.fillEventParams(event);
      if (result is NEResult) {
        event.endStepWithResult(result);
      } else if (result is int) {
        event.endStep(result);
      } else {
        event.endStep(-1, 'timeout');
      }
      NEMeetingKit.instance.reportEvent(event);
    }
  }

  Stopwatch? meetingDuration;

  void reportMeetingEndEvent(NERoomEndReason reason) {
    final event = IntervalEvent(kEventMeetingEnd)
      ..setResult(0)
      ..addParam(kEventParamReason, reason.camelCaseName)
      ..addParam(kEventParamMeetingDuration,
          meetingDuration?.elapsedMilliseconds ?? 0);
    roomContext.fillEventParams(event);
    NEMeetingKit.instance.reportEvent(event);
  }

  void iOSSetupPIP(String roomUuid, {bool autoEnterPIP = false}) async {
    if (!Platform.isIOS) return;
    if (!arguments.enablePictureInPicture && !_isMinimized) return;

    /// 当前的邀请信息，如果存在邀请则会在小窗展示来电页面
    final data = InviteQueueUtil.instance.currentInviteData.value?.inviteInfo;
    final inviterRoomId =
        InviteQueueUtil.instance.currentInviteData.value?.roomUuid;
    floating.setup(
        roomUuid,
        NEMeetingUIKitLocalizations.of(context)!.movedToWaitingRoom,
        NEMeetingUIKitLocalizations.of(context)!.meetingWasInterrupted,
        autoEnterPIP: autoEnterPIP,
        inviterIcon: data?.inviterIcon,
        inviterName: data?.inviterName,
        inviterRoomId: inviterRoomId);
  }

  /// TODO 需要和[updatePIPAspectRatio]合并
  void iOSUpdatePIPVideo(String userUuid) async {
    if (!Platform.isIOS) return;
    final shareUuid = roomContext.rtcController.getScreenSharingUserUuid();
    await Future.delayed(const Duration(milliseconds: 500));
    final result = await floating.isActive();
    if (result) {
      if (roomContext.localMember.uuid != userUuid) {
        pipUsers.add(userUuid);
      }
      if (shareUuid != null && shareUuid != roomContext.localMember.uuid) {
        pipShareUsers.add(shareUuid);
      }
      final member = roomContext.getMember(userUuid);
      floating.updateVideo(roomContext.roomUuid, userUuid, shareUuid ?? '',
          member?.isInCall ?? false);
    } else {
      // print("Picture in picture not turned on.");
    }
  }

  void iOSMemberVideoChange(String userUuid, bool isVideoOn) async {
    if (!Platform.isIOS || userUuid == '') return;
    await Future.delayed(const Duration(milliseconds: 500));
    final isActive = await floating.isActive();
    if (isActive) {
      if (roomContext.localMember.uuid != userUuid) {
        pipUsers.add(userUuid);
      }
      floating.memberVideoChange(userUuid, isVideoOn);
    } else {
      print("Picture in picture not turned on.");
    }
  }

  void iOSMemberAudioChange(String userUuid, bool isAudioOn) async {
    if (!Platform.isIOS) return;
    final isActive = await floating.isActive();
    if (isActive) {
      floating.memberAudioChange(userUuid, isAudioOn);
    } else {
      print("Picture in picture not turned on.");
    }
  }

  void iOSMemberInCall(String userUuid, bool isInCall) async {
    if (!Platform.isIOS || !_isAppInBackground) return;
    final isActive = await floating.isActive();
    if (isActive) {
      floating.memberInCall(userUuid, isInCall);
    } else {
      print("Picture in picture not turned on.");
    }
  }

  Future<bool> iOSDisposePIP() async {
    if (!Platform.isIOS) return Future.value(false);
    return await floating.disposePIP();
  }

  Future<PiPStatus> updatePIPAspectRatio(
      {bool canPopToMeetingPage = false}) async {
    PiPStatus pipStatus = PiPStatus.disabled;
    if (Platform.isAndroid) {
      pipStatus = await floating.pipStatus;
    }
    if (!mounted) return pipStatus;
    if (pipStatus == PiPStatus.enabled &&
        Platform.isAndroid &&
        arguments.backgroundWidget != null) {
      if (!_isMinimized) {
        setState(() {
          _isMinimized = true;
        });
      }
      if (canPopToMeetingPage) {
        SchedulerBinding.instance.scheduleFrameCallback((_) {
          if (!mounted) return;

          /// 需要放置的此处而不是resumed，因为Android的退后监听的是onUserLeaveHint
          /// 小窗模式下，需要处理隐藏弹窗逻辑，目前是回到inMeeting界面，waitingRoom界面没有最小化
          Navigator.popUntil(
              context, ModalRoute.withName(_RouterName.inMeeting));
        });
      }
    }
    if (getScreenShareUserId() != null) {
      var _ratio = _userAspectRatioMap[getScreenShareUserId()];
      pipViewAspectRatio = _ratio == null ? pipViewAspectRatio : _ratio;
    } else {
      ///设置当前bigUid ,视频开启在pipViewAspectRatio进行调整
      bool isVideoOn = false;
      if (isSelf(bigUid)) {
        isVideoOn = roomContext.localMember.isVideoOn;
      } else {
        isVideoOn = roomContext.remoteMembers.any((member) => member.isVideoOn);
      }
      if (isVideoOn) {
        var _ratio = _userAspectRatioMap[bigUid];
        pipViewAspectRatio = _ratio == null ? pipViewAspectRatio : _ratio;
      }
    }

    if (_isMinimized || pipStatus == PiPStatus.enabled) {
      // setState(() {});
      if (arguments.backgroundWidget != null) {
        if (pipStatus == PiPStatus.enabled) {
          if (Platform.isAndroid) {
            floating.updatePIPParams(
                aspectRatio: pipViewAspectRatio! > 1.0
                    ? Rational.landscape()
                    : Rational.vertical());
          } else if (Platform.isIOS) {
            ///TODO
          }
        } else {
          ///动态监听 会议 flutter组件
          /// 解决子widget 中需要被重建的 widget
          Future.delayed(const Duration(milliseconds: 300), () {
            PIPView.of(pipContext)
                ?.updatePipViewAspectRatio(ratio: pipViewAspectRatio);
          });
        }
      } else {
        ///会议 native组件.
        if (Platform.isAndroid) {
          floating.updatePIPParams(
              aspectRatio: pipViewAspectRatio! > 1.0
                  ? Rational.landscape()
                  : Rational.vertical());
        } else if (Platform.isIOS) {
          Rational rational = pipViewAspectRatio! > 1.0
              ? Rational.landscape()
              : Rational.vertical();
          EventBus().emit(NEMeetingUIEvents.flutterFrameChanged,
              {'width': rational.numerator, 'height': rational.denominator});
        }
      }
    }
    return pipStatus;
  }

  void determineToShowMeetingCloudRecordDialog() {
    /// 普通参会成员 入会或者重新入会的时候，如果会议开启了云录制，就弹出云录制提示框
    if (_isFirstJoinOrRejoinMeeting &&
        roomContext.isCloudRecording &&
        !isSelfHostOrCoHost()) {
      showCloudRecordingStateChangeDialog();
    }

    /// 如果从小窗模式回来，且小窗期间有云录制开启/停止，则弹出云录制提示框
    else if (_needToShowCloudRecordChange) {
      showCloudRecordingStateChangeDialog();
    }
    _isFirstJoinOrRejoinMeeting = false;
  }

  void checkMeetingEnd(bool isFloating) {
    _isMinimized = isFloating;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isShowNetworkAbnormalityAlertDialog &&
          !_isMeetingReconnecting.value &&
          !isFloating) {
        _showNetworkAbnormalityAlertDialog();
      } else if (_isAlreadyMeetingDisposeInMinimized &&
          _currentExitCode == NEMeetingCode.removedByHost &&
          !isFloating) {
        onKicked();
      } else if (_isAlreadyMeetingDisposeInMinimized &&
          _currentExitCode != null &&
          !isFloating) {
        _onCancel(exitCode: _currentExitCode!, reason: _currentReason);
      }
    });
  }

  Widget buildPIPView() {
    return PIPView(
      builder: (context, isFloating) {
        _isMinimized = isFloating;
        return Scaffold(
          resizeToAvoidBottomInset: !isFloating,
          body: AnnotatedRegion<SystemUiOverlayStyle>(
            value: isFloating
                ? AppStyle.systemUiOverlayStyleDark
                : AppStyle.systemUiOverlayStyleLight,
            child: InComingInvite(
                child: buildChild(context), isInMinimizedMode: true),
          ),
        );
      },
      backgroundWidget: arguments.backgroundWidget,
      onFloating: (isFloating) {
        checkMeetingEnd(isFloating);
        SystemChrome.setPreferredOrientations(
            !isFloating ? [] : [DeviceOrientation.portraitUp]);
        MeetingCore().notifyStatusChange(NEMeetingStatus(!isFloating
            ? NEMeetingEvent.inMeeting
            : NEMeetingEvent.inMeetingMinimized));
      },
    );
  }

  Future<bool> checkNetworkAndToast() async {
    if (!await ConnectivityManager().isConnected()) {
      showToast(NEMeetingUIKitLocalizations.of(context)!
          .networkAbnormalityPleaseCheckYourNetwork);
      return false;
    }
    return true;
  }

  Future<void> startCloudRecord() async {
    final localizations = NEMeetingUIKitLocalizations.of(context)!;
    final result = await DialogUtils.showCommonDialog(
        context,
        localizations.cloudRecordingEnabledTitle,
        arguments.options.showCloudRecordingUI
            ? localizations.cloudRecordingEnabledMessage
            : localizations.cloudRecordingEnabledMessageWithoutNotice, () {
      Navigator.of(context).pop();
    }, () {
      Navigator.of(context).pop(true);
    });
    if (result == true) {
      if (!await checkNetworkAndToast()) {
        return;
      }
      if (cloudRecordStateListenable.value == _CloudRecordState.notStarted) {
        cloudRecordStateListenable.value = _CloudRecordState.starting;
      }
      final startResult = await roomContext.startCloudRecord();
      cloudRecordStateListenable.value = roomContext.isCloudRecording
          ? _CloudRecordState.started
          : _CloudRecordState.notStarted;
      if (!startResult.isSuccess()) {
        showToast(localizations.cloudRecordingStartFail);
      }
    }
  }

  Future<void> stopCloudRecord() async {
    final result = await DialogUtils.showCommonDialog(
        context,
        NEMeetingUIKitLocalizations.of(context)!
            .cloudRecordingWhetherEndedTitle,
        NEMeetingUIKitLocalizations.of(context)!.cloudRecordingEndedMessage,
        () {
      Navigator.of(context).pop();
    }, () {
      Navigator.of(context).pop(true);
    });
    if (result == true) {
      if (!await checkNetworkAndToast()) {
        return;
      }
      final stopResult = await roomContext.stopCloudRecord();
      if (!stopResult.isSuccess()) {
        showToast(
            NEMeetingUIKitLocalizations.of(context)!.cloudRecordingStopFail);
      }
    }
  }

  /// 显示云录制开启/停止后的弹窗提示，如果showCloudRecordingUI为false，则不展示
  void showCloudRecordingStateChangeDialog() {
    if (!arguments.options.showCloudRecordingUI) {
      return;
    }

    /// 如果是最小化，则记录需要显示云录制状态变更弹窗，回来后再显示
    if (_isMinimized) {
      _needToShowCloudRecordChange = true;
      return;
    } else {
      _needToShowCloudRecordChange = false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (roomContext.isCloudRecording) {
        showCloudRecordingStartedDialog();
      } else {
        showCloudRecordingStoppedDialog();
      }
    });
  }

  /// 展示云录制开始弹窗
  void showCloudRecordingStartedDialog() {
    if (_cloudRecordStartedDismissCallback != null) {
      return;
    }
    commonLogger.i(
      'showCloudRecordingStartedDialog',
    );
    closeCloudRecordingStoppedDialog();
    _cloudRecordStartedDismissCallback = DialogUtils.showCustomContentDialog(
      context,
      NEMeetingUIKitLocalizations.of(context)!.cloudRecordingTitle,
      NEMeetingUIKitLocalizations.of(context)!.cloudRecordingMessage,
      () async {
        closeCloudRecordingStartedDialog();
        await _hideMorePopupMenu();
        finishPage();
      },
      closeCloudRecordingStartedDialog,
      cancelText: NEMeetingUIKitLocalizations.of(context)!.meetingLeave,
      acceptText: NEMeetingUIKitLocalizations.of(context)!.globalGotIt,
      contentWidget: Column(
        children: [
          Text(NEMeetingUIKitLocalizations.of(context)!.cloudRecordingMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: _UIColors.color_333333,
                  fontSize: 14,
                  decoration: TextDecoration.none,
                  fontWeight: FontWeight.w400)),
          SizedBox(
            height: 10,
          ),
          Text(NEMeetingUIKitLocalizations.of(context)!.cloudRecordingAgree,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: _UIColors.color_333333,
                  fontSize: 14,
                  decoration: TextDecoration.none,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  /// 关闭云录制开始弹窗
  bool closeCloudRecordingStartedDialog() {
    if (_cloudRecordStartedDismissCallback != null) {
      bool result = _cloudRecordStartedDismissCallback!.call();
      _cloudRecordStartedDismissCallback = null;
      return result;
    }
    return false;
  }

  /// 展示云录制停止弹窗
  void showCloudRecordingStoppedDialog() {
    if (_cloudRecordStoppedDismissCallback != null) {
      return;
    }
    commonLogger.i(
      'showCloudRecordingStoppedDialog',
    );
    closeCloudRecordingStartedDialog();
    _cloudRecordStoppedDismissCallback = DialogUtils.showOneTimerButtonDialog(
      context,
      NEMeetingUIKitLocalizations.of(context)!.cloudRecordingEndedTitle,
      NEMeetingUIKitLocalizations.of(context)!.cloudRecordingEndedAndGetUrl,
      closeCloudRecordingStoppedDialog,
      acceptText: NEMeetingUIKitLocalizations.of(context)!.globalIKnow,
    );
  }

  /// 关闭云录制停止弹窗
  bool closeCloudRecordingStoppedDialog() {
    if (_cloudRecordStoppedDismissCallback != null) {
      bool result = _cloudRecordStoppedDismissCallback!.call();
      _cloudRecordStoppedDismissCallback = null;
      return result;
    }
    return false;
  }

  TextWatermarkConfiguration? textWatermarkConfiguration;

  void _updateWatermarkInfo() {
    if (!isSelfScreenSharing() && roomContext.watermark.isEnable()) {
      final watermark = roomContext.watermark;
      final paddingTop = MediaQuery.of(context).padding.top;
      textWatermarkConfiguration ??= TextWatermarkConfiguration(
        offset: Offset(0, paddingTop),
        singleRow: watermark.isSingleRow(),
        text: watermark.replaceFormatText(arguments.watermarkConfig),
        maxWidth: watermark.isSingleRow() ? 184 : 138,
      );
      watermarkConfiguration.value = textWatermarkConfiguration;
    } else {
      watermarkConfiguration.value = null;
    }
  }

  Timer? _updateWaitingRoomCountTimer;

  void _updateWaitingRoomCountTip(MeetingNotifyDialogCountTipType tip) {
    if (_waitingRoomCountTipListenable.value !=
        MeetingNotifyDialogCountTipType.noLongerRemind) {
      if (isSelfHostOrCoHost() || tip != MeetingNotifyDialogCountTipType.show) {
        _waitingRoomCountTipListenable.value = tip;
      }

      if (tip == MeetingNotifyDialogCountTipType.show) {
        _updateWaitingRoomCountTimer?.cancel();
        _updateWaitingRoomCountTimer = Timer(Duration(seconds: 5), () {
          _updateWaitingRoomCountTip(MeetingNotifyDialogCountTipType.hide);
        });
      }
    }
  }

  Timer? _updateUnReadCountTimer;

  void _updateNotifyMessageTip(MeetingNotifyDialogCountTipType tip) {
    commonLogger.i('_updateNotifyMessageTip tip: ${tip.name}');
    if (_notifyMessageTipListenable.value !=
        MeetingNotifyDialogCountTipType.noLongerRemind) {
      _notifyMessageTipListenable.value = tip;

      if (tip == MeetingNotifyDialogCountTipType.show) {
        _updateUnReadCountTimer?.cancel();
        _updateUnReadCountTimer = Timer(Duration(seconds: 5), () {
          _updateNotifyMessageTip(MeetingNotifyDialogCountTipType.hide);
        });
      }
    }
  }

  /// 展示等候室等待人数提示
  Widget _buildWaitingRoomCountTip() {
    final localizations = NEMeetingUIKitLocalizations.of(context)!;
    final greyTextStyle = const TextStyle(
        color: _UIColors.color_666666,
        fontSize: 12,
        decoration: TextDecoration.none,
        fontWeight: FontWeight.w400);
    final contentTextStyle = const TextStyle(
        color: _UIColors.black_333333,
        fontSize: 14,
        decoration: TextDecoration.none,
        fontWeight: FontWeight.w500);
    final boxDecoration = const BoxDecoration(
      color: _UIColors.color_337eff,
      borderRadius: BorderRadius.all(Radius.circular(4)),
    );
    return ValueListenableBuilder(
        valueListenable: _waitingRoomCountTipListenable,
        builder: (context, value, child) {
          return ValueListenableBuilder<int>(
              valueListenable:
                  waitingRoomManager.waitingRoomMemberCountListenable,
              builder: (context, count, child) {
                return Visibility(
                    visible: value == MeetingNotifyDialogCountTipType.show &&
                        count != 0,
                    child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                            padding: EdgeInsets.all(16),
                            margin: EdgeInsets.only(
                              left: 16,
                              right: 16,
                              bottom:
                                  94 + MediaQuery.of(context).padding.bottom,
                            ),
                            decoration: BoxDecoration(
                              color: _UIColors.white,
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8)),
                            ),
                            constraints: BoxConstraints(maxWidth: 344),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Container(
                                        width: 24,
                                        height: 24,
                                        padding: EdgeInsets.all(4),
                                        decoration: boxDecoration,
                                        child: Icon(
                                          NEMeetingIconFont
                                              .icon_yx_tv_attendeex,
                                          color: _UIColors.white,
                                          size: 16,
                                        )),
                                    SizedBox(width: 8),
                                    Text(
                                        NEMeetingUIKitLocalizations.of(context)!
                                            .participantAttendees,
                                        style: greyTextStyle),
                                    Spacer(),
                                    Container(
                                        height: 24,
                                        alignment: Alignment.topRight,
                                        child: GestureDetector(
                                            key: MeetingUIValueKeys
                                                .waitingRoomCountTipClose,
                                            onTap: () =>
                                                _updateWaitingRoomCountTip(
                                                    MeetingNotifyDialogCountTipType
                                                        .hide),
                                            child: Icon(
                                              NEMeetingIconFont
                                                  .icon_yx_tv_duankaix,
                                              color: _UIColors.color_666666,
                                              size: 14,
                                            )))
                                  ]),
                                  SizedBox(height: 6),
                                  RichText(
                                      textAlign: TextAlign.start,
                                      text: TextSpan(children: <TextSpan>[
                                        TextSpan(
                                            text: localizations
                                                .waitingRoomCount(count)
                                                .split('$count')
                                                .first,
                                            style: contentTextStyle),
                                        TextSpan(
                                          text: ' $count ',
                                          style: TextStyle(
                                              color: _UIColors.color_337eff,
                                              fontSize: 14,
                                              decoration: TextDecoration.none,
                                              fontWeight: FontWeight.w500),
                                        ),
                                        TextSpan(
                                            text: localizations
                                                .waitingRoomCount('$count')
                                                .split('$count')
                                                .last,
                                            style: contentTextStyle)
                                      ])),
                                  SizedBox(height: 6),
                                  Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        GestureDetector(
                                          child: Text(
                                            localizations.globalNoLongerRemind,
                                            style: greyTextStyle,
                                          ),
                                          onTap: () =>
                                              _updateWaitingRoomCountTip(
                                                  MeetingNotifyDialogCountTipType
                                                      .noLongerRemind),
                                        ),
                                        SizedBox(width: 16),
                                        GestureDetector(
                                          child: Container(
                                              decoration: boxDecoration,
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 4, horizontal: 12),
                                              child: Text(
                                                localizations.globalViewMessage,
                                                style: TextStyle(
                                                    color: _UIColors.white,
                                                    fontSize: 12,
                                                    decoration:
                                                        TextDecoration.none,
                                                    fontWeight:
                                                        FontWeight.w400),
                                              )),
                                          onTap: () {
                                            _updateWaitingRoomCountTip(
                                                MeetingNotifyDialogCountTipType
                                                    .hide);
                                            _onMember(
                                                pageType: _MembersPageType
                                                    .waitingRoom);
                                          },
                                        )
                                      ])
                                ]))));
              });
        });
  }

  // final pageViewScrolling = ValueNotifier(false);
  // 滑动时是否展示视频，ios 默认展示视频预览，android 默认不展示
  // Android 在滑动时会出现闪屏：https://github.com/flutter/flutter/issues/144532
  static late final enableVideoPreviewOnScrolling = Platform.isIOS;

  // 允许打开视频预览的页面下标
  final enableVideoPreviewPageIndex = ValueNotifier(0);

  bool enableVideoPreviewForUser(NERoomMember user, int page) {
    final enableVideoPreview = Platform.isIOS // ios 默认开启
        ||
        enableVideoPreviewPageIndex.value == page // 用户属于当前页
        ||
        (user.uuid == roomContext.localMember.uuid &&
            smallUid == user.uuid); // 本地小画面
    debugPrint(
        'enableVideoPreviewPageIndex: ${user.name}, $page, $enableVideoPreview');
    return enableVideoPreview;
  }

  /// 当 PageView 左右滑动时，超出滑动页面 2 / 3 时，开启下一页的视频预览
  bool handlePageViewScrollNotification(ScrollNotification notification) {
    if (Platform.isAndroid && notification.depth == 0) {
      if (notification is ScrollStartNotification ||
          notification is ScrollEndNotification) {
        enableVideoPreviewPageIndex.value = pageViewCurrentIndex.value;
      } else if (notification
          case ScrollUpdateNotification(
            metrics: PageMetrics(
              :var pixels,
              :var viewportDimension,
            )
          )) {
        final oldIndex = enableVideoPreviewPageIndex.value;
        final newIndex = pageViewCurrentIndex.value;
        if (oldIndex != newIndex) {
          final moveRight = newIndex > oldIndex;
          final pixel = _galleryModePageController!.position.pixels;
          const ratio = 2.0 / 3;
          final nextPage60Extent = moveRight
              ? (oldIndex + ratio) * viewportDimension
              : (oldIndex - ratio) * viewportDimension;
          print(
              'ScrollUpdateNotification: $viewportDimension, $moveRight, $pixels, $nextPage60Extent');
          if (moveRight && pixel > nextPage60Extent) {
            enableVideoPreviewPageIndex.value = newIndex;
          } else if (!moveRight && pixel < nextPage60Extent) {
            enableVideoPreviewPageIndex.value = newIndex;
          }
        }
      }
    }
    return false;
  }

  Widget _buildNotifyMessageTip() {
    final localizations = NEMeetingUIKitLocalizations.of(context)!;
    final boxDecoration = const BoxDecoration(
      color: _UIColors.color_337eff,
      borderRadius: BorderRadius.all(Radius.circular(4)),
    );
    return ValueListenableBuilder(
        valueListenable: _notifyMessageTipListenable,
        builder: (context, value, child) {
          return ValueListenableBuilder<List<NEMeetingCustomSessionMessage>>(
              valueListenable: unreadNotifyMessageListenable,
              builder: (context, sessionMessageList, child) {
                CardData? cardData = sessionMessageList.lastOrNull?.data?.data;
                List<PopUpCardBottomButton>? popUpCardBottomButtonList =
                    cardData?.notifyCard?.popUpCardBottomButton;
                NESingleStateMenuItem<NEMeetingWebAppItem>? item;
                if (webAppList.isNotEmpty && cardData?.pluginId != null) {
                  item = webAppList.firstWhere((element) =>
                      element.singleStateItem.customObject?.pluginId ==
                      cardData?.pluginId);
                }
                String? pluginId = item?.singleStateItem.customObject?.pluginId;
                return Visibility(
                    visible: value == MeetingNotifyDialogCountTipType.show,
                    child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                            padding: EdgeInsets.all(16),
                            margin: EdgeInsets.only(
                              left: 16,
                              right: 16,
                              bottom:
                                  94 + MediaQuery.of(context).padding.bottom,
                            ),
                            decoration: BoxDecoration(
                              color: _UIColors.white,
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8)),
                            ),
                            constraints: BoxConstraints(maxWidth: 344),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    if (cardData?.notifyCard?.header?.icon !=
                                        null)
                                      MeetingCachedNetworkImage
                                          .CachedNetworkImage(
                                        width: 24,
                                        height: 24,
                                        imageUrl:
                                            '${cardData?.notifyCard?.header?.icon}',
                                        fit: BoxFit.cover,
                                      ),
                                    Expanded(
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(left: 6.0),
                                        child: Text(
                                          '${cardData?.notifyCard?.header?.subject}',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 16,
                                              decoration: TextDecoration.none,
                                              color: _UIColors.color_999999,
                                              fontWeight: FontWeight.normal),
                                        ),
                                      ),
                                    ),
                                    Spacer(),
                                    Container(
                                        height: 24,
                                        alignment: Alignment.topRight,
                                        child: GestureDetector(
                                            onTap: () {
                                              _updateNotifyMessageTip(
                                                  MeetingNotifyDialogCountTipType
                                                      .hide);
                                            },
                                            child: Icon(
                                              NEMeetingIconFont
                                                  .icon_yx_tv_duankaix,
                                              color: _UIColors.color_666666,
                                              size: 14,
                                            )))
                                  ]),
                                  Container(
                                    alignment: Alignment.centerLeft,
                                    padding: EdgeInsets.only(top: 6, bottom: 6),
                                    child: Text(
                                      '${cardData?.notifyCard?.body?.title}',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: TextStyle(
                                          fontSize: 14,
                                          decoration: TextDecoration.none,
                                          color: _UIColors.black_333333,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  if (popUpCardBottomButtonList != null &&
                                      popUpCardBottomButtonList.length > 0)
                                    Container(
                                      height: 24,
                                      alignment: Alignment.centerRight,
                                      child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          shrinkWrap: true,
                                          physics:
                                              NeverScrollableScrollPhysics(),
                                          itemCount:
                                              popUpCardBottomButtonList.length,
                                          itemBuilder: (context, index) {
                                            return GestureDetector(
                                                child: Container(
                                                  padding: EdgeInsets.only(
                                                      left: 12, right: 12),
                                                  margin: EdgeInsets.only(
                                                      left:
                                                          index == 0 ? 0 : 12),
                                                  decoration: (popUpCardBottomButtonList[
                                                                      index]
                                                                  .action ==
                                                              null ||
                                                          popUpCardBottomButtonList[
                                                                      index]
                                                                  .action ==
                                                              MeetingNotifyCenterActionUtil
                                                                  .action_no_more_remind)
                                                      ? null
                                                      : boxDecoration,
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    textAlign: TextAlign.center,
                                                    popUpCardBottomButtonList[
                                                                index]
                                                            .name ??
                                                        localizations
                                                            .globalViewMessage,
                                                    style: TextStyle(
                                                        color: (popUpCardBottomButtonList[
                                                                            index]
                                                                        .action ==
                                                                    null ||
                                                                popUpCardBottomButtonList[
                                                                            index]
                                                                        .action ==
                                                                    MeetingNotifyCenterActionUtil
                                                                        .action_no_more_remind)
                                                            ? _UIColors
                                                                .color_666666
                                                            : _UIColors.white,
                                                        fontSize: 12,
                                                        decoration:
                                                            TextDecoration.none,
                                                        fontWeight:
                                                            FontWeight.w400),
                                                  ),
                                                ),
                                                onTap: () {
                                                  if (popUpCardBottomButtonList[
                                                                  index]
                                                              .action !=
                                                          null &&
                                                      item != null) {
                                                    if (popUpCardBottomButtonList[
                                                                index]
                                                            .action ==
                                                        MeetingNotifyCenterActionUtil
                                                            .action_no_more_remind) {
                                                      _updateNotifyMessageTip(
                                                          MeetingNotifyDialogCountTipType
                                                              .noLongerRemind);
                                                      return;
                                                    }
                                                    if (!_isWebApp(
                                                            item.itemId) &&
                                                        pluginId != null) {
                                                      commonLogger.e(
                                                          'the plugin is not webapp');
                                                      return;
                                                    }
                                                    _updateNotifyMessageTip(
                                                        MeetingNotifyDialogCountTipType
                                                            .hide);
                                                    _unreadNotifyMessageListenable
                                                        .value
                                                        .removeWhere((element) =>
                                                            element.sessionId ==
                                                            item
                                                                ?.singleStateItem
                                                                .customObject
                                                                ?.sessionId);
                                                    _unReadMoreMenuItemUnreadCountNotifier
                                                        ?.value = 0;
                                                    MeetingNotifyCenterActionUtil
                                                        .openPlugin(
                                                      context,
                                                      roomContext,
                                                      item,
                                                      clearAllMessage:
                                                          (String? sessionId) {
                                                        if (sessionId != null) {
                                                          _unreadNotifyMessageListenable
                                                              .value
                                                              .removeWhere(
                                                                  (element) =>
                                                                      element
                                                                          .sessionId ==
                                                                      sessionId);
                                                        }
                                                        if (_unreadNotifyMessageListenable
                                                                .value.length <=
                                                            0) {
                                                          _unReadMoreMenuItemUnreadCountNotifier
                                                              ?.value = 0;
                                                        }
                                                      },
                                                    );
                                                  } else {
                                                    _updateNotifyMessageTip(
                                                        MeetingNotifyDialogCountTipType
                                                            .hide);
                                                  }
                                                });
                                          }),
                                    ),
                                ]))));
              });
        });
  }

  @override
  void onChangeRecentSession(List<NEMeetingRecentSession> messages) {}

  @override
  void onDeleteAllSessionMessage(
      String sessionId, NEMeetingSessionTypeEnum sessionType) {}

  @override
  void onDeleteSessionMessage(NEMeetingCustomSessionMessage message) {}

  @override
  void onReceiveSessionMessage(NEMeetingCustomSessionMessage message) {
    if (message.sessionType == NEMeetingSessionTypeEnum.P2P &&
        message.data?.data?.meetingId == arguments.meetingInfo.meetingId &&
        !_unreadNotifyMessageListenable.value.contains(message)) {
      _unreadNotifyMessageListenable.value.add(message);
      _unReadMoreMenuItemUnreadCountNotifier?.value =
          _unreadNotifyMessageListenable.value.length;
      _allNotifyMessageList.value = List.of(_allNotifyMessageList.value)
        ..add(message);
      _updateNotifyMessageTip(MeetingNotifyDialogCountTipType.show);
      _hideMorePopupMenu();
    }
  }

  void _onNotifyCenter() {
    _updateNotifyMessageTip(MeetingNotifyDialogCountTipType.hide);
    List<String> sessionIdList =
        MeetingNotifyCenterActionUtil.convertToSessionList(webAppList);
    _unreadNotifyMessageListenable.value.clear();
    _unReadMoreMenuItemUnreadCountNotifier?.value = 0;
    showMeetingPopupPageRoute(
      context: context,
      builder: (context) => wrapWithWatermark(
          child: MeetingUINotifyMessagePage(
              onClearAllMessage: () {
                /// 清理对应sessionId的消息
                _unreadNotifyMessageListenable.value.clear();
                _allNotifyMessageList.value = [];
              },
              sessionIdList: sessionIdList,
              messageList: _allNotifyMessageList,
              roomContext: roomContext,
              webAppList: webAppList)),
      routeSettings: RouteSettings(name: MeetingUINotifyMessagePage.routeName),
    ).then((value) {
      _unreadNotifyMessageListenable.value.clear();
      _unReadMoreMenuItemUnreadCountNotifier?.value = 0;
    });
  }

  void showReclaimHostDialogIfNeeded() {
    var curHost = roomContext.getHostMember();
    if (curHost != null && roomContext.canReclaimHost) {
      showConfirmDialog(
        title: meetingUiLocalizations.meetingReclaimHost,
        message: meetingUiLocalizations.meetingReclaimHostTip(curHost.name),
        cancelLabel: meetingUiLocalizations.meetingReclaimHostCancel,
        okLabel: meetingUiLocalizations.meetingReclaimHost,
        contentWrapperBuilder: (child) {
          return AutoPopScope(
            child: child,
            listenable: isMySelfHostListenable,
          );
        },
      ).then((value) {
        if (!mounted || value != true) return;
        roomContext.getHostMember().guard((user) {
          roomContext.reclaimHost(user.uuid).onFailure((code, msg) {
            showToast(msg ?? meetingUiLocalizations.globalOperationFail);
          }).ignore();
        });
      });
    }
  }

  /// 展示邀请
  /// [user] 邀请的用户
  ///
  void handleInviteCall(NERoomMember user) {
    if (!isSelf(user.uuid) &&
        user.inviteState != NERoomMemberInviteState.calling &&
        user.inviteState != NERoomMemberInviteState.waitingJoin) {
      if (user.isInAppInviting == true) {
        roomContext.appInviteController.callByUserUuid(user.uuid);
      } else if (user.isInSIPInviting == true) {
        roomContext.sipController.callByUserUuid(user.uuid);
      }
    }
  }

  /// 展示邀请
  /// [user] 邀请的用户
  /// [child] 邀请的用户头像
  Widget _buildMeetingInviteWrapper(
      {required Widget child, required NERoomMember user}) {
    return (!user.isInAppInviting && !user.isInSIPInviting)
        ? child
        : GestureDetector(
            onTap: () => handleInviteCall(user),
            child: MeetingInviteWrapper(
              inviteType:
                  user.isInAppInviting ? InviteType.app : InviteType.sip,
              isCalling: user.inviteState == NERoomMemberInviteState.calling &&
                  !isSelf(user.uuid),
              child: child,
            ));
  }
}

extension MeetingToastExtension on MeetingStateScope {
  void showToast(String message, {bool isError = false}) {
    if (mounted && meetingUIState.isMinimized != true) {
      ToastUtils.showToast(context, message, isError: isError);
    }
  }
}

class NERoomUserAudioVolumeInfo {
  /// 用户 ID
  final String userId;

  /// 音量[0-100]
  final int volume;

  NERoomUserAudioVolumeInfo(this.userId, this.volume);
}

class NetWorkRttInfo {
  int networkDownRtt;
  int upLossRate;
  int downLossRate;

  NetWorkRttInfo(this.networkDownRtt, this.upLossRate, this.downLossRate);
}

enum _NetworkStatus {
  good,
  normal,
  poor,
  unknown,
}

enum _CloudRecordState {
  notStarted,
  starting,
  started,
}

bool _isScreenShareSupported() {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    final osVer = '${DeviceInfo.osVer}.0';
    return (double.tryParse(osVer.substring(0, osVer.indexOf(r'.'))) ?? 0) >=
        12;
  }
  return defaultTargetPlatform == TargetPlatform.android;
}

bool _isAudioShareSupported() {
  if (Platform.isAndroid) {
    return DeviceInfo.sdkInt >= 29;
  }
  return _isScreenShareSupported();
}

class _LockCameraVideoViewListener extends NERoomUserVideoViewListener {
  final void Function(String uid, int width, int height) action;

  _LockCameraVideoViewListener(this.action);

  void onFrameResolutionChanged(
      String userId, int width, int height, int rotation) {
    action(userId, width, height);
  }
}

extension _NERoomEndReasonStringify on NERoomEndReason {
  String get camelCaseName {
    switch (this) {
      case NERoomEndReason.kLeaveBySelf:
        return "leaveBySelf";
      case NERoomEndReason.kSyncDataError:
        return "syncDataError";
      case NERoomEndReason.kKickBySelf:
        return "kickBySelf";
      case NERoomEndReason.kKickOut:
        return "kickOut";
      case NERoomEndReason.kCloseByMember:
        return "closeByMember";
      case NERoomEndReason.kEndOfLife:
        return "endOfLife";
      case NERoomEndReason.kEndOfRtc:
        return "endOfRtc";
      case NERoomEndReason.kAllMemberOut:
        return "allMembersOut";
      case NERoomEndReason.kCloseByBackend:
        return "closeByBackend";
      case NERoomEndReason.kLoginStateError:
        return "loginStateError";
      default:
        return "unknown";
    }
  }
}

enum MeetingNotifyDialogCountTipType {
  show,
  hide,
  noLongerRemind,
}

enum _GridLayoutMode {
  audio,
  video,
}
