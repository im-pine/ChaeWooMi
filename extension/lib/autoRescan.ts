import { sameDocument } from './tabPages';

/**
 * 탭에 들어갈 때 자동으로 다시 읽을지 정한다 ("지원 이력 확인"을 누르지 않아도 카드가 뜨게).
 * 확장을 새로고침 · 업데이트하기 전에 열어 둔 탭은 콘텐츠 스크립트가 끊겨 스스로 보고하지 않는다 →
 * 그 탭이 지정 사이트 공고인데 확장에 그 탭의 공고가 없으면 다시 읽는다.
 * 같은 탭 · 같은 공고에서는 한 번만 시도한다 (계속 다시 넣지 않게). 새로고침은 자동으로 하지 않는다.
 */
export class AutoRescan {
  private tried = new Map<number, string>();

  /** `isPosting`: 지정 사이트 공고 주소인가, `hasPage`: 확장이 그 탭의 공고를 알고 있는가 */
  shouldTry(tabId: number, url: string | undefined, isPosting: boolean, hasPage: boolean): boolean {
    if (!url || !isPosting || hasPage) return false;
    const previous = this.tried.get(tabId);
    if (previous !== undefined && sameDocument(previous, url)) return false;
    this.tried.set(tabId, url);
    return true;
  }

  /** 탭을 닫음 */
  forget(tabId: number) {
    this.tried.delete(tabId);
  }
}

/** 탭에 들어간 뒤 자동으로 다시 읽기 전 기다리는 시간. 막 연 탭은 콘텐츠 스크립트가 곧 스스로 보고한다 */
export const AUTO_RESCAN_DELAY_MS = 1500;
