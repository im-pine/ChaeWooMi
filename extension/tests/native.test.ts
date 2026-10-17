import { describe, expect, it } from 'vitest';
import { describeState, stateFromDisconnect } from '@/lib/native';

describe('브라우저 연결 상태 구분 (WEB-001 · SET-005)', () => {
  it('호스트가 등록되지 않았으면 미설치', () => {
    expect(stateFromDisconnect('Specified native messaging host not found.')).toEqual({
      kind: 'hostNotInstalled',
    });
  });

  it('허용 목록에 없으면 권한 없음', () => {
    expect(
      stateFromDisconnect('Access to the specified native messaging host is forbidden.'),
    ).toEqual({ kind: 'forbidden' });
  });

  it('그 밖의 끊김은 이유와 함께 끊김', () => {
    expect(stateFromDisconnect('Native host has exited.')).toEqual({
      kind: 'disconnected',
      reason: 'Native host has exited.',
    });
    expect(stateFromDisconnect(undefined)).toEqual({
      kind: 'disconnected',
      reason: '앱이 연결을 닫음',
    });
  });

  it('상태마다 안내 문구가 다르다', () => {
    const texts = [
      describeState({ kind: 'connecting' }),
      describeState({ kind: 'connected', appVersion: '0.1.0' }),
      describeState({ kind: 'hostNotInstalled' }),
      describeState({ kind: 'forbidden' }),
      describeState({ kind: 'disconnected', reason: 'x' }),
    ];
    expect(new Set(texts).size).toBe(5);
  });
});
