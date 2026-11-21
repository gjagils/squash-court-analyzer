-- "Teamstand vanzelf op je vergrendelscherm" (Gerd-Jan, 21 November 2026):
-- how the lock screen card of this phone can be started when the team
-- starts. iOS: the push-to-start token of the team Live Activity (hex);
-- Android: "fcm" (the phone's own FCM token shows the ongoing notification).
-- NULL: the phone gets the plain notification "Je team is begonnen" only.
-- Passed on to the live Worker with the announcement, never used here.
ALTER TABLE push_tokens ADD COLUMN start TEXT;
