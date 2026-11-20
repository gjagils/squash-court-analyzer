-- "Je team is begonnen" (Gerd-Jan, 21 November 2026): the push token of a phone
-- that is signed in, so teammates hear it when someone of the team makes a
-- team match visible for the team. Only used for that: the account Worker
-- signs the token up as an alerts follower of that live team match on the live
-- Worker and never sends a push itself. Sent by the app while "Meldingen van je
-- teamwedstrijd" is on; gone when it is switched off, on signing out, with the
-- account, and when the phone has not been seen for 60 days.
CREATE TABLE push_tokens (
  player_id TEXT NOT NULL,       -- players.id
  token TEXT NOT NULL,           -- APNs device token (hex) or FCM token
  platform TEXT NOT NULL,        -- "ios" or "android"
  sandbox INTEGER NOT NULL DEFAULT 0,  -- an iOS development build
  lang TEXT NOT NULL DEFAULT 'nl',     -- "nl" or "en": the language of the notification
  device TEXT,                   -- the phone's install id for the live server (LiveDevice)
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (player_id, token)
);
CREATE INDEX push_tokens_token ON push_tokens (token);
CREATE INDEX push_tokens_updated ON push_tokens (updated_at);
