import { isAppToExtension, type ExtensionToApp } from './protocol';
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
      deps.onState({ kind: 'connected', appVersion: message.appVersion });
    });
    port.onDisconnect.addListener(() => {
      if (port !== current) return;
      current = null;
      deps.onState(stateFromDisconnect(deps.lastErrorMessage()));
    });
    const hello: ExtensionToApp = { type: 'hello', extensionVersion: deps.extensionVersion };
    port.postMessage(hello);
  }

  return { connect };
}
