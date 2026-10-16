import js from '@eslint/js';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  { ignores: ['.output/', '.wxt/', 'node_modules/'] },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    rules: {
      // 함수 하나 = 한 가지 일 신호 (R-SRP-01). 경고만 한다.
      'max-lines-per-function': ['warn', { max: 40, skipBlankLines: true, skipComments: true }],
      complexity: ['warn', 10],
    },
  },
);
