// @vitest-environment happy-dom
import { describe, expect, it } from 'vitest';
import { dayKey, shouldAskLaunch } from '@/lib/launchPrompt';
import { showLaunchDialog } from '@/lib/launchDialog';

const base = { site: 'saramin', appNotRunning: true, skippedDay: undefined, today: '2026-10-26' };

describe('앱 실행 확인창을 띄울지', () => {
  it('앱이 꺼져 있고 사람인 · 잡플래닛 · 원티드 공고면 묻는다', () => {
    expect(shouldAskLaunch(base)).toBe(true);
    expect(shouldAskLaunch({ ...base, site: 'jobplanet' })).toBe(true);
    expect(shouldAskLaunch({ ...base, site: 'wanted' })).toBe(true);
  });

  it('다른 사이트 공고, 앱이 켜져 있음, 오늘 묻지 않기를 고른 날에는 묻지 않는다', () => {
    expect(shouldAskLaunch({ ...base, site: 'jobkorea' })).toBe(false);
    expect(shouldAskLaunch({ ...base, appNotRunning: false })).toBe(false);
    expect(shouldAskLaunch({ ...base, skippedDay: '2026-10-26' })).toBe(false);
  });

  it('묻지 않기를 고른 날이 지나면 다시 묻는다', () => {
    expect(shouldAskLaunch({ ...base, skippedDay: '2026-10-25' })).toBe(true);
  });

  it('날짜는 사용자 시간대 기준 YYYY-MM-DD', () => {
    expect(dayKey(new Date(2026, 0, 5, 23, 59))).toBe('2026-01-05');
  });
});

describe('앱 실행 확인창', () => {
  const shadow = () => document.querySelector('chaewoomi-launch-dialog')?.shadowRoot;
  const click = (answer: string) =>
    shadow()?.querySelector<HTMLButtonElement>(`[data-answer="${answer}"]`)?.click();

  it('묻지 않기는 기본 체크이고, 열기를 누르면 열기 · 묻지 않기로 끝나고 창이 사라진다', async () => {
    const answer = showLaunchDialog(document);
    expect(shadow()?.querySelector('h2')?.textContent).toBe('채우미 앱을 실행하시겠습니까?');
    expect(shadow()?.querySelector('input')?.checked).toBe(true);
    click('open');
    await expect(answer).resolves.toEqual({ open: true, skipToday: true });
    expect(shadow()).toBeUndefined();
  });

  it('체크를 풀고 열지 않음을 누르면 오늘 다시 물을 수 있게 끝난다', async () => {
    const answer = showLaunchDialog(document);
    shadow()?.querySelector('input')?.click();
    click('close');
    await expect(answer).resolves.toEqual({ open: false, skipToday: false });
  });

  it('Esc는 열지 않음과 같다', async () => {
    const answer = showLaunchDialog(document);
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));
    await expect(answer).resolves.toEqual({ open: false, skipToday: true });
  });
});
