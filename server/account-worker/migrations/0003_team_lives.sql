-- A team match that teammates and the opponent can find (Gerd-Jan, 6 November
-- 2026; docs/voorstel-teamwedstrijd-vinden-4.0.md). A pointer to the live team
-- match on the live Worker, per team and SBN match. The owner key never comes
-- here. A row is gone at the start of the second day after the match day.
CREATE TABLE team_lives (
  team_key TEXT NOT NULL,        -- "<league uuid>/<team number>" of the team keeping it (players.team_key)
  fixture TEXT NOT NULL,         -- "/league/<UUID>/team-match/<n>": the SBN match, the same for both teams
  team_name TEXT NOT NULL,       -- shown to the opponent
  live_id TEXT NOT NULL,         -- TeamSession id on the live Worker
  write_key TEXT NOT NULL,       -- the invitation key: only for the own team
  referee_key TEXT,              -- the opponent's key: only the partijen they referee
  starter_id TEXT NOT NULL,      -- players.id of whoever registered it
  starter_name TEXT NOT NULL,
  match_at INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  PRIMARY KEY (team_key, fixture)
);
CREATE INDEX team_lives_fixture ON team_lives (fixture);
CREATE INDEX team_lives_expires ON team_lives (expires_at);
