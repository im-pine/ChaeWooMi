/**
 * 공고 페이지에서 채우미 앱 실행을 묻는 확인창 (사용자 요청 2026-10-26).
 * 앱은 저절로 켜지 않는다. 사람인 · 잡코리아 · 원티드 공고를 열었는데 앱이 꺼져 있으면 묻고,
 * "오늘 하루 묻지 않기"(기본 체크)를 고른 날에는 다시 묻지 않는다.
 */

/** 확인창을 띄우는 사이트 (설정의 사이트 id). 잡플래닛 공고는 잡코리아 공고 페이지로 열린다 (2026-10 실측) */
export const LAUNCH_PROMPT_SITES = ['saramin', 'jobkorea', 'wanted'];

/** background → 콘텐츠 스크립트: 확인창을 띄우고 고른 답을 돌려 달라 */
export const ASK_LAUNCH = 'chaewoomi-ask-launch';

/** `storage.local`에 남기는 "오늘 하루 묻지 않기"를 고른 날 */
export const SKIPPED_DAY_KEY = 'launchPromptSkippedDay';

export type LaunchAnswer = { open: boolean; skipToday: boolean };

/** 사용자 시간대 기준 날짜 `YYYY-MM-DD` */
export function dayKey(date: Date): string {
  const pad = (value: number) => String(value).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

/** 앱이 꺼져 있고(호스트가 기다리는 중), 확인창 사이트 공고이고, 오늘 묻지 않기를 고르지 않았을 때만 묻는다 */
export function shouldAskLaunch(input: {
  site: string;
  appNotRunning: boolean;
  skippedDay: unknown;
  today: string;
}): boolean {
  return (
    input.appNotRunning &&
    LAUNCH_PROMPT_SITES.includes(input.site) &&
    input.skippedDay !== input.today
  );
}
