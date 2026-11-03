// The link preview of a single match (preview.js): the stand at the moment of sharing.
import { describe, expect, it } from 'vitest';
import { previewLines } from '../src/preview.js';
import { validateSnapshot } from '../src/validate.js';

const base = {
  p1: 'Jansen', p2: 'Vries', bestOf: 5, games: [[11, 8], [9, 11], [11, 6]], score: [7, 5], gamesWon: [2, 1],
  server: 1, side: 'R', status: 'playing',
};

describe('previewLines', () => {
  it('shows games won in the title and the running game in the description', () => {
    expect(previewLines(base)).toEqual({
      title: '🔴 Live: Jansen 2 – 1 Vries',
      description: 'Game 4 · 7–5 · volg live in SquashAnalyzer',
    });
  });

  it('between two games shows the next game at 0–0', () => {
    const between = { ...base, status: 'between', score: [0, 0] };
    expect(previewLines(between).description).toBe('Game 4 · 0–0 · volg live in SquashAnalyzer');
  });

  it('during the warm-up shows no game yet', () => {
    const warmup = { ...base, status: 'warmup', games: [], score: [0, 0], gamesWon: [0, 0] };
    expect(previewLines(warmup)).toEqual({
      title: '🔴 Live: Jansen 0 – 0 Vries', description: 'Inspelen · volg live in SquashAnalyzer',
    });
  });

  it('a finished match shows the final score instead of the running game', () => {
    const finished = { ...base, status: 'finished', games: [...base.games, [11, 4]], score: [11, 4], gamesWon: [3, 1], winner: 1 };
    expect(previewLines(finished)).toEqual({
      title: 'Uitslag: Jansen 3 – 1 Vries', description: 'Eindstand · 11–8, 9–11, 11–6, 11–4',
    });
    expect(previewLines(finished, 'en')).toEqual({
      title: 'Result: Jansen 3 – 1 Vries', description: 'Final score · 11–8, 9–11, 11–6, 11–4',
    });
  });

  it('in English', () => {
    expect(previewLines(base, 'en').description).toBe('Game 4 · 7–5 · follow live');
    expect(previewLines(null, 'en').description).toBe('This live match has ended.');
    expect(previewLines(base, 'fr').description).toMatch(/volg live/);
  });

  it('a match that is gone has no stand', () => {
    expect(previewLines(null)).toEqual({ title: 'SquashAnalyzer · live', description: 'Deze livewedstrijd is afgelopen.' });
  });

  it('long names stay whole, as the server cut them (first names, at most 20 letters)', () => {
    const long = validateSnapshot({ ...base, p1: 'Maximiliaan-Alexander de Groot', p2: 'Anne-Marie Dijkstra' });
    expect(previewLines(long).title).toBe('🔴 Live: Maximiliaan-Alexande 2 – 1 Anne-Marie');
  });
});
