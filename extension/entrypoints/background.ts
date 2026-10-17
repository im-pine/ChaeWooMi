import { createConnection } from '@/lib/connection';
import type { ConnectionState } from '@/lib/native';
import type { ExtensionToApp } from '@/lib/protocol';
import type { PageReport } from '@/lib/postingWatch';
import { POSTING_SCRIPT_ID, splitByPermission } from '@/lib/registration';
import { configProblems, DEFAULT_CONFIG, type SiteConfig } from '@/lib/siteConfig';
import { TabPages } from '@/lib/tabPages';

let state: ConnectionState = { kind: 'connecting' };
const tabs = new TabPages();

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
      if (next.kind === 'connected') connection.post(tabs.current());
    },
    // 앱 소유 지원 사이트 설정. 공고 인식은 이 값을 쓰고, 없으면 기본값 (WEB-014)
    onConfig: (config) =>
      void browser.storage.local.set({ siteConfig: config }).then(registerPostingScript),
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
        : tabs.applyButton(tabId, report.covering);
  if (message) post(message);
}

export default defineBackground(() => {
  const connection = createAppConnection();
  connection.connect();
  void registerPostingScript();
  void browser.tabs.query({ active: true, currentWindow: true }).then(([tab]) => {
    if (tab?.id !== undefined) tabs.activate(tab.id);
  });
  browser.tabs.onActivated.addListener(({ tabId }) => connection.post(tabs.activate(tabId)));
  // 탭이 새 페이지를 불러오기 시작하면 이전 공고를 비운다. 등록 도메인 밖으로 가면 콘텐츠 스크립트가 없어 left를 못 보내기 때문
  browser.tabs.onUpdated.addListener((tabId, info) => {
    if (info.status !== 'loading') return;
    const message = tabs.navigating(tabId);
    if (message) connection.post(message);
  });
  browser.tabs.onRemoved.addListener((tabId) => {
    const message = tabs.closed(tabId);
    if (message) connection.post(message);
  });
  browser.permissions.onAdded.addListener(() => void registerPostingScript());
  browser.permissions.onRemoved.addListener(() => void registerPostingScript());
  browser.runtime.onMessage.addListener((message: unknown, sender) => {
    if (message === 'connection-state') return Promise.resolve(state);
    if (message === 'reconnect') connection.connect();
    if (
      typeof message === 'object' &&
      message !== null &&
      'kind' in message &&
      sender.tab?.id !== undefined
    ) {
      handleReport(message as PageReport, sender.tab.id, connection.post);
    }
    return undefined;
  });
});
