import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { cleanQuestion, parseSections, pickSections, userPrompt } from '../src/help.js';

const root = new URL('../../../website/', import.meta.url);
const nl = parseSections(readFileSync(new URL('handleiding/iphone.html', root), 'utf8'));
const en = parseSections(readFileSync(new URL('en/guide/android.html', root), 'utf8'));

test('reads the sections of the manuals', () => {
  assert.ok(nl.length >= 10, `nl: ${nl.length}`);
  assert.ok(en.length >= 10, `en: ${en.length}`);
  const ids = nl.map((section) => section.id);
  assert.ok(ids.includes('scheidsrechter') && ids.includes('badges'));
  for (const section of nl) {
    assert.ok(!section.text.includes('<'), `no tags in ${section.id}`);
    assert.ok(section.title.length > 0);
  }
});

test('picks the sections that fit the question', () => {
  assert.equal(pickSections(nl, 'Hoe werken de badges?')[0].id, 'badges');
  assert.equal(pickSections(nl, 'Waar vind ik mijn teamlink?')[0].id, 'teamlink-vinden');
  assert.equal(pickSections(en, 'How do I make a backup?')[0].id, 'settings');
  const picked = pickSections(nl, 'scheidsrechter let stroke');
  assert.ok(picked.reduce((sum, section) => sum + section.text.length, 0) <= 9000);
});

test('cleans the question and builds the prompt', () => {
  assert.equal(cleanQuestion('  hoe\n werkt   dit? '), 'hoe werkt dit?');
  assert.equal(cleanQuestion('a'), '');
  assert.equal(cleanQuestion('x'.repeat(301)), '');
  assert.equal(cleanQuestion(42), '');
  assert.match(userPrompt('Wat?', [{ title: 'Badges', text: 'Uitleg' }]), /### Badges\nUitleg/);
});
