import { describe, expect, it } from 'vitest';
import { isAppToExtension, isExtensionToApp, type JobPageMessage } from '@/lib/protocol';
import { sanitizeJobPage } from '@/lib/sanitize';
import hello from '../../protocol/examples/hello.json';
import jobPage from '../../protocol/examples/job-page.json';
import ack from '../../protocol/examples/ack.json';
import pageLeft from '../../protocol/examples/page-left.json';
import applyButton from '../../protocol/examples/apply-button.json';
import applyComplete from '../../protocol/examples/apply-complete.json';
import rescan from '../../protocol/examples/rescan.json';
import rescanReload from '../../protocol/examples/rescan-reload.json';
import notPosting from '../../protocol/examples/not-posting.json';
import launchApp from '../../protocol/examples/launch-app.json';
import appWaiting from '../../protocol/examples/app-waiting.json';

describe('확장 ↔ 앱 메시지 규약 (공용 예시)', () => {
  it('확장 → 앱 예시는 모두 규약에 맞다', () => {
    expect(isExtensionToApp(hello)).toBe(true);
    expect(isExtensionToApp(jobPage)).toBe(true);
    expect(isExtensionToApp(pageLeft)).toBe(true);
    expect(isExtensionToApp(applyButton)).toBe(true);
    expect(isExtensionToApp(applyComplete)).toBe(true);
    expect(isExtensionToApp(notPosting)).toBe(true);
    expect(isExtensionToApp(launchApp)).toBe(true);
  });

  it('공고 예시는 이미 걸러진 모양이다 (거르기 전후가 같다)', () => {
    expect(sanitizeJobPage(jobPage as JobPageMessage)).toEqual(jobPage);
  });

  it('앱 → 확장 예시는 규약에 맞다', () => {
    expect(isAppToExtension(ack)).toBe(true);
    expect(isAppToExtension(rescan)).toBe(true);
    expect(isAppToExtension(rescanReload)).toBe(true);
    expect(isAppToExtension(appWaiting)).toBe(true);
    expect(isAppToExtension({ type: 'rescan', reload: 'yes' })).toBe(false);
  });

  it('필수 필드가 빠지거나 모르는 type이면 거부한다', () => {
    expect(isExtensionToApp({ type: 'hello' })).toBe(false);
    expect(isExtensionToApp({ type: 'jobPage', site: 'wanted' })).toBe(false);
    expect(isExtensionToApp({ type: 'jobPage', site: 'wanted', url: 'u' })).toBe(false);
    expect(isExtensionToApp({ type: 'jobPage', site: 'wanted', url: 'u', companies: [1] })).toBe(
      false,
    );
    expect(isExtensionToApp({ type: 'applyButton', covering: 'yes' })).toBe(false);
    expect(isExtensionToApp({ type: 'unknown' })).toBe(false);
    expect(isExtensionToApp(null)).toBe(false);
    expect(isAppToExtension({ type: 'ack' })).toBe(false);
    expect(isAppToExtension([ack])).toBe(false);
  });
});

describe('지원 사이트 설정 메시지', () => {
  it('검사를 통과한 설정만 받는다', async () => {
    const { DEFAULT_CONFIG } = await import('@/lib/siteConfig');
    expect(isAppToExtension({ type: 'siteConfig', config: DEFAULT_CONFIG })).toBe(true);
    expect(isAppToExtension({ type: 'siteConfig', config: { version: 1, sites: [] } })).toBe(false);
  });
});
