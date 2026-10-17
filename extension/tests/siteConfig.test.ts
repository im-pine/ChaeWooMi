import { describe, expect, it } from 'vitest';
import {
  configProblems,
  DEFAULT_CONFIG,
  hostPatterns,
  postingSite,
  type SiteConfig,
} from '@/lib/siteConfig';

const clone = (): SiteConfig => structuredClone(DEFAULT_CONFIG);

describe('지원 사이트 설정 검사 (WEB-014)', () => {
  it('기본 설정은 검사에 통과하고 세 사이트 모두 구조화 데이터를 먼저 읽는다', () => {
    expect(configProblems(DEFAULT_CONFIG)).toEqual([]);
    expect(DEFAULT_CONFIG.sites.every((site) => site.company.jsonLd)).toBe(true);
  });

  it('설정에 새 플랫폼을 더하면 확장 코드 수정 없이 그 사이트 공고를 알아본다 (QA-063)', () => {
    const config = clone();
    const base = config.sites[2]!;
    config.sites.push({
      ...base,
      id: 'virtualjobs',
      label: '가상잡스',
      domains: ['virtualjobs.example.com'],
      postingPatterns: ['^/jobs/\\d+'],
    });
    expect(configProblems(config)).toEqual([]);
    expect(postingSite('https://virtualjobs.example.com/jobs/7', config)?.id).toBe('virtualjobs');
    expect(hostPatterns(config)).toContain('https://*.virtualjobs.example.com/*');
  });

  it('버전 · 빈 사이트 · 모양 · 도메인 · 정규식 오류를 경로와 함께 알린다', () => {
    expect(configProblems({ version: 2, sites: [] })).toEqual(['version: 1이어야 합니다']);
    expect(configProblems({ version: 1, sites: [] })).toEqual(['sites: 사이트가 없습니다']);
    expect(configProblems({ version: 1, sites: [{ id: 'x' }] })).toEqual([
      'sites[0]: 항목 모양이 다릅니다',
    ]);
    const config = clone();
    config.sites[0]!.domains = ['https://www.saramin.co.kr/'];
    config.sites[1]!.postingPatterns = ['(unclosed'];
    expect(configProblems(config)).toEqual([
      'sites[0].domains[0]: 도메인 형식이 아닙니다',
      'sites[1].postingPatterns[0]: 정규식이 아닙니다',
    ]);
    expect(configProblems(null)).toEqual(['설정이 객체가 아닙니다']);
  });
});
