import { describe, expect, it } from 'vitest';
import { isAppToExtension, isExtensionToApp, type JobPageMessage } from '@/lib/protocol';
import { sanitizeJobPage } from '@/lib/sanitize';
import hello from '../../protocol/examples/hello.json';
import jobPage from '../../protocol/examples/job-page.json';
import ack from '../../protocol/examples/ack.json';

describe('확장 ↔ 앱 메시지 규약 (공용 예시)', () => {
  it('확장 → 앱 예시는 모두 규약에 맞다', () => {
    expect(isExtensionToApp(hello)).toBe(true);
    expect(isExtensionToApp(jobPage)).toBe(true);
  });

  it('공고 예시는 이미 걸러진 모양이다 (거르기 전후가 같다)', () => {
    expect(sanitizeJobPage(jobPage as JobPageMessage)).toEqual(jobPage);
  });

  it('앱 → 확장 예시는 규약에 맞다', () => {
    expect(isAppToExtension(ack)).toBe(true);
  });

  it('필수 필드가 빠지거나 모르는 type이면 거부한다', () => {
    expect(isExtensionToApp({ type: 'hello' })).toBe(false);
    expect(isExtensionToApp({ type: 'jobPage', site: 'wanted' })).toBe(false);
    expect(isExtensionToApp({ type: 'jobPage', site: 'wanted', url: 'u', company: 1 })).toBe(false);
    expect(isExtensionToApp({ type: 'unknown' })).toBe(false);
    expect(isExtensionToApp(null)).toBe(false);
    expect(isAppToExtension({ type: 'ack' })).toBe(false);
    expect(isAppToExtension([ack])).toBe(false);
  });
});
