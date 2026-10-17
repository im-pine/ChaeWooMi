import {
  applyButtonCovering,
  completeOnPage,
  readPage,
  WAIT_FOR_COMPANY_MS,
  type PageReport,
} from '@/lib/postingWatch';
import { DEFAULT_CONFIG, configProblems, hostPatterns, type SiteConfig } from '@/lib/siteConfig';
import { sameDocument } from '@/lib/tabPages';
import type { ContentScriptContext } from 'wxt/utils/content-script-context';

async function currentConfig(): Promise<SiteConfig> {
  const stored = (await browser.storage.local.get('siteConfig')).siteConfig;
  return configProblems(stored).length === 0 ? (stored as SiteConfig) : DEFAULT_CONFIG;
}

const report = (message: PageReport) =>
  void browser.runtime.sendMessage(message).catch(() => undefined);

/**
 * 공고 페이지면 회사명 · 공고 원문을 읽어 background에 보낸다.
 * 회사명이 아직 없으면(본문을 나중에 불러오는 사이트) DOM 변화를 보며 최대 5초 기다린다. 폴링하지 않는다.
 */
function scan(config: SiteConfig, ctx: ContentScriptContext) {
  const first = readPage(document, location.href, config);
  if (first.kind === 'left' || first.page.companies.length > 0) {
    report(first);
    return;
  }
  const observer = new MutationObserver(() => {
    const next = readPage(document, location.href, config);
    if (next.kind === 'posting' && next.page.companies.length > 0) {
      observer.disconnect();
      report(next);
    }
  });
  observer.observe(document.documentElement, { childList: true, subtree: true });
  ctx.setTimeout(() => {
    observer.disconnect();
    report(readPage(document, location.href, config));
  }, WAIT_FOR_COMPANY_MS);
}

/** 스크롤 · 크기 변화 때 지원 버튼이 카드 자리를 가리는지 알린다 (바뀔 때만) */
function watchApplyButton(config: SiteConfig, ctx: ContentScriptContext) {
  let last: boolean | null = null;
  const check = () => {
    const covering = applyButtonCovering(document, location.href, config, {
      width: window.innerWidth,
      height: window.innerHeight,
    });
    if (covering !== last) report({ kind: 'applyButton', covering });
    last = covering;
  };
  ctx.addEventListener(window, 'scroll', check, { passive: true });
  ctx.addEventListener(window, 'resize', check);
  check();
}

/** 지원 완료 화면(HIS-017)을 DOM 변화마다 0.5초 모아 확인하고, 주소마다 한 번만 알린다 */
function watchCompletion(config: SiteConfig, ctx: ContentScriptContext) {
  let reported: string | null = null;
  let pending = false;
  const check = () => {
    pending = false;
    if (reported === location.href || !completeOnPage(document, location.href, config)) return;
    reported = location.href;
    report({ kind: 'complete' });
  };
  const observer = new MutationObserver(() => {
    if (pending) return;
    pending = true;
    ctx.setTimeout(check, 500);
  });
  observer.observe(document.documentElement, {
    childList: true,
    subtree: true,
    characterData: true,
  });
  ctx.onInvalidated(() => observer.disconnect());
  check();
}

export default defineContentScript({
  // 런타임 등록: background가 설정 도메인 중 권한이 있는 곳에만 등록한다 (WEB-002 · WEB-014)
  registration: 'runtime',
  matches: hostPatterns(DEFAULT_CONFIG),
  runAt: 'document_idle',
  async main(ctx) {
    const config = await currentConfig();
    scan(config, ctx);
    watchApplyButton(config, ctx);
    watchCompletion(config, ctx);
    // SPA 주소 변경(원티드 등): 이전 회사 결과를 비우고 다시 읽는다 (WEB-015)
    ctx.addEventListener(window, 'wxt:locationchange', ({ newUrl, oldUrl }) => {
      // 해시만 바뀌면 같은 공고 (사람인 `#seq=0`) — 비우고 다시 읽지 않는다
      if (sameDocument(newUrl.href, oldUrl.href)) return;
      report({ kind: 'left' });
      scan(config, ctx);
    });
  },
});
