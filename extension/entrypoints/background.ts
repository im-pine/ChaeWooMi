import { createConnection } from '@/lib/connection';
import type { ConnectionState } from '@/lib/native';
import type { ExtensionToApp, JobPageMessage } from '@/lib/protocol';
import { RESCAN, type PageReport } from '@/lib/postingWatch';
import { POSTING_SCRIPT_ID, splitByPermission } from '@/lib/registration';
import { configProblems, DEFAULT_CONFIG, postingSite, type SiteConfig } from '@/lib/siteConfig';
import { AUTO_RESCAN_DELAY_MS, AutoRescan } from '@/lib/autoRescan';
import { TabPages, type TabPagesState } from '@/lib/tabPages';
import {
  ASK_LAUNCH,
  dayKey,
  shouldAskLaunch,
  SKIPPED_DAY_KEY,
  type LaunchAnswer,
} from '@/lib/launchPrompt';

let state: ConnectionState = { kind: 'connecting' };
let tabs = new TabPages();
const autoRescan = new AutoRescan();
/** `storage.session`에서 탭별 공고 기억을 다 읽었음 */
let ready: Promise<void> = Promise.resolve();

/** 끊긴 뒤 첫 조용한 재연결까지 (그다음은 `RECONNECT_ALARM` 30초 주기) */
const QUICK_RETRY_MS = 3000;
const RECONNECT_ALARM = 'chaewoomi-reconnect';
let quickRetried = false;
/** 앱 실행 확인창: 떠 있는 동안 또 띄우지 않고, 이번에 물어본 공고 주소는 다시 묻지 않는다 (다시 읽기 · 새로고침) */
let askingLaunch = false;
const askedLaunchUrls = new Set<string>();

/** 탭별 공고 기억을 저장한다. service worker가 쉬다 다시 시작되면 메모리가 비어 이전에 연 탭의 카드를 잃었다 */
const saveTabs = () =>
  void browser.storage.session.set({ tabPages: tabs.state() }).catch(() => undefined);

/**
 * 지금 보고 있는 탭을 다시 읽는다 (카드의 "지원 이력 확인" 버튼).
 * 콘텐츠 스크립트가 응답하지 않으면(확장을 새로고침하기 전에 연 탭 등) 그 탭에 다시 넣는다.
 * 권한이 없는 사이트면 아무것도 하지 않는다 → 앱이 수동 조회 카드를 연다
 */
async function rescanActiveTab(post: (message: ExtensionToApp) => void, reload: boolean) {
  const [tab] = await browser.tabs.query({ active: true, lastFocusedWindow: true });
  if (tab?.id === undefined) return;
  // 지정 사이트 공고 주소가 아니면 다시 읽기 · 새로고침이 소용없다 → 앱이 바로 직접 입력으로
  if (!tab.url || !postingSite(tab.url, await currentConfig())) {
    post({ type: 'notPosting' });
    return;
  }
  // 다시 읽어도 회사명이 없으면 앱이 새로고침을 요청한다
  if (reload) {
    await browser.tabs.reload(tab.id);
    return;
  }
  post(tabs.activate(tab.id));
  saveTabs();
  await rereadTab(tab.id);
}

/** 그 탭의 콘텐츠 스크립트에 다시 읽기를 보내고, 응답이 없으면(끊긴 탭) 다시 넣는다 */
async function rereadTab(tabId: number) {
  try {
    await browser.tabs.sendMessage(tabId, RESCAN);
  } catch {
    await browser.scripting
      .executeScript({ target: { tabId }, files: ['/content-scripts/posting.js'] })
      .catch(() => undefined);
  }
}

/**
 * 탭에 들어가거나 앱과 다시 연결되면, 잠시 뒤에도 그 탭(지정 사이트 공고)의 공고를 모를 때 자동으로 다시 읽는다.
 * "지원 이력 확인"을 누르지 않아도 카드가 뜨게 (사용자 요청 2026-10-18)
 */
function autoRescanSoon(tabId: number) {
  setTimeout(() => {
    void (async () => {
      const tab = await browser.tabs.get(tabId).catch(() => undefined);
      if (!tab?.active || tab.status !== 'complete') return;
      const isPosting = !!tab.url && postingSite(tab.url, await currentConfig()) !== null;
      if (autoRescan.shouldTry(tabId, tab.url, isPosting, tabs.has(tabId))) await rereadTab(tabId);
    })();
  }, AUTO_RESCAN_DELAY_MS);
}

async function currentConfig(): Promise<SiteConfig> {
  const stored = (await browser.storage.local.get('siteConfig')).siteConfig;
  return configProblems(stored).length === 0 ? (stored as SiteConfig) : DEFAULT_CONFIG;
}

/** 설정 도메인 중 권한이 있는 곳에만 공고 콘텐츠 스크립트를 등록하고, 승인이 필요한 도메인을 저장한다 */
async function registerPostingScript() {
  const { granted, missing } = await splitByPermission(await currentConfig(), (pattern) =>
    browser.permissions.contains({ origins: [pattern] }),
  );
  await browser.storage.session.set({ missingOrigins: missing });
  await browser.scripting
    .unregisterContentScripts({ ids: [POSTING_SCRIPT_ID] })
    .catch(() => undefined);
  if (granted.length === 0) return;
  await browser.scripting.registerContentScripts([
    {
      id: POSTING_SCRIPT_ID,
      matches: granted,
      js: ['content-scripts/posting.js'],
      runAt: 'document_idle',
      // 사람인은 지원 완료 안내를 공고 위 레이어의 iframe(`#quick_apply_layer_frame`)에 띄운다 (HIS-017, 실측 누락)
      allFrames: true,
    },
  ]);
}

/**
 * 채우미 앱에 Native Messaging으로 연결한다.
 * 연결하면 Chrome이 호스트를 실행한다. 앱이 꺼져 있으면 호스트는 앱을 실행하지 않고 켜질 때까지 기다린다 (appNotRunning).
 * 빌드할 때 이 모듈을 불러오므로 브라우저 API는 함수 안에서만 부른다.
 */
function createAppConnection() {
  const connection = createConnection({
    connectNative: (host) => browser.runtime.connectNative(host),
    lastErrorMessage: () => browser.runtime.lastError?.message,
    extensionVersion: browser.runtime.getManifest().version,
    onState: (next) => {
      state = next;
      void browser.storage.session.set({ connection: state });
      if (next.kind === 'connected') {
        quickRetried = false;
        void ready.then(async () => {
          connection.post(tabs.current());
          const [tab] = await browser.tabs.query({ active: true, lastFocusedWindow: true });
          if (tab?.id !== undefined) autoRescanSoon(tab.id);
        });
      } else if (next.kind === 'appNotRunning') {
        // 공고 보고가 앱 꺼짐 알림보다 먼저 왔으면 지금 보고 있는 공고에서 묻는다
        void ready.then(async () => {
          const page = tabs.current();
          const [tab] = await browser.tabs.query({ active: true, lastFocusedWindow: true });
          if (page.type === 'jobPage' && tab?.id !== undefined)
            await askLaunch(tab.id, page, connection.post);
        });
      } else if (next.kind !== 'connecting' && !quickRetried) {
        // 끊기면 3초 뒤 한 번 조용히 다시 연결 (앱을 다시 켰거나 바꿔 설치한 경우). 그다음은 30초 알람
        quickRetried = true;
        setTimeout(() => {
          if (!connection.isConnected()) connection.connect();
        }, QUICK_RETRY_MS);
      }
    },
    // 앱 소유 지원 사이트 설정. 공고 인식은 이 값을 쓰고, 없으면 기본값 (WEB-014)
    onConfig: (config) =>
      void browser.storage.local.set({ siteConfig: config }).then(registerPostingScript),
    onRescan: (reload) => void ready.then(() => rescanActiveTab(connection.post, reload)),
  });
  return connection;
}

/**
 * 앱이 꺼져 있을 때 확인창 사이트 공고를 열면 그 탭에 앱 실행 확인창을 띄운다.
 * "열기"면 호스트에 앱 실행을 부탁하고, "오늘 하루 묻지 않기"를 골랐으면 오늘은 다시 묻지 않는다
 */
async function askLaunch(
  tabId: number,
  page: JobPageMessage,
  post: (message: ExtensionToApp) => void,
) {
  if (askingLaunch || askedLaunchUrls.has(page.url)) return;
  const today = dayKey(new Date());
  const skippedDay = (await browser.storage.local.get(SKIPPED_DAY_KEY))[SKIPPED_DAY_KEY];
  const appNotRunning = state.kind === 'appNotRunning';
  if (!shouldAskLaunch({ site: page.site, appNotRunning, skippedDay, today })) return;
  askingLaunch = true;
  askedLaunchUrls.add(page.url);
  try {
    const answer = (await browser.tabs.sendMessage(tabId, ASK_LAUNCH)) as LaunchAnswer | undefined;
    if (!answer) return;
    if (answer.skipToday) await browser.storage.local.set({ [SKIPPED_DAY_KEY]: today });
    if (answer.open) post({ type: 'launchApp' });
  } catch {
    // 확장을 새로고침하기 전에 연 탭 등 콘텐츠 스크립트가 없으면 묻지 않는다
  } finally {
    askingLaunch = false;
  }
}

/** 콘텐츠 스크립트 보고 → 보고 있는 탭이면 앱에 보낸다 */
function handleReport(report: PageReport, tabId: number, post: (message: ExtensionToApp) => void) {
  const message =
    report.kind === 'posting'
      ? tabs.posting(tabId, report.page)
      : report.kind === 'left'
        ? tabs.left(tabId)
        : report.kind === 'complete'
          ? tabs.complete()
          : tabs.applyButton(tabId, report.covering);
  saveTabs();
  if (message) post(message);
  if (message && report.kind === 'posting') void askLaunch(tabId, report.page, post);
}

/** 탭 전환 · 이동 · 닫기를 보고 있는 탭의 공고 상태로 바꿔 앱에 보낸다. 처리는 저장된 기억을 읽은 뒤에 한다 */
function listenTabs(post: (message: ExtensionToApp) => void) {
  browser.tabs.onActivated.addListener(
    ({ tabId }) =>
      void ready.then(() => {
        post(tabs.activate(tabId));
        saveTabs();
        autoRescanSoon(tabId);
      }),
  );
  // 탭이 새 페이지를 불러오기 시작하면 이전 공고를 비운다. 등록 도메인 밖으로 가면 콘텐츠 스크립트가 없어 left를 못 보내기 때문
  browser.tabs.onUpdated.addListener((tabId, info, tab) => {
    if (info.status !== 'loading') return;
    void ready.then(() => {
      const message = tabs.navigating(tabId, tab.url);
      saveTabs();
      if (message) post(message);
    });
  });
  browser.tabs.onRemoved.addListener(
    (tabId) =>
      void ready.then(() => {
        autoRescan.forget(tabId);
        const message = tabs.closed(tabId);
        saveTabs();
        if (message) post(message);
      }),
  );
}

export default defineBackground(() => {
  // service worker 이벤트 리스너는 시작할 때 바로 등록해야 깨운 이벤트를 놓치지 않는다. 저장된 기억은 따로 읽는다
  ready = browser.storage.session
    .get('tabPages')
    .then(({ tabPages }) => {
      tabs = TabPages.restore(tabPages as TabPagesState | undefined);
    })
    .catch(() => undefined);
  const connection = createAppConnection();
  connection.connect();
  void registerPostingScript();
  void ready
    .then(() => browser.tabs.query({ active: true, currentWindow: true }))
    .then(([tab]) => {
      if (tab?.id !== undefined) tabs.activate(tab.id);
      saveTabs();
    });
  listenTabs(connection.post);
  // 호스트가 끝나 연결이 끊겨도(앱 종료 등) 30초마다 다시 연결한다. 호스트는 앱을 실행하지 않고 켜질 때까지 기다린다
  void browser.alarms.create(RECONNECT_ALARM, { periodInMinutes: 0.5 });
  browser.alarms.onAlarm.addListener((alarm) => {
    if (alarm.name === RECONNECT_ALARM && !connection.isConnected()) connection.connect();
  });
  browser.permissions.onAdded.addListener(() => void registerPostingScript());
  browser.permissions.onRemoved.addListener(() => void registerPostingScript());
  browser.runtime.onMessage.addListener((message: unknown, sender) => {
    if (message === 'connection-state') return Promise.resolve(state);
    if (message === 'reconnect') connection.connect();
    const tabId = sender.tab?.id;
    if (
      typeof message === 'object' &&
      message !== null &&
      'kind' in message &&
      tabId !== undefined
    ) {
      void ready.then(() => handleReport(message as PageReport, tabId, connection.post));
    }
    return undefined;
  });
});
