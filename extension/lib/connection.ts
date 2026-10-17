import { isAppToExtension, type ExtensionToApp } from './protocol';
import type { SiteConfig } from './siteConfig';
import { NATIVE_HOST, stateFromDisconnect, type ConnectionState } from './native';

/** Native Messaging 포트에서 쓰는 부분만 (테스트에서 가짜 포트로 바꾼다) */
export type NativePort = {
  postMessage(message: unknown): void;
  disconnect(): void;
  onMessage: { addListener(listener: (message: unknown) => void): void };
  onDisconnect: { addListener(listener: () => void): void };
};

export type ConnectionDeps = {
  connectNative(host: string): NativePort;
  lastErrorMessage(): string | undefined;
  extensionVersion: string;
  onState(state: ConnectionState): void;
  /** 앱이 보낸 지원 사이트 설정 */
  onConfig(config: SiteConfig): void;
};

/**
 * 채우미 앱 연결 하나를 관리한다. 다시 연결하면 이전 포트를 닫고,
 * 이전 포트에서 늦게 온 사건은 무시해 새 연결 상태를 덮어쓰지 않는다.
 */
export function createConnection(deps: ConnectionDeps) {
  let current: NativePort | null = null;

  function connect() {
    current?.disconnect();
    deps.onState({ kind: 'connecting' });
    const port = deps.connectNative(NATIVE_HOST);
    current = port;
    port.onMessage.addListener((message) => {
      if (port !== current || !isAppToExtension(message)) return;
      if (message.type === 'ack')
        deps.onState({ kind: 'connected', appVersion: message.appVersion });
      else deps.onConfig(message.config);
    });
    port.onDisconnect.addListener(() => {
      if (port !== current) return;
      current = null;
      deps.onState(stateFromDisconnect(deps.lastErrorMessage()));
    });
    const hello: ExtensionToApp = { type: 'hello', extensionVersion: deps.extensionVersion };
    port.postMessage(hello);
  }

  /**
   * 앱에 보낸다. 끊겨 있으면(앱을 껐다 켰거나 바꿔 설치함) 먼저 다시 연결한다 — 연결하면 호스트가 앱을 실행한다 (APP-019).
   * 다시 연결하지 않으면 service worker가 다시 시작될 때까지 공고 알림이 모두 버려졌다 (실측)
   */
  function post(message: ExtensionToApp) {
    if (!current) connect();
    current?.postMessage(message);
  }

  return { connect, post };
}
