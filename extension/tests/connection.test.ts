import { describe, expect, it } from 'vitest';
import { createConnection, type NativePort } from '@/lib/connection';
import type { ConnectionState } from '@/lib/native';
import { DEFAULT_CONFIG, type SiteConfig } from '@/lib/siteConfig';

/** 메시지 · 끊김을 직접 일으킬 수 있는 가짜 포트 */
function fakePort() {
  const messageListeners: ((message: unknown) => void)[] = [];
  const disconnectListeners: (() => void)[] = [];
  const port = {
    posted: [] as unknown[],
    disconnected: false,
    postMessage(message: unknown) {
      port.posted.push(message);
    },
    disconnect() {
      port.disconnected = true;
    },
    onMessage: {
      addListener: (listener: (message: unknown) => void) => messageListeners.push(listener),
    },
    onDisconnect: { addListener: (listener: () => void) => disconnectListeners.push(listener) },
    receive: (message: unknown) => messageListeners.forEach((listener) => listener(message)),
    drop: () => disconnectListeners.forEach((listener) => listener()),
  };
  return port;
}

function setup(lastError?: string) {
  const ports: ReturnType<typeof fakePort>[] = [];
  const states: ConnectionState[] = [];
  const configs: SiteConfig[] = [];
  const connection = createConnection({
    connectNative: (): NativePort => {
      const port = fakePort();
      ports.push(port);
      return port;
    },
    lastErrorMessage: () => lastError,
    extensionVersion: '0.1.0',
    onState: (state) => states.push(state),
    onConfig: (config) => configs.push(config),
  });
  return { connection, ports, states, configs };
}

describe('앱 연결 관리', () => {
  it('연결하면 hello를 보내고, ack를 받으면 연결됨', () => {
    const { connection, ports, states } = setup();
    connection.connect();
    ports[0]?.receive({ type: 'ack', appVersion: '0.2.0' });
    expect(ports[0]?.posted).toEqual([{ type: 'hello', extensionVersion: '0.1.0' }]);
    expect(states.at(-1)).toEqual({ kind: 'connected', appVersion: '0.2.0' });
  });

  it('다시 연결하면 이전 포트를 닫는다', () => {
    const { connection, ports } = setup();
    connection.connect();
    connection.connect();
    expect(ports[0]?.disconnected).toBe(true);
    expect(ports[1]?.disconnected).toBe(false);
  });

  it('이전 포트의 늦은 끊김 · 메시지는 새 연결 상태를 덮어쓰지 않는다', () => {
    const { connection, ports, states } = setup('Native host has exited.');
    connection.connect();
    connection.connect();
    ports[1]?.receive({ type: 'ack', appVersion: '0.1.0' });
    ports[0]?.drop();
    ports[0]?.receive({ type: 'ack', appVersion: '9.9.9' });
    expect(states.at(-1)).toEqual({ kind: 'connected', appVersion: '0.1.0' });
  });

  it('현재 포트가 끊기면 원인별 상태가 된다', () => {
    const { connection, ports, states } = setup('Specified native messaging host not found.');
    connection.connect();
    ports[0]?.drop();
    expect(states.at(-1)).toEqual({ kind: 'hostNotInstalled' });
  });

  it('모르는 메시지는 무시한다', () => {
    const { connection, ports, states } = setup();
    connection.connect();
    ports[0]?.receive({ type: 'unknown' });
    expect(states).toEqual([{ kind: 'connecting' }]);
  });
});

describe('앱이 보낸 설정', () => {
  it('앱이 보낸 지원 사이트 설정을 넘기고, 틀린 설정은 버린다', () => {
    const { connection, ports, configs } = setup();
    connection.connect();
    ports[0]?.receive({ type: 'siteConfig', config: DEFAULT_CONFIG });
    ports[0]?.receive({ type: 'siteConfig', config: { version: 9, sites: [] } });
    expect(configs).toEqual([DEFAULT_CONFIG]);
  });

  it('끊긴 뒤 보낼 메시지가 생기면 다시 연결하고 hello 다음에 보낸다 (앱 재시작 실측 버그)', () => {
    const { connection, ports } = setup();
    connection.connect();
    ports[0]?.drop();
    const page = { type: 'pageLeft' as const };
    connection.post(page);
    expect(ports).toHaveLength(2);
    expect(ports[1]?.posted).toEqual([{ type: 'hello', extensionVersion: '0.1.0' }, page]);
  });

  it('연결돼 있으면 새로 연결하지 않는다', () => {
    const { connection, ports } = setup();
    connection.connect();
    connection.post({ type: 'pageLeft' });
    expect(ports).toHaveLength(1);
  });
});
