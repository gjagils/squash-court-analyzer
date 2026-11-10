-- The avatar of an account (Gerd-Jan, 10 November 2026): a small square JPEG
-- the player chose, with consent that whoever picks them as a player may see
-- it. Phones ask for it by SBN player path (only players linked to an SBN
-- player get it). `version` changes with every new photo, so phones only
-- download a photo they do not have yet. Gone with the account.
CREATE TABLE avatars (
  player_id TEXT PRIMARY KEY,   -- players.id
  image TEXT NOT NULL,          -- base64 of the JPEG (at most 300 KB)
  version INTEGER NOT NULL,     -- milliseconds of the upload
  consent_at INTEGER NOT NULL
);

-- "Foto melden": one row per phone and photo, for a look by hand
CREATE TABLE avatar_reports (
  player_id TEXT NOT NULL,
  device_id TEXT NOT NULL,
  version INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (player_id, device_id)
);
