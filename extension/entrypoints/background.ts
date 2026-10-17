import { createConnection } from '@/lib/connection';
import type { ConnectionState } from '@/lib/native';

let state: ConnectionState = { kind: 'connecting' };

/**
 * 채우미 앱에 Native Messaging으로 연결한다.
 * 연결하면 Chrome이 호스트를 실행하고, 호스트가 꺼진 앱을 실행한다 (APP-019).
 */
const connection = createConnection({
  connectNative: (host) => browser.runtime.connectNative(host),
  lastErrorMessage: () => browser.runtime.lastError?.message,
  extensionVersion: browser.runtime.getManifest().version,
  onState: (next) => {
    state = next;
    void browser.storage.session.set({ connection: state });
  },
  // 앱 소유 지원 사이트 설정. 공고 인식은 이 값을 쓰고, 없으면 기본값 (WEB-014)
  onConfig: (config) => void browser.storage.local.set({ siteConfig: config }),
});

export default defineBackground(() => {
  connection.connect();
  browser.runtime.onMessage.addListener((message: unknown) => {
    if (message === 'connection-state') return Promise.resolve(state);
    if (message === 'reconnect') connection.connect();
    return undefined;
  });
});
