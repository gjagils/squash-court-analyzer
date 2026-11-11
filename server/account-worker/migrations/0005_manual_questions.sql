-- Questions asked with "Stel een vraag" (website and app, 11 November 2026):
-- for improving the app and the manual, and for ideas. Written by the website
-- Worker (squashanalyzer-site), which binds this database too. No IP address,
-- no account; e-mail addresses and phone numbers are taken out before storing.
-- The account Worker's nightly job deletes rows older than 180 days.
CREATE TABLE manual_questions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  asked_at INTEGER NOT NULL,     -- milliseconds
  lang TEXT NOT NULL,            -- nl or en
  platform TEXT NOT NULL,        -- iphone or android
  source TEXT NOT NULL,          -- app or web
  question TEXT NOT NULL,
  answered INTEGER NOT NULL      -- 1 when the model gave an answer
);
CREATE INDEX manual_questions_asked ON manual_questions (asked_at);
