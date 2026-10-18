import { describe, expect, it } from 'vitest';
import { splitByPermission } from '@/lib/registration';
import { DEFAULT_CONFIG, type SiteConfig } from '@/lib/siteConfig';

describe('권한이 있는 도메인에만 콘텐츠 스크립트 등록 (WEB-002)', () => {
  it('기본 세 도메인은 등록하고, 설정에 더한 도메인은 승인 전까지 등록하지 않는다', async () => {
    const config: SiteConfig = structuredClone(DEFAULT_CONFIG);
    config.sites.push({
      ...config.sites[2]!,
      id: 'virtualjobs',
      domains: ['virtualjobs.example.com'],
    });
    const granted = new Set([
      'https://*.saramin.co.kr/*',
      'https://*.jobkorea.co.kr/*',
      'https://*.wanted.co.kr/*',
    ]);

    const result = await splitByPermission(config, async (pattern) => granted.has(pattern));

    expect(result.granted).toEqual([...granted]);
    expect(result.missing).toEqual(['https://*.virtualjobs.example.com/*']);
  });

  it('사용자가 승인하면 그 도메인도 등록 대상이 된다', async () => {
    const config: SiteConfig = structuredClone(DEFAULT_CONFIG);
    config.sites.push({
      ...config.sites[2]!,
      id: 'virtualjobs',
      domains: ['virtualjobs.example.com'],
    });
    const result = await splitByPermission(config, async () => true);
    expect(result.missing).toEqual([]);
    expect(result.granted).toContain('https://*.virtualjobs.example.com/*');
  });
});
