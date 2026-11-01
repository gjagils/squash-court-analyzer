-- Linking without a player code (Gerd-Jan, 1 November 2026): a coach sends a
-- match for "this SBN player" or for "the name I use, in my team", also when
-- that player has no account yet. It waits here until someone claims it.

-- The SBN team a player plays in ("<league uuid>/<team number>"), for the
-- matches of their team that still wait for a name
ALTER TABLE players ADD COLUMN team_key TEXT;

-- A match nobody has yet. `target` is who it is for:
--   'sbn:<player path>'   an SBN player (moves to the player once they make an account)
--   'team:<team key>'     the name the sender uses (`name`) in that team; teammates claim it
--   'link:<hash>'         whoever opens the link the sender shared
CREATE TABLE open_matches (
  id TEXT NOT NULL,
  target TEXT NOT NULL,
  name TEXT NOT NULL DEFAULT '',
  device_id TEXT,
  sender_name TEXT NOT NULL DEFAULT '',
  played_at INTEGER NOT NULL,
  received_at INTEGER NOT NULL,
  team_key TEXT,
  opponent TEXT NOT NULL DEFAULT '',
  summary TEXT NOT NULL,
  rallies TEXT NOT NULL,
  PRIMARY KEY (id, target, name)
);
CREATE INDEX open_matches_target ON open_matches (target, received_at);
CREATE INDEX open_matches_device ON open_matches (device_id, received_at);

-- What a claim taught a sending phone: the name it uses in that team is this
-- SBN player. The phone fetches these and links the player in Spelers, so its
-- next match goes to the player at once.
CREATE TABLE learned_links (
  device_id TEXT NOT NULL,
  team_key TEXT NOT NULL,
  name TEXT NOT NULL,
  sbn_path TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (device_id, team_key, name)
);
