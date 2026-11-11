-- The account mails through Cirrux (11 November 2026, src/mail.js).
-- A change of e-mail address waits here for the link in the mail to the new
-- address (kind 'change', 24 hours); after the change, the link in the mail to
-- the old address can undo it (kind 'undo', 7 days). Only hashes of the codes.
CREATE TABLE email_changes (
  code_hash TEXT PRIMARY KEY,
  uid TEXT NOT NULL,
  kind TEXT NOT NULL,            -- change or undo
  old_email TEXT NOT NULL,
  new_email TEXT NOT NULL,
  lang TEXT NOT NULL,            -- nl or en
  expires_at INTEGER NOT NULL    -- milliseconds
);
CREATE INDEX email_changes_uid ON email_changes (uid);

-- One row per mail sent, per address and per IP address (hashed), to brake
-- abuse; the nightly job keeps one day
CREATE TABLE mail_log (
  key_hash TEXT NOT NULL,
  sent_at INTEGER NOT NULL
);
CREATE INDEX mail_log_key ON mail_log (key_hash, sent_at);
