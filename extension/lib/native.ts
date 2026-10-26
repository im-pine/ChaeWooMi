/** 채우미 Native Messaging 호스트 이름 (앱이 Chrome에 등록) */
export const NATIVE_HOST = 'com.impine.chaewoomi';

/** 확장 → 앱 연결 상태. 미설치 · 권한 없음 · 끊김을 구분한다 (WEB-001 · SET-005) */
export type ConnectionState =
  | { kind: 'connecting' }
  | { kind: 'connected'; appVersion: string }
  /** 호스트는 붙었지만 앱이 꺼져 있음. 사용자가 앱을 켜면 바로 연결된다 */
  | { kind: 'appNotRunning' }
  | { kind: 'hostNotInstalled' }
  | { kind: 'forbidden' }
  | { kind: 'disconnected'; reason: string };

/**
 * 연결이 끊길 때 Chrome이 주는 오류 문구로 원인을 나눈다.
 * 문구 출처: Chrome Native Messaging 문서의 오류 목록.
 */
export function stateFromDisconnect(errorMessage: string | undefined): ConnectionState {
  const message = errorMessage ?? '';
  if (message.includes('host not found')) return { kind: 'hostNotInstalled' };
  if (message.includes('forbidden')) return { kind: 'forbidden' };
  return { kind: 'disconnected', reason: message || '앱이 연결을 닫음' };
}

/** 상태별 사용자 안내 문구 */
export function describeState(state: ConnectionState): string {
  switch (state.kind) {
    case 'connecting':
      return '채우미 앱에 연결 중';
    case 'connected':
      return `채우미 앱 연결됨 (v${state.appVersion})`;
    case 'appNotRunning':
      return '채우미 앱이 꺼져 있습니다. 앱을 실행하면 바로 연결됩니다';
    case 'hostNotInstalled':
      return '채우미 앱이 설치되지 않았거나 브라우저 연결이 등록되지 않았습니다. 앱을 한 번 실행하세요';
    case 'forbidden':
      return '이 확장은 채우미 앱 연결 허용 목록에 없습니다. 앱 설정의 브라우저 연결을 점검하세요';
    case 'disconnected':
      return `채우미 앱 연결이 끊겼습니다: ${state.reason}`;
  }
}
