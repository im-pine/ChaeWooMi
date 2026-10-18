import { createConnection } from '@/lib/connection';
import type { ConnectionState } from '@/lib/native';
import type { ExtensionToApp } from '@/lib/protocol';
import { RESCAN, type PageReport } from '@/lib/postingWatch';
import { POSTING_SCRIPT_ID, splitByPermission } from '@/lib/registration';
import { configProblems, DEFAULT_CONFIG, type SiteConfig } from '@/lib/siteConfig';
import { TabPages, type TabPagesState } from '@/lib/tabPages';

let state: ConnectionState = { kind: 'connecting' };
let tabs = new TabPages();
/** `storage.session`에서 탭별 공고 기억을 다 읽었음 */
let ready: Promise<void> = Promise.resolve();

/** 탭별 공고 기억을 저장한다. service worker가 쉬다 다시 시작되면 메모리가 비어 이전에 연 탭의 카드를 잃었다 */
const saveTabs = () =>
  void browser.storage.session.set({ tabPages: tabs.state() }).catch(() => undefined);

/**
 * 지금 보고 있는 탭을 다시 읽는다 (카드의 "지원 이력 확인" 버튼).
 * 콘텐츠 스크립트가 응답하지 않으면(확장을 새로고침하기 전에 연 탭 등) 그 탭에 다시 넣는다.
 * 권한이 없는 사이트면 아무것도 하지 않는다 → 앱이 수동 조회 카드를 연다
 */
async function rescanActiveTab(post: (message: ExtensionToApp) => void) {
  const [tab] = await browser.tabs.query({ active: true, lastFocusedWindow: true });
  if (tab?.id === undefined) return;
  post(tabs.activate(tab.id));
  saveTabs();
  try {
    await browser.tabs.sendMessage(tab.id, RESCAN);
  } catch {
    await browser.scripting
      .executeScript({ target: { tabId: tab.id }, files: ['/content-scripts/posting.js'] })
      .catch(() => undefined);
  }
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
    },
  ]);
}

/**
 * 채우미 앱에 Native Messaging으로 연결한다.
 * 연결하면 Chrome이 호스트를 실행하고, 호스트가 꺼진 앱을 실행한다 (APP-019).
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
      if (next.kind === 'connected') void ready.then(() => connection.post(tabs.current()));
    },
    // 앱 소유 지원 사이트 설정. 공고 인식은 이 값을 쓰고, 없으면 기본값 (WEB-014)
    onConfig: (config) =>
      void browser.storage.local.set({ siteConfig: config }).then(registerPostingScript),
    onRescan: () => void ready.then(() => rescanActiveTab(connection.post)),
  });
  return connection;
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
}

/** 탭 전환 · 이동 · 닫기를 보고 있는 탭의 공고 상태로 바꿔 앱에 보낸다. 처리는 저장된 기억을 읽은 뒤에 한다 */
function listenTabs(post: (message: ExtensionToApp) => void) {
  browser.tabs.onActivated.addListener(
    ({ tabId }) =>
      void ready.then(() => {
        post(tabs.activate(tabId));
        saveTabs();
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
