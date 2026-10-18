import type {
  ApplyButtonMessage,
  ApplyCompleteMessage,
  ExtensionToApp,
  JobPageMessage,
} from './protocol';
import { sanitizeUrl } from './sanitize';

/**
 * 탭마다 마지막 공고 상태를 기억하고, **보고 있는 탭**의 상태만 앱에 보낸다 (WEB-015).
 * 다른 탭으로 옮기면 그 탭의 공고를 보내거나, 공고가 아니면 pageLeft를 보낸다.
 */
/**
 * 같은 공고 주소인가: 공고 정보와 같은 규칙(허용 쿼리만 · 해시 없음)으로 거른 주소가 같으면.
 * 저장한 공고 주소는 이미 걸러져 있어 탭 주소(`view_type=…#seq=0`)와 그대로 비교하면 늘 다르다 (실측)
 */
export function sameDocument(a: string, b: string): boolean {
  try {
    return sanitizeUrl(a) === sanitizeUrl(b);
  } catch {
    return false;
  }
}

/** service worker가 다시 시작돼도 이어 쓰도록 `storage.session`에 두는 모양 */
export type TabPagesState = {
  pages: [number, JobPageMessage][];
  active: number | null;
  latest: JobPageMessage | null;
};

export class TabPages {
  private pages = new Map<number, JobPageMessage>();
  private active: number | null = null;
  /** 가장 최근에 본 공고 (어느 탭이든). 지원 완료 화면이 팝업 · 다른 주소로 떠도 그 공고로 기록한다 */
  private latest: JobPageMessage | null = null;

  /** 탭의 공고가 바뀜. 보고 있는 탭이면 앱에 보낼 메시지 */
  posting(tabId: number, page: JobPageMessage): ExtensionToApp | null {
    this.pages.set(tabId, page);
    this.latest = page;
    return tabId === this.active ? page : null;
  }

  /** 탭이 공고가 아닌 페이지로 옮김 */
  left(tabId: number): ExtensionToApp | null {
    const had = this.pages.delete(tabId);
    return tabId === this.active && had ? { type: 'pageLeft' } : null;
  }

  applyButton(tabId: number, covering: boolean): ApplyButtonMessage | null {
    return tabId === this.active ? { type: 'applyButton', covering } : null;
  }

  /** 다른 탭을 보기 시작함 */
  activate(tabId: number): ExtensionToApp {
    this.active = tabId;
    return this.pages.get(tabId) ?? { type: 'pageLeft' };
  }

  /** 보고 있는 탭의 지금 상태 (다시 연결했을 때 보냄) */
  current(): ExtensionToApp {
    return (this.active !== null && this.pages.get(this.active)) || { type: 'pageLeft' };
  }

  /**
   * 탭이 새 페이지를 불러오기 시작함 (다른 사이트로 가도 알 수 있도록). 새 페이지가 공고면 콘텐츠 스크립트가 다시 알린다.
   * 주소가 해시만 다르면 같은 문서라 공고를 지우지 않는다 (사람인은 공고를 연 뒤 `#seq=0`을 붙인다)
   */
  navigating(tabId: number, url?: string): ExtensionToApp | null {
    const page = this.pages.get(tabId);
    if (page && url && sameDocument(page.url, url)) return null;
    return this.left(tabId);
  }

  /** 이 탭의 공고를 알고 있는가 */
  has(tabId: number): boolean {
    return this.pages.has(tabId);
  }

  /** 저장할 상태 */
  state(): TabPagesState {
    return { pages: [...this.pages], active: this.active, latest: this.latest };
  }

  /** 저장해 둔 상태로 되살린다 (service worker 재시작) */
  static restore(state: TabPagesState | undefined): TabPages {
    const tabs = new TabPages();
    if (!state) return tabs;
    tabs.pages = new Map(state.pages);
    tabs.active = state.active;
    tabs.latest = state.latest;
    return tabs;
  }

  /** 지원 완료 화면 감지 (HIS-017). 본 공고가 없으면 보내지 않는다 (회사를 모름) */
  complete(): ApplyCompleteMessage | null {
    if (!this.latest) return null;
    const { site, url, companies, title } = this.latest;
    return { type: 'applyComplete', site, url, companies, ...(title ? { title } : {}) };
  }

  /** 탭을 닫음 */
  closed(tabId: number): ExtensionToApp | null {
    return this.left(tabId);
  }
}
