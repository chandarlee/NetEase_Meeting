// Copyright (c) 2022 NetEase, Inc. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'meeting_app_localizations.dart';

/// The translations for English (`en`).
class MeetingAppLocalizationsEn extends MeetingAppLocalizations {
  MeetingAppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get globalAppName => 'NetEase Meeting';

  @override
  String get globalSure => 'OK';

  @override
  String get globalOK => 'Confirm';

  @override
  String get globalQuit => 'Quit';

  @override
  String get globalAgree => 'Agree';

  @override
  String get globalDisagree => 'Disagree';

  @override
  String get globalCancel => 'Cancel';

  @override
  String get globalCopy => 'Copy';

  @override
  String get globalCopySuccess => 'Copied';

  @override
  String get globalApplication => 'Apps';

  @override
  String get globalNo => 'No';

  @override
  String get globalYes => 'Yes';

  @override
  String get globalComplete => 'Complete';

  @override
  String get globalResume => 'Resume';

  @override
  String get globalCopyright =>
      'Copyright ©1997-2024 NetEase Inc.\nAll Rights Reserved.';

  @override
  String get globalAppRegistryNO => '浙ICP17006647号-124A';

  @override
  String get globalNetworkUnavailableCheck =>
      'Network connection failed, please check your network connection!';

  @override
  String get globalNetworkNotAvailable =>
      'The network is not available, please check the network settings.';

  @override
  String get globalNetworkNotAvailableTitle =>
      'The network connection is unavailable.';

  @override
  String get globalNetworkNotAvailablePart1 =>
      'Failed to connect to the Internet.';

  @override
  String get globalNetworkNotAvailablePart2 =>
      'If you need to connect to the Internet, you can refer to the following methods:';

  @override
  String get globalNetworkNotAvailablePart3 =>
      'If the device is connected to a Wi-Fi network:';

  @override
  String get globalNetworkNotAvailableTip1 =>
      'Your device is not enabled for mobile or Wi Fi networks';

  @override
  String get globalNetworkNotAvailableTip2 =>
      'Select an available Wi-Fi hotspot access in the Settings panel of the device \"Settings\"-\"Wi-Fi Network\".';

  @override
  String get globalNetworkNotAvailableTip3 =>
      '• Enable cellular data in the Settings panel of the device\'s Settings - Networks (carriers may charge for data communications after enabling it).';

  @override
  String get globalNetworkNotAvailableTip4 =>
      'Check whether the Wi-Fi hotspot your device is connected to is connected to the Internet, or whether the hotspot allows your device to access the Internet.';

  @override
  String get globalYear => '';

  @override
  String get globalMonth => '';

  @override
  String get globalDay => '';

  @override
  String get globalSave => 'Save';

  @override
  String get globalSunday => 'Sun.';

  @override
  String get globalMonday => 'Mon.';

  @override
  String get globalTuesday => 'Tues.';

  @override
  String get globalWednesday => 'Wed.';

  @override
  String get globalThursday => 'Thur.';

  @override
  String get globalFriday => 'Fri.';

  @override
  String get globalSaturday => 'Sat.';

  @override
  String get globalNotify => 'Notification';

  @override
  String get globalSubmit => 'Submit';

  @override
  String get globalEdit => 'Edit';

  @override
  String get globalIKnow => 'Got it';

  @override
  String get authImmediatelyRegister => 'Register Now';

  @override
  String get authLoginBySSO => 'SSO';

  @override
  String get authPrivacyCheckedTips =>
      'Please agree to the Privacy Policy and User Service Agreement first.';

  @override
  String get authLogin => 'Log in';

  @override
  String get authRegisterAndLogin => 'Register/Login';

  @override
  String get authServiceAgreement => 'Service agreement';

  @override
  String get authPrivacy => 'Privacy Policy';

  @override
  String get authPrivacyDialogTitle => 'Service Agreement and Privacy Policy';

  @override
  String get authUserProtocolAndPrivacy =>
      'Service Agreement and Privacy Policy';

  @override
  String get authNetEaseServiceAgreement =>
      'NetEase Meeting Services Agreement';

  @override
  String get authNeteasePrivacy => 'NetEase Meeting Privacy Policy';

  @override
  String authPrivacyDialogMessage(
      Object neteasePrivacy, Object neteaseUserProtocol) {
    return 'NetEase Meeting is an audio and video conference software product provided to you by NetEase. We will use \"$neteaseUserProtocol\" and \"$neteasePrivacy\" to help you understand how the conference software processes personal information and your rights and obligations. If you agree, click agree to accept our services.';
  }

  @override
  String get authLoginOnOtherDevice =>
      'The number of devices logged in at the same time exceeds the limit and has been automatically logged out.';

  @override
  String get authLoginTokenExpired =>
      'Login status has expired. Please log in again';

  @override
  String get authInputEmailHint => 'Please enter the complete email address';

  @override
  String get authAndLogin => 'Authorize and login';

  @override
  String get authNoAuth => 'Please log in first';

  @override
  String authHasReadAndAgreeToPolicy(
      Object neteasePrivacy, Object neteaseUserProtocol) {
    return 'I have read and agreed to NetEase Meeting $neteasePrivacy and $neteaseUserProtocol';
  }

  @override
  String get authHasReadAndAgreeMeeting =>
      'I have read and agreed to NetEase Meeting';

  @override
  String get authAnd => 'And';

  @override
  String get authNextStep => 'Next';

  @override
  String get authMobileNotRegister =>
      'The mobile phone number is not registered.';

  @override
  String get authVerifyCodeErrorTip => 'Verification code error';

  @override
  String get authEnterCheckCode => 'Please enter the verification code';

  @override
  String get authEnterMobile => 'Please enter your phone number';

  @override
  String get authGetCheckCode => 'Get code';

  @override
  String get authNewRegister => 'New user registration';

  @override
  String get authCheckMobile => 'Verify the phone number';

  @override
  String get authLoginByPassword => 'Password login';

  @override
  String get authLoginByMobile => 'Verification code login';

  @override
  String get authRegister => 'Register';

  @override
  String get authEnterAccount => 'Enter account';

  @override
  String get authEnterPassword => 'Enter password';

  @override
  String get authEnterNick => 'Please enter the name';

  @override
  String get authCompleteSelfInfo => 'Improve personal information';

  @override
  String authResendCode(Object second) {
    return 'Resend in $second seconds.';
  }

  @override
  String authCheckCodeHasSendToMobile(Object mobile) {
    return 'The code has been sent to $mobile. Please enter the code below.';
  }

  @override
  String get authResend => 'Resend';

  @override
  String get authEnterCorpCode => 'Please enter the enterprise code.';

  @override
  String get authSSOTip => 'No affiliated enterprise.';

  @override
  String get authSSONotSupport => 'SSO login is not supported.';

  @override
  String get authSSOLoginFail => 'SSO login failed.';

  @override
  String get authEnterCorpMail => 'Please enter the enterprise email address.';

  @override
  String get authForgetPassword => 'Forgot password';

  @override
  String get authPhoneErrorTip => 'The phone number is invalid';

  @override
  String get authPleaseLoginFirst => 'Please login NetEase Meeting first';

  @override
  String get authResetInitialPasswordTitle => 'Set a new password';

  @override
  String get authResetInitialPasswordDialogTitle => 'Set a new password';

  @override
  String get authResetInitialPasswordDialogMessage =>
      'For security reasons, it is recommended to set a new password';

  @override
  String get authResetInitialPasswordDialogCancelLabel => 'Not Now';

  @override
  String get authResetInitialPasswordDialogOKLabel => 'Go to Settings';

  @override
  String get authMobileNum => 'Mobile phone number';

  @override
  String get authUnavailable => 'None';

  @override
  String get authNoCorpCode => 'No code?';

  @override
  String get authCreateAccountByPC => 'Go to the desktop to create';

  @override
  String get authCreateNow => 'Create Now';

  @override
  String get authLoginToCorpEdition => 'Official';

  @override
  String get authLoginToTrialEdition => 'Experience';

  @override
  String get authCorpNotFound => 'No enterprise is matched';

  @override
  String get authHasCorpCode => 'Existing enterprise code?';

  @override
  String get authLoginByCorpCode => 'Enterprise code login';

  @override
  String get authLoginByCorpMail => 'Enterprise email login';

  @override
  String get authOldPasswordError => 'Password error, please re-enter';

  @override
  String get authEnterOldPassword => 'Please enter the old password';

  @override
  String get authSuggestChrome => 'Chrome browser is recommended';

  @override
  String get meetingCreate => 'Start';

  @override
  String get meetingNetworkAbnormalityCheckAndRejoin =>
      'Network abnormality, please check the network connection and rejoin the meeting.';

  @override
  String get meetingRecover =>
      'Detected your last abnormal exit. Do you want to resume the meeting?';

  @override
  String get meetingJoin => 'Join';

  @override
  String get meetingSchedule => 'Schedule';

  @override
  String get meetingScheduleListEmpty => 'No meetings';

  @override
  String get meetingToday => 'Today';

  @override
  String get meetingTomorrow => 'Tomorrow';

  @override
  String get meetingNum => 'Meeting ID';

  @override
  String get meetingStatusInit => 'Upcoming';

  @override
  String get meetingStatusStarted => 'Ongoing';

  @override
  String get meetingStatusEnded => 'Ended';

  @override
  String get meetingStatusRecycle => 'Recovered';

  @override
  String get meetingStatusCancel => 'Cancelled';

  @override
  String get meetingOperationNotSupportedInMeeting =>
      'This operation is not supported in the meeting.';

  @override
  String get meetingPersonalMeetingID => 'Personal Meeting ID';

  @override
  String get meetingPersonalShortMeetingID => 'Short ID';

  @override
  String get meetingUsePersonalMeetId => 'Use personal meeting ID';

  @override
  String get meetingPassword => 'Password';

  @override
  String get meetingEnterSixDigitPassword => 'Enter a 6-digit password';

  @override
  String get meetingJoinCameraOn => 'Camera On';

  @override
  String get meetingJoinMicrophoneOn => 'Microphone On';

  @override
  String get meetingJoinCloudRecordOn => 'Enable meeting recording';

  @override
  String get meetingCreateAlreadyInTip =>
      'The meeting is still in progress. Would you like to join the meeting?';

  @override
  String get meetingCreateFail => 'Failed to create the meeting';

  @override
  String get meetingJoinFail => 'Failed to join the meeting';

  @override
  String get meetingEnterId => 'Enter meeting ID';

  @override
  String meetingSubject(Object userName) {
    return '$userName\'s Scheduled Meeting';
  }

  @override
  String get meetingScheduleNow => 'Schedule';

  @override
  String get meetingEnterPassword => 'Enter the meeting Password';

  @override
  String get meetingScheduleTimeIllegal =>
      'Appointment time cannot be earlier than the current time.';

  @override
  String get meetingScheduleSuccess => 'Scheduled successfully';

  @override
  String get meetingDurationTooLong =>
      'The duration of the meeting is too long';

  @override
  String get meetingInfo => 'Meeting information';

  @override
  String get meetingSecurity => 'Security';

  @override
  String get meetingEnableWaitingRoom => 'Enable Waiting Room';

  @override
  String get meetingWaitingRoomHint =>
      'Participants enter the waiting room before joining the meeting.';

  @override
  String get meetingAttendeeAudioOff => 'Mute participants upon entry';

  @override
  String get meetingAttendeeAudioOffAllowOn =>
      'Automatically mute and allow attendees to turn on the Mic.';

  @override
  String get meetingAttendeeAudioOffNotAllowOn =>
      'Automatically mute and disallow attendees to turn on the Mic.';

  @override
  String get meetingEnterTopic => 'Enter meeting topic';

  @override
  String get meetingEndTime => 'End Time';

  @override
  String get meetingChooseDate => 'Date';

  @override
  String get meetingLiveOn => 'Enable Live';

  @override
  String get meetingLiveUrl => 'Live URL';

  @override
  String get meetingLiveLevelTip => 'Only employees can watch';

  @override
  String get meetingRecordOn =>
      'Start recording when participants join the meeting';

  @override
  String get meetingInviteUrl => 'Meeting URL';

  @override
  String get meetingLiveLevel => 'Live Mode';

  @override
  String get meetingCancel => 'Cancel Meeting';

  @override
  String get meetingCancelConfirm => 'Are you sure to cancel the meeting?';

  @override
  String get meetingNotCancel => 'Not Now';

  @override
  String get meetingEdit => 'Edit Meeting';

  @override
  String get meetingScheduleEditSuccess => 'Modified successfully';

  @override
  String get meetingInfoDialogMeetingTitle => 'Title';

  @override
  String get meetingDeepLinkTipAlreadyInMeeting =>
      'You are already in the meeting';

  @override
  String get meetingDeepLinkTipAlreadyInDifferentMeeting =>
      'You are in another meeting. Please exit the meeting and try again';

  @override
  String get meetingShareScreenTips =>
      'Everything on your screen, including notifications, will be recorded. Please be alert to the fraud of counterfeiting customer service, campus loan and public security law, and don\'t make financial transfer when sharing the screen.';

  @override
  String get meetingForegroundContentText => 'Netease Meeting is running.';

  @override
  String get meetingId => 'Meeting ID:';

  @override
  String get meetingStartTime => 'Start Time';

  @override
  String get meetingCloseByHost => 'The host has ended the meeting';

  @override
  String get meetingEndOfLife =>
      'The meeting duration has reached the upper limit. The meeting is closed.';

  @override
  String get meetingSwitchOtherDevice =>
      'You have exited the meeting because the host moved out or switched to another device.';

  @override
  String get meetingSyncDataError =>
      'Meeting information synchronization failed.';

  @override
  String get meetingEnd => 'The meeting has ended.';

  @override
  String get meetingMicrophone => 'Microphone';

  @override
  String get meetingCamera => 'Camera';

  @override
  String get meetingDetail => 'Meeting details';

  @override
  String get meetingInfoDialogMeetingDateFormat => 'yyyy-MM-dd';

  @override
  String get meetingHasBeenCanceled =>
      'The meeting has been cancelled by another login device';

  @override
  String get historyMeeting => 'Meeting history';

  @override
  String get historyAllMeeting => 'All Meetings';

  @override
  String get historyCollectMeeting => 'Favorites';

  @override
  String get historyMeetingListEmpty => 'No history meetings';

  @override
  String get historyChat => 'Chat History';

  @override
  String get historyMeetingOwner => 'Founder';

  @override
  String get historyMeetingCloudRecord => 'Cloud Recording';

  @override
  String get historyMeetingCloudRecordingFileBeingGenerated =>
      'Generating cloud recording file';

  @override
  String get settings => 'Settings';

  @override
  String get settingDefaultCompanyName => 'Unaffiliated enterprise';

  @override
  String get settingInternalDedicated => 'Internal Use Only';

  @override
  String get settingMeeting => 'Meeting Settings';

  @override
  String get settingFeedback => 'Feedback';

  @override
  String get settingBeauty => 'Beauty';

  @override
  String get settingVirtualBackground => 'Background';

  @override
  String get settingAbout => 'About';

  @override
  String get settingSetMeetingNick => 'Setting a name';

  @override
  String get settingSetMeetingTips =>
      'Please enter Chinese, English or numbers.';

  @override
  String get settingValidatorNickTip =>
      'Max 20 characters, including Chinese characters, letters, and numbers';

  @override
  String get settingModifySuccess => 'Modified successfully';

  @override
  String get settingModifyFailed => 'Modified failed';

  @override
  String get settingCheckUpdate => 'Check for updates';

  @override
  String get settingFindNewVersion => 'New Version';

  @override
  String get settingAlreadyLatestVersion => 'It\'s already the latest version';

  @override
  String get settingVersion => 'Version:';

  @override
  String get settingAccountAndSafety => 'Account  Security';

  @override
  String get settingModifyPassword => 'Change Password';

  @override
  String get settingEnterNewPasswordTips => 'Enter new password';

  @override
  String get settingEnterPasswordConfirm => 'Enter the new password again';

  @override
  String get settingValidatorPwdTip =>
      '6-18 characters, including uppercase and lowercase letters and numbers.';

  @override
  String get settingPasswordDifferent =>
      'The two new passwords are different. Please re-enter them';

  @override
  String get settingPasswordSameToOld =>
      'The new password is the same as the old one. Please enter it again';

  @override
  String get settingPasswordFormatError =>
      'Password format is incorrect, please re-enter';

  @override
  String get settingCompany => 'Enterprise';

  @override
  String get settingSwitchCompanyFail =>
      'Failed to switch the enterprise. Check the network';

  @override
  String get settingAudioAINS => 'Smart Noise Reduction';

  @override
  String get settingShowShareUserVideo =>
      'Enable the shared person camera when sharing';

  @override
  String get settingEnableTransparentWhiteboard =>
      'Set the whiteboard to transparent';

  @override
  String get settingEnableFrontCameraMirror => 'Front camera mirroring';

  @override
  String get settingOpenCameraMeeting => 'Camera on by default';

  @override
  String get settingOpenMicroMeeting => 'Microphone on by default';

  @override
  String get settingShowMeetDuration => 'Show Meeting Duration';

  @override
  String get settingEnableAudioDeviceSwitch => 'Allow audio device switching';

  @override
  String get settingRename => 'Rename';

  @override
  String get settingPackageVersion => 'Package Version';

  @override
  String get settingNick => 'Nickname';

  @override
  String get settingDeleteAccount => 'Cancel Account';

  @override
  String get settingEmail => 'Email';

  @override
  String get settingLogout => 'Log Out';

  @override
  String get settingLogoutConfirm => 'Are you sure you want to log out?';

  @override
  String get settingMobile => 'Phone';

  @override
  String get settingHead => 'Profile Photo';

  @override
  String get settingPersonalCenter => 'Personal Center';

  @override
  String get settingVersionUpgrade => 'Version Update';

  @override
  String get settingUpgradeNow => 'Update Now';

  @override
  String get settingUpgradeCancel => 'Not Update';

  @override
  String get settingDownloadFailTryAgain =>
      'Download failed, please try again.';

  @override
  String get settingInstallFailTryAgain =>
      'Installation failed, please try again.';

  @override
  String get settingModifyAndReLogin =>
      'After the modification, you need to log in again';

  @override
  String get settingServiceBundleTitle => 'Supported Meetings';

  @override
  String settingServiceBundleDetailLimitedMinutes(
      Object maxCount, Object maxMinutes) {
    return '$maxCount participants, limited time $maxMinutes minutes meeting';
  }

  @override
  String settingServiceBundleDetailUnlimitedMinutes(Object maxCount) {
    return '$maxCount participants，unlimited time meeting';
  }

  @override
  String get settingUpdateFailed => 'Update Failed';

  @override
  String get settingTryAgainLater => 'Next Time';

  @override
  String get settingRetryNow => 'Retry Now';

  @override
  String get settingUpdating => 'Updating';

  @override
  String get settingCancelUpdate => 'Cancel Update';

  @override
  String get settingExitApp => 'Exit App';

  @override
  String get settingNotUpdate => 'Not Update';

  @override
  String get settingUPdateNow => 'Update Now';

  @override
  String get settingComfirmExitApp => 'Confirm to exit the app';

  @override
  String get feedbackInRoom => 'Feedback';

  @override
  String get feedbackProblemType => 'Problem Type';

  @override
  String get feedbackSuccess => 'Feedback submitted successfully';

  @override
  String get feedbackAudioLatency => 'A large delay';

  @override
  String get feedbackAudioFreeze => 'Stuck';

  @override
  String get feedbackCannotHearOthers => 'Can\'t hear the other\'s voice';

  @override
  String get feedbackCannotHearMe => 'The others can\'t hear me';

  @override
  String get feedbackTitleExtras => 'Additional Information';

  @override
  String get feedbackTitleDate => 'Occurrence Time';

  @override
  String get feedbackContentEmpty => 'Empty';

  @override
  String get feedbackTitleSelectPicture => 'Picture';

  @override
  String get feedbackAudioMechanicalNoise => 'Mechanical sound';

  @override
  String get feedbackAudioNoise => 'Noise';

  @override
  String get feedbackAudioEcho => 'Echo';

  @override
  String get feedbackAudioVolumeSmall => 'Low volume';

  @override
  String get feedbackVideoFreeze => 'Long time stuck';

  @override
  String get feedbackVideoIntermittent => 'Video is intermittent';

  @override
  String get feedbackVideoTearing => 'Tearing';

  @override
  String get feedbackVideoTooBrightOrDark => 'Picture too bright/too dark';

  @override
  String get feedbackVideoBlurry => 'Blurred image';

  @override
  String get feedbackVideoNoise => 'Obvious noise';

  @override
  String get feedbackAudioVideoNotSync =>
      'Sound and picture are not synchronized';

  @override
  String get feedbackUnexpectedExit => 'Unexpected exit';

  @override
  String get feedbackOthers => 'There are other problems';

  @override
  String get feedbackTitleAudio => 'Audio problem';

  @override
  String get feedbackTitleVideo => 'Video problem';

  @override
  String get feedbackTitleOthers => 'Other';

  @override
  String get feedbackTitleDescription => 'Description';

  @override
  String get feedbackOtherTip =>
      'Please describe your problem (when you select \"There are other problems\"), you need to fill in a specific description before submitting';

  @override
  String get evaluationTitle =>
      'How likely are you to recommend NetEase Meeting to colleagues or partners?';

  @override
  String get evaluationCoreZero => '0- Definitely not';

  @override
  String get evaluationCoreTen => '10- With pleasure';

  @override
  String get evaluationHitTextOne =>
      '0-6: What are the points that make you dissatisfied or disappointed? (Optional)';

  @override
  String get evaluationHitTextTwo =>
      '7-8: What aspects do you think can be done better? (Optional)';

  @override
  String get evaluationHitTextThree =>
      '9-10: Welcome to share your experience of the best features or feelings (optional)';

  @override
  String get evaluationToast => 'Submit after scoring';

  @override
  String get evaluationThankFeedback => 'Thank you for your feedback';

  @override
  String get evaluationGoHome => 'Back Homepage';
}