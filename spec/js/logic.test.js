// Unit tests for the DOM-free client helpers extracted in BT-112.
// Run with:  node --test spec/js/
const test = require('node:test');
const assert = require('node:assert');
const { storyNumber, byStoryNumber } = require('../../lib/bacon_tracker/assets/logic.js');

test('storyNumber returns the trailing number', () => {
  assert.strictEqual(storyNumber('BCN-042'), 42);
  assert.strictEqual(storyNumber('BT-001'), 1);
});

test('storyNumber ignores digits inside the namespace (BT-104)', () => {
  assert.strictEqual(storyNumber('B2B-007'), 7); // not 2
  assert.strictEqual(storyNumber('WEB3-010'), 10); // not 3
});

test('storyNumber is 0 for an id with no trailing digits', () => {
  assert.strictEqual(storyNumber('BT-x'), 0);
});

test('byStoryNumber orders stories by their trailing number', () => {
  const arr = [{ id: 'B2B-010' }, { id: 'B2B-002' }, { id: 'B2B-001' }];
  arr.sort(byStoryNumber);
  assert.deepStrictEqual(
    arr.map((s) => s.id),
    ['B2B-001', 'B2B-002', 'B2B-010']
  );
});

const { resolveDocPath } = require('../../lib/bacon_tracker/assets/logic.js');

test('resolveDocPath resolves siblings and parents against the page dir', () => {
  assert.strictEqual(
    resolveDocPath('guides/setup.md', 'deep/nested.txt'),
    'guides/deep/nested.txt'
  );
  assert.strictEqual(resolveDocPath('guides/setup.md', '../Home.md'), 'Home.md');
  assert.strictEqual(resolveDocPath('guides/setup.md', './other.md'), 'guides/other.md');
});

test('resolveDocPath refuses escapes and non-relative links (BT-140/BT-159)', () => {
  assert.strictEqual(resolveDocPath('guides/setup.md', '../../etc/passwd'), null);
  assert.strictEqual(resolveDocPath('Home.md', '../secret.md'), null);
  assert.strictEqual(resolveDocPath('a.md', 'https://example.com/x.md'), null);
  assert.strictEqual(resolveDocPath('a.md', '/abs.md'), null);
  assert.strictEqual(resolveDocPath('a.md', '#section'), null);
});

const { supersedeCandidates } = require('../../lib/bacon_tracker/assets/logic.js');

test('supersedeCandidates offers accepted records, never the record itself (BT-145)', () => {
  const records = [
    { id: 'A-ADR-0001', status: 'accepted' },
    { id: 'A-ADR-0002', status: 'accepted' },
    { id: 'A-ADR-0003', status: 'proposed' },
    { id: 'A-ADR-0004', status: 'superseded' },
  ];
  assert.deepStrictEqual(supersedeCandidates(records, 'A-ADR-0001'), ['A-ADR-0002']);
  assert.deepStrictEqual(supersedeCandidates(records, 'A-ADR-0009'), ['A-ADR-0001', 'A-ADR-0002']);
});

const { idNamespace, sameNamespace } = require('../../lib/bacon_tracker/assets/logic.js');

test('idNamespace and sameNamespace pair records with their own stories (BT-148)', () => {
  assert.strictEqual(idNamespace('TST-ADR-0004'), 'TST');
  assert.strictEqual(idNamespace('TST-129'), 'TST');
  assert.strictEqual(idNamespace('nonsense'), null);
  assert.ok(sameNamespace('TST-ADR-0004', 'TST-129'));
  assert.ok(!sameNamespace('TST-ADR-0004', 'OTH-129'));
  assert.ok(!sameNamespace('nonsense', 'nonsense'));
});

const { isExternalHref, hashId } = require('../../lib/bacon_tracker/assets/logic.js');

test('isExternalHref lets only http(s) and mailto reach the browser', () => {
  assert.ok(isExternalHref('https://example.com/x'));
  assert.ok(isExternalHref('HTTP://example.com'));
  assert.ok(isExternalHref('mailto:a@b.c'));
  assert.ok(!isExternalHref('javascript:alert(1)'));
  assert.ok(!isExternalHref('data:text/html,x'));
  assert.ok(!isExternalHref('java\nscript:alert(1)'));
  assert.ok(!isExternalHref('guides/setup.md'));
  assert.ok(!isExternalHref('#section'));
  assert.ok(!isExternalHref(''));
});

test('hashId decodes a location hash and never throws', () => {
  assert.strictEqual(hashId('#TST-042'), 'TST-042');
  assert.strictEqual(hashId('#TST%2D042'), 'TST-042');
  assert.strictEqual(hashId(''), '');
  assert.strictEqual(hashId('#%E0%A4%A'), ''); // malformed escape
});
