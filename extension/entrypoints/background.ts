import { isAppToExtension, type ExtensionToApp } from '@/lib/protocol';
import { NATIVE_HOST, stateFromDisconnect, type ConnectionState } from '@/lib/native';

let state: ConnectionState = { kind: 'connecting' };

function setState(next: ConnectionState) {
  state = next;
  void browser.storage.session.set({ connection: state });
}

/**
 * 채우미 앱에 Native Messaging으로 연결한다.
 * 연결하면 Chrome이 호스트를 실행하고, 호스트가 꺼진 앱을 실행한다 (APP-019).
 */
function connect() {
  setState({ kind: 'connecting' });
  const port = browser.runtime.connectNative(NATIVE_HOST);
  port.onMessage.addListener((message: unknown) => {
    if (isAppToExtension(message)) setState({ kind: 'connected', appVersion: message.appVersion });
  });
  port.onDisconnect.addListener(() => {
    setState(stateFromDisconnect(browser.runtime.lastError?.message));
  });
  const hello: ExtensionToApp = {
    type: 'hello',
    extensionVersion: browser.runtime.getManifest().version,
  };
  port.postMessage(hello);
}

export default defineBackground(() => {
  connect();
  browser.runtime.onMessage.addListener((message: unknown) => {
    if (message === 'connection-state') return Promise.resolve(state);
    if (message === 'reconnect') connect();
    return undefined;
  });
});
