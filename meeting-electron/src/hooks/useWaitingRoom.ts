import React, { useCallback, useEffect, useRef, useState } from 'react'
import {
  ActionType,
  EventType,
  MeetingEventType,
  MeetingSetting,
  NEMeetingInfo,
} from '../types'
import { useGlobalContext, useMeetingInfoContext } from '../store'
import { useTranslation } from 'react-i18next'
import usePreviewHandler from './usePreviewHandler'
import { formatDate } from '../utils'
import { getWindow } from '../utils/windowsProxy'
import { IPCEvent } from '../../app/src/types'
import Toast from '../components/common/toast'
import { NEMeetingLeaveType } from '../types/type'
import { errorCodeMap } from '../config'
import { NEResult } from 'neroom-web-sdk'

export function formateMsg(
  message: { type: string; text: string } | undefined,
  t: any
): string {
  if (message?.type === 'text') {
    return message.text
  } else if (message?.type === 'image') {
    return t('imageMsg')
  } else {
    return t('fileMsg')
  }
}

interface WaitingRoomProps {
  closeModalHandle: (data: {
    title: string
    content: string
    closeText: string
    reason: any
    notNeedAutoClose?: boolean
  }) => void
  handleVideoFrameData?: (uuid, bSubVideo, data, type, width, height) => void
}

type WaitingRoomReturn = {
  openAudio: boolean
  openVideo: boolean
  setOpenVideo: (openVideo: boolean) => void
  setOpenAudio: (openAudio: boolean) => void
  setting: MeetingSetting | null
  unReadMsgCount: number
  isOffLine: boolean
  nickname: string
  recordVolume: number
  meetingInfo: NEMeetingInfo
  meetingState: number
  showChatRoom: boolean
  handleOpenAudio: (openAudio: boolean) => void
  handleOpenVideo: (openVideo: boolean) => void
  handleOpenChatRoom: (openChatRoom: boolean) => void
  startPreview: (view: HTMLElement) => Promise<NEResult<null>> | undefined
  stopPreview: () => void
  openChatRoom: boolean
  formatMeetingTime: (startTime: number) => string
  videoCanvasWrapRef: React.RefObject<HTMLDivElement>
  setSetting: (setting: MeetingSetting) => void
  setOpenChatRoom: (openChatRoom: boolean) => void
  setUnReadMsgCount: (unReadMsgCount: number) => void
  setRecordVolume: (recordVolume: number) => void
}

export function useWaitingRoom(data: WaitingRoomProps): WaitingRoomReturn {
  const { handleVideoFrameData, closeModalHandle } = data

  const { t } = useTranslation()
  const [openAudio, setOpenAudio] = useState<boolean>(false)
  const [openVideo, setOpenVideo] = useState<boolean>(false)
  const [setting, setSetting] = useState<MeetingSetting | null>(null)
  const [unReadMsgCount, setUnReadMsgCount] = useState<number>(0)
  const [isOffLine, setIsOffLine] = useState<boolean>(false)
  const [nickname, setNickname] = useState('')
  const previewRoomListenerRef = useRef<any>(null)

  const [openChatRoom, setOpenChatRoom] = useState<boolean>(false)
  const videoCanvasWrapRef = useRef<HTMLDivElement>(null)
  const [recordVolume, setRecordVolume] = useState<number>(0)
  const { meetingInfo, dispatch } = useMeetingInfoContext()
  const [meetingState, setMeetingState] = useState(1)
  const [showChatRoom, setShowChatRoom] = useState(false)
  const {
    neMeeting,
    outEventEmitter,
    eventEmitter,
    dispatch: globalDispatch,
  } = useGlobalContext()
  const meetingInfoRef = useRef<NEMeetingInfo>(meetingInfo)
  const closeTimerRef = useRef<any>(null)

  usePreviewHandler()
  // useEventHandler()
  meetingInfoRef.current = meetingInfo

  function handleOpenAudio(openAudio: boolean) {
    dispatch?.({
      type: ActionType.UPDATE_MEETING_INFO,
      data: {
        isUnMutedAudio: !openAudio,
      },
    })
    const previewController = neMeeting?.previewController

    if (previewController) {
      if (openAudio) {
        previewController?.stopRecordDeviceTest().finally(() => {
          setOpenAudio(false)
        })
      } else {
        previewController
          ?.startRecordDeviceTest((level: number) => {
            setRecordVolume((level as number) * 10)
          })
          .then(() => {
            setOpenAudio(true)
          })
          .catch((e) => {
            if (e?.msg || errorCodeMap[e?.code]) {
              Toast.fail(e?.msg || t(errorCodeMap[e?.code]))
            } else if (
              e.data?.message &&
              (e.data?.message?.includes('Permission denied') ||
                e.data?.name?.includes('NotAllowedError'))
            ) {
              //@ts-ignore
              Toast.fail(t(errorCodeMap['10212']))
            }

            throw e
          })
      }
    }
  }

  async function handleOpenVideo(openVideo: boolean) {
    dispatch?.({
      type: ActionType.UPDATE_MEETING_INFO,
      data: {
        isUnMutedVideo: !openVideo,
      },
    })
    const previewController = neMeeting?.previewController

    if (previewController) {
      if (openVideo) {
        if (window.isElectronNative) {
          const code = stopPreview()

          //@ts-ignore
          if (code === 0) {
            setOpenVideo(false)
          }
        } else {
          try {
            await stopPreview()
          } finally {
            setOpenVideo(false)
          }
        }
      } else {
        if (window.isElectronNative) {
          const code = startPreview(videoCanvasWrapRef.current as HTMLElement)

          console.log('code>>>', code)
          // @ts-ignore
          if (code === 0) {
            setOpenVideo(true)
          }
        } else {
          try {
            await stopPreview()
          } finally {
            await startPreview(videoCanvasWrapRef.current as HTMLElement)
            setOpenVideo(true)
          }
        }
      }
    }
  }

  function addPreviewRoomListener() {
    if (!window.isElectronNative) {
      return
    }

    const previewConText = neMeeting?.roomService?.getPreviewRoomContext()

    if (!previewConText) {
      return
    }

    previewRoomListenerRef.current = {
      onLocalAudioVolumeIndication: (volume: number) => {
        // console.log('onLocalAudioVolumeIndication>>>', volume)
        setRecordVolume(volume)
      },
      onRtcVirtualBackgroundSourceEnabled: (
        enabled: boolean,
        reason: string
      ) => {
        const settingWindow = getWindow('settingWindow')

        settingWindow?.postMessage(
          {
            event: EventType.rtcVirtualBackgroundSourceEnabled,
            payload: {
              enabled,
              reason,
            },
          },
          settingWindow.origin
        )
      },
      //@ts-ignore
      onVideoFrameData: (uuid, bSubVideo, data, type, width, height) => {
        handleVideoFrameData?.(uuid, bSubVideo, data, type, width, height)
        const settingWindow = getWindow('settingWindow')

        settingWindow?.postMessage(
          {
            event: 'onVideoFrameData',
            payload: {
              uuid,
              bSubVideo,
              data,
              type,
              width,
              height,
            },
          },
          '*',
          [data.bytes.buffer]
        )
      },
    }
    //@ts-ignore
    previewConText?.addPreviewRoomListener(previewRoomListenerRef.current)
  }

  function removePreviewRoomListener() {
    if (previewRoomListenerRef.current) {
      const previewConText = neMeeting?.roomService?.getPreviewRoomContext()

      //@ts-ignore
      previewConText?.removePreviewRoomListener(previewRoomListenerRef.current)
    }
  }

  useEffect(() => {
    setNickname(meetingInfo?.localMember?.name || '')
  }, [meetingInfo?.localMember?.name])

  useEffect(() => {
    window.ipcRenderer?.on(IPCEvent.changeSetting, (event, setting) => {
      setSetting(setting)
    })
    const tmpSetting = localStorage.getItem('ne-meeting-setting')

    if (tmpSetting) {
      try {
        const _setting = JSON.parse(tmpSetting) as MeetingSetting

        setSetting(_setting)
      } catch (e) {
        console.log('parse setting error', e)
      }
    }

    neMeeting?._meetingInfo && setMeetingState(neMeeting?._meetingInfo.state)
  }, [])

  useEffect(() => {
    if (meetingInfo.isUnMutedAudio) {
      handleOpenAudio(false)
    }

    if (neMeeting?.alreadyJoin) {
      if (meetingInfo.localMember.isVideoOn) {
        handleOpenVideo(false)
      }

      if (meetingInfo.localMember.isAudioOn) {
        handleOpenAudio(false)
      }
    } else {
      if (meetingInfo.isUnMutedVideo) {
        handleOpenVideo(false)
      }

      return () => {
        setOpenChatRoom(false)
      }
    }
  }, [])
  function startPreview(view: HTMLElement) {
    const previewController = neMeeting?.previewController

    if (window.ipcRenderer) {
      previewController?.setupLocalVideoCanvas(view)
      return previewController?.startPreview()
    } else {
      return previewController?.startPreview(view).catch((e) => {
        if (e?.msg || errorCodeMap[e?.code]) {
          Toast.fail(e?.msg || t(errorCodeMap[e?.code]))
        } else if (
          e.data?.message &&
          e.data?.message?.includes('Permission denied')
        ) {
          //@ts-ignore
          Toast.fail(t(errorCodeMap['10212']))
        }

        throw e
      })
    }
  }

  function stopPreview() {
    const previewController = neMeeting?.previewController

    return previewController?.stopPreview()
  }

  const handleNameChange = useCallback((memberId, name) => {
    const localMember = meetingInfo.localMember

    if (localMember && localMember.uuid === memberId) {
      setNickname(name)
      const value = meetingInfo.shortMeetingNum
        ? {
            [meetingInfo.meetingNum]: name,
            [meetingInfo.shortMeetingNum]: name,
          }
        : {
            [meetingInfo.meetingNum]: name,
          }

      localStorage.setItem(
        'ne-meeting-nickname-' + localMember.uuid,
        JSON.stringify(value)
      )
    }
  }, [])

  const handleMeetingUpdate = useCallback(
    (res) => {
      if (res.data) {
        if (res.data?.type === 200) {
          window.isElectronNative && Toast.warning(t('tokenExpired'), 5000)
        } else {
          setMeetingState(res.data.state)
        }
      }
    },
    [t]
  )

  useEffect(() => {
    if (meetingState === 2) {
      setShowChatRoom(true)
    }
  }, [meetingState])

  const getWaitingRoomConfig = useCallback(() => {
    neMeeting?.getWaitingRoomConfig(meetingInfo.meetingNum).then((data) => {
      dispatch?.({
        type: ActionType.UPDATE_MEETING_INFO,
        data: {
          waitingRoomChatPermission: data.wtPrChat,
        },
      })
    })
  }, [meetingInfo.meetingNum, neMeeting, dispatch])

  const handleWaitingRoomEvent = useCallback(() => {
    eventEmitter?.on

    eventEmitter?.on(
      EventType.RoomPropertiesChanged,
      (properties: Record<string, any>) => {
        console.log('onRoomPropertiesChanged: %o %o %t', properties)
        if (properties.wtPrChat) {
          const waitingRoomChatPermission = Number(properties.wtPrChat.value)

          console.log('waitingRoomChatPermission', waitingRoomChatPermission)
          dispatch?.({
            type: ActionType.UPDATE_MEETING_INFO,
            data: {
              waitingRoomChatPermission,
            },
          })
        }
      }
    )
    eventEmitter?.on(EventType.MyWaitingRoomStatusChanged, (status, reason) => {
      console.log('MyWaitingRoomStatusChanged', status, reason)
      // 被准入
      if (status === 2) {
        globalDispatch?.({
          type: ActionType.JOIN_LOADING,
          data: true,
        })
        dispatch?.({
          type: ActionType.RESET_MEETING,
          data: null,
        })
        neMeeting?.rejoinAfterAdmittedToRoom().then(() => {
          console.warn('rejoinAfterAdmittedToRoom', meetingInfoRef.current)
          // 使用eventEmitter auth组件无法监听到
          outEventEmitter?.emit(MeetingEventType.rejoinAfterAdmittedToRoom, {
            isUnMutedVideo: meetingInfoRef.current.isUnMutedVideo,
            isUnMutedAudio: meetingInfoRef.current.isUnMutedAudio,
          })
          if (window.isElectronNative) {
            const meeting = neMeeting?.getMeetingInfo()

            meeting &&
              dispatch?.({
                type: ActionType.SET_MEETING,
                data: meeting,
              })
          }

          dispatch?.({
            type: ActionType.UPDATE_MEETING_INFO,
            data: {
              inWaitingRoom: false,
            },
          })
        })
      } else if (status === 3) {
        console.log('MyWaitingRoomStatusChanged', status, reason)
        // 被主持人移除 或者全部被移除
        if (reason === 3 || reason === 6) {
          closeModalHandle({
            title: t('removedFromMeeting'),
            content: t('removeFromMeetingByHost'),
            closeText: t('globalClose'),
            reason,
            notNeedAutoClose: true,
          })
        } else {
          // 不是加入房间
          if (reason !== 5) {
            if (reason === 2) {
              Toast.info(t('meetingSwitchOtherDevice'))
              setTimeout(() => {
                outEventEmitter?.emit(EventType.RoomEnded, reason)
              }, 2000)
            } else {
              outEventEmitter?.emit(EventType.RoomEnded, reason)
            }
          }
        }
      }
    })
    eventEmitter?.on(EventType.MemberNameChangedInWaitingRoom, handleNameChange)
    eventEmitter?.on(EventType.RoomEnded, handleRoomEnd)

    eventEmitter?.on(
      EventType.ReceiveScheduledMeetingUpdate,
      handleMeetingUpdate
    )
  }, [])

  function removeWaitingRoomEvent() {
    eventEmitter?.off(EventType.MyWaitingRoomStatusChanged)
    eventEmitter?.off(
      EventType.MemberNameChangedInWaitingRoom,
      handleNameChange
    )
    eventEmitter?.off(EventType.RoomEnded, handleRoomEnd)
    eventEmitter?.off(
      EventType.ReceiveScheduledMeetingUpdate,
      handleMeetingUpdate
    )
    // eventEmitter?.off(EventType.MemberJoinWaitingRoom)
    // eventEmitter?.off(EventType.MemberLeaveWaitingRoom)
    // eventEmitter?.off(EventType.MemberAdmitted)
    // eventEmitter?.off(EventType.MemberNameChangedInWaitingRoom)
    // eventEmitter?.off(EventType.WaitingRoomInfoUpdated)
  }

  function handleOpenChatRoom(openChatRoom) {
    setUnReadMsgCount(0)
    setOpenChatRoom(openChatRoom)
  }

  function formatMeetingTime(startTime: number) {
    return startTime ? formatDate(startTime, 'yyyy.MM.dd_hh:mm') : '--'
  }

  const handleRoomEnd = useCallback((reason: string) => {
    const langMap: Record<string, string> = {
      UNKNOWN: t('UNKNOWN'), // 未知异常
      LOGIN_STATE_ERROR: t('LOGIN_STATE_ERROR'), // 账号异常
      CLOSE_BY_BACKEND: meetingInfoRef.current.isScreenSharingMeeting
        ? t('screenShareStop')
        : t('CLOSE_BY_BACKEND'), // 后台关闭
      ALL_MEMBERS_OUT: t('ALL_MEMBERS_OUT'), // 所有成员退出
      END_OF_LIFE: t('END_OF_LIFE'), // 房间到期
      CLOSE_BY_MEMBER: t('meetingEnded'), // 会议已结束
      KICK_OUT: t('KICK_OUT'), // 被管理员踢出
      SYNC_DATA_ERROR: t('SYNC_DATA_ERROR'), // 数据同步错误
      LEAVE_BY_SELF: t('LEAVE_BY_SELF'), // 成员主动离开房间
      OTHER: t('OTHER'), // 其他
    }

    if (reason === 'CLOSE_BY_MEMBER') {
      closeModalHandle({
        title: t('meetingEnded'),
        content: t('closeAutomatically'),
        closeText: t('globalSure'),
        reason,
      })
    } else {
      langMap[reason] && Toast.info(langMap[reason])
      let leaveType: NEMeetingLeaveType = NEMeetingLeaveType[reason]

      if (!leaveType && leaveType !== 0) {
        leaveType = NEMeetingLeaveType.UNKNOWN
      }

      outEventEmitter?.emit(EventType.RoomEnded, reason)
    }
  }, [])

  useEffect(() => {
    addPreviewRoomListener()
    neMeeting?.chatController?.leaveChatroom(0)
    neMeeting?.chatController?.joinChatroom(1)
    const closeTimer = closeTimerRef.current

    return () => {
      stopPreview()
      removePreviewRoomListener()
      closeTimer && clearInterval(closeTimer)
      neMeeting?.previewController?.stopRecordDeviceTest()
    }
  }, [])

  useEffect(() => {
    handleWaitingRoomEvent()
    return () => {
      removeWaitingRoomEvent()
    }
  }, [])

  useEffect(() => {
    getWaitingRoomConfig()
    function onlineHandle() {
      setIsOffLine(false)
      // 延迟请求
      setTimeout(() => {
        getWaitingRoomConfig()
      }, 1000)
    }

    function offlineHandle() {
      setIsOffLine(true)
    }

    window.addEventListener('online', onlineHandle)
    window.addEventListener('offline', offlineHandle)
    return () => {
      window.removeEventListener('online', onlineHandle)
      window.removeEventListener('offline', offlineHandle)
    }
  }, [getWaitingRoomConfig])

  return {
    openAudio,
    openVideo,
    setOpenVideo,
    setOpenAudio,
    setting,
    unReadMsgCount,
    isOffLine,
    nickname,
    recordVolume,
    meetingInfo,
    meetingState,
    showChatRoom,
    handleOpenAudio,
    handleOpenVideo,
    handleOpenChatRoom,
    startPreview,
    stopPreview,
    openChatRoom,
    formatMeetingTime,
    videoCanvasWrapRef,
    setSetting,
    setOpenChatRoom,
    setUnReadMsgCount,
    setRecordVolume,
  }
}