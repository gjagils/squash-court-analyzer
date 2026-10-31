-- Squash Analyzer 4.0: the player account (docs/voorstel-spelersaccount-4.0.md).
-- Only what badges, card, form and trend need; the full analysis stays on the
-- phone of whoever entered the match. The rallies sit in their own column so
-- they can move to R2 later (D1 has a 10 GB limit per database).

-- One row per signed-in person: the Firebase uid and the player it is
CREATE TABLE accounts (
  uid TEXT PRIMARY KEY,
  player_id TEXT NOT NULL UNIQUE,
  birth_year INTEGER NOT NULL,
  consent_at INTEGER NOT NULL,
  created_at INTEGER NOT NULL
);

-- The player others send matches to: a code (and QR) to hand out, and the SBN
-- player path for team matches when known
CREATE TABLE players (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  code TEXT NOT NULL UNIQUE,
  sbn_path TEXT UNIQUE,
  created_at INTEGER NOT NULL
);

-- A phone that may send matches without an account: only a hash of its key is kept
CREATE TABLE devices (
  id TEXT PRIMARY KEY,
  key_hash TEXT NOT NULL,
  ip_hash TEXT NOT NULL,
  created_at INTEGER NOT NULL
);
CREATE INDEX devices_ip ON devices (ip_hash, created_at);

-- Matches of a player: 'pending' waits for the player's answer, 'accepted' counts.
-- The id is the match id the sending phone chose, so a retry never makes two.
CREATE TABLE matches (
  player_id TEXT NOT NULL,
  id TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('pending', 'accepted')),
  device_id TEXT,
  sender_name TEXT NOT NULL DEFAULT '',
  played_at INTEGER NOT NULL,
  received_at INTEGER NOT NULL,
  decided_at INTEGER,
  team_key TEXT,
  opponent TEXT NOT NULL DEFAULT '',
  summary TEXT NOT NULL,
  rallies TEXT NOT NULL,
  PRIMARY KEY (player_id, id)
);
CREATE INDEX matches_status ON matches (player_id, status, received_at);
CREATE INDEX matches_device ON matches (device_id, received_at);

-- Awards the app worked out with BadgeEngine; deleted ones keep a tombstone so
-- a merge from another phone does not bring them back
CREATE TABLE awards (
  player_id TEXT NOT NULL,
  id TEXT NOT NULL,
  value TEXT NOT NULL,
  deleted_at INTEGER,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (player_id, id)
);

-- Phones a player no longer wants matches from
CREATE TABLE blocks (
  player_id TEXT NOT NULL,
  device_id TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (player_id, device_id)
);
