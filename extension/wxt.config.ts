import { defineConfig } from 'wxt';
import { HOST_PERMISSIONS, OPTIONAL_HOST_PERMISSIONS } from './lib/sites';

export default defineConfig({
  manifest: {
    name: 'ChaeWooMi',
    description: '채용공고의 회사가 1년 안에 지원한 곳인지 채우미 앱에 알려 줍니다.',
    // 공개 키로 확장 ID를 고정한다 (abceklimfjcabkeahgahfakmajlimbem).
    // Native Messaging 호스트 등록 파일의 allowed_origins가 이 ID만 허용한다.
    key: 'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEArmg66drVTvpsKSK5qp64hYFiT/xRN+SPo27OLCMXns10jHovcCiiMaJRCW+qCmN4ZVXU4BCkunW9f0InPFfcqZLaOxmaIOh0M46VZFnpBBbin10vp1Ocv5W7252uYqPfu/aiEL0sLU21ySEmhWJRzfOA3OE/P2+CxLkvcRf9p+z88MUkmyrp/ZXsgUFy4v+t1TWKjXTse3LFMlGNYLeV5Ep/PEjGeI/sxriunm9CZ8+hH9O6vEwgfNJ8Jk7WTn8lbed1NFrIGsJ92sMpnlWZqEy913KnXoO3t+SlXAgBQoaWG6e6g+vWV7Iek5orMNSXerGCxBvW5HGl1AQefxZA6QIDAQAB',
    permissions: ['nativeMessaging', 'storage', 'scripting', 'alarms'],
    host_permissions: HOST_PERMISSIONS,
    optional_host_permissions: OPTIONAL_HOST_PERMISSIONS,
  },
});
