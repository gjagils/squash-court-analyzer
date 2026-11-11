import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { cleanQuestion, parseSections, pickSections, redact, statsView, userPrompt } from '../src/help.js';

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

test('takes e-mail addresses and phone numbers out', () => {
  assert.equal(redact('mail me op jan@example.com of 06-12345678'), 'mail me op [e-mail] of [nummer]');
  assert.equal(redact('Hoe werkt E1 tot E4?'), 'Hoe werkt E1 tot E4?');
});

test('counts questions per day for the owner', () => {
  const now = Date.parse('2026-11-11T12:00:00Z');
  const rows = [
    { asked_at: now - 1000, lang: 'nl', platform: 'iphone', source: 'app', question: 'a', answered: 1 },
    { asked_at: now - 86400000, lang: 'en', platform: 'android', source: 'web', question: 'b', answered: 0 },
  ];
  const view = statsView(rows, 3, now);
  assert.equal(view.total, 2);
  assert.equal(view.unanswered, 1);
  assert.deepEqual(view.perDay.map((d) => d.count), [0, 1, 1]);
  assert.equal(view.questions[0].source, 'app');
});
