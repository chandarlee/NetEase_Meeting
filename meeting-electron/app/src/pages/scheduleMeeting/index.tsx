import React, { useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import EventEmitter from 'eventemitter3';

import PCTopButtons from '../../../../src/components/common/PCTopButtons';
import ScheduleMeeting, {
  ScheduleMeetingRef,
} from '../../../../src/components/web/BeforeMeetingModal/ScheduleMeeting';
import { useGlobalContext } from '../../../../src/store';
import ScheduleMeetingBgImg from '../../assets/schedule_bg.png';

import './index.less';
import {
  CreateMeetingResponse,
  EventType,
  GetMeetingConfigResponse,
} from '../../../../src/types';
import Toast from '../../../../src/components/common/toast';
import classNames from 'classnames';

const eventEmitter = new EventEmitter();

const ScheduleMeetingPage: React.FC = () => {
  const { t } = useTranslation();
  const { neMeeting } = useGlobalContext();
  const scheduleMeetingRef = useRef<ScheduleMeetingRef>(null);
  const isCreateOrEditScheduleMeetingRef = useRef<boolean>(false);
  const [open, setOpen] = useState<boolean>(false);
  const [nickname, setNickname] = useState<string>('');
  const [submitLoading, setSubmitLoading] = useState(false);
  const [appLiveAvailable, setAppLiveAvailable] = useState<boolean>(false);
  const [globalConfig, setGlobalConfig] = useState<GetMeetingConfigResponse>();
  const [editMeeting, setEditMeeting] = useState<CreateMeetingResponse>();
  const [pageMode, setPageMode] = useState<'detail' | 'edit' | 'create'>(
    'create',
  );

  useEffect(() => {
    function handleMessage(e: MessageEvent) {
      const { event, payload } = e.data;

      if (event === 'windowOpen') {
        payload.nickname && setNickname(payload.nickname);
        payload.appLiveAvailable &&
          setAppLiveAvailable(payload.appLiveAvailable);
        payload.globalConfig && setGlobalConfig(payload.globalConfig);
        setEditMeeting(payload.editMeeting);
        setOpen(true);
      } else if (event === 'createOrEditScheduleMeetingFail') {
        isCreateOrEditScheduleMeetingRef.current = false;
        Toast.fail(payload.errorMsg);
        setSubmitLoading(false);
      }
    }

    window.addEventListener('message', handleMessage);
    return () => {
      window.removeEventListener('message', handleMessage);
    };
  }, []);

  useEffect(() => {
    function ipcRenderer() {
      if (isCreateOrEditScheduleMeetingRef.current) {
        window.ipcRenderer?.send('childWindow:closed');
      } else {
        scheduleMeetingRef.current?.handleCancelEditMeeting();
      }
    }

    window.ipcRenderer?.on('scheduleMeetingWindow:close', ipcRenderer);
    return () => {
      window.ipcRenderer?.removeListener(
        'scheduleMeetingWindow:close',
        ipcRenderer,
      );
    };
  }, []);

  useEffect(() => {
    setTimeout(() => {
      document.title = t('scheduleMeeting');
    });
  }, [t]);

  useEffect(() => {
    eventEmitter.on(EventType.OnScheduledMeetingPageModeChanged, (mode) => {
      setPageMode(mode);
    });
    return () => {
      eventEmitter.off(EventType.OnScheduledMeetingPageModeChanged);
    };
  }, []);

  return (
    <>
      <div
        className={classNames('schedule-meeting-page', {
          'schedule-meeting-page-bg': pageMode === 'detail',
        })}
        style={{
          backgroundImage:
            pageMode === 'detail' ? `url(${ScheduleMeetingBgImg})` : 'none',
        }}
      >
        <div className="electron-drag-bar">
          <div className="drag-region" />
          {pageMode !== 'detail' && (
            <span
              style={{
                fontWeight: window.systemPlatform === 'win32' ? 'bold' : '500',
              }}
            >
              {t('scheduleMeeting')}
            </span>
          )}
          <PCTopButtons size="normal" minimizable={false} maximizable={false} />
        </div>
        <div className="schedule-meeting-page-content">
          <ScheduleMeeting
            ref={scheduleMeetingRef}
            open={open}
            neMeeting={neMeeting}
            nickname={nickname}
            submitLoading={submitLoading}
            appLiveAvailable={appLiveAvailable}
            globalConfig={globalConfig}
            eventEmitter={eventEmitter}
            meeting={editMeeting}
            onCancel={() => {
              window.ipcRenderer?.send('childWindow:closed');
            }}
            onJoinMeeting={(meetingId) => {
              const parentWindow = window.parent;

              parentWindow?.postMessage(
                {
                  event: 'joinScheduleMeeting',
                  payload: {
                    meetingId,
                  },
                },
                parentWindow.origin,
              );
            }}
            onSummit={(value) => {
              setSubmitLoading(true);
              isCreateOrEditScheduleMeetingRef.current = true;
              const parentWindow = window.parent;

              parentWindow?.postMessage(
                {
                  event: 'createOrEditScheduleMeeting',
                  payload: {
                    value,
                  },
                },
                parentWindow.origin,
              );
            }}
            onCancelMeeting={(cancelRecurringMeeting) => {
              const parentWindow = window.parent;

              parentWindow?.postMessage(
                {
                  event: 'cancelScheduleMeeting',
                  payload: {
                    cancelRecurringMeeting,
                    meetingId: editMeeting?.meetingId,
                  },
                },
                parentWindow.origin,
              );
            }}
          />
        </div>
      </div>
    </>
  );
};

export default ScheduleMeetingPage;