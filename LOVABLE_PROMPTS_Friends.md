# Friends v1: Lovable prompts

Paste these into Lovable **in order**, one at a time, and confirm each applied before the next. The iOS client assumes exactly these names and shapes.

Design rules baked into every prompt:
- 13+ only. No public search or discovery. Friends join by invite code or link only.
- Sharing is **opt-in, default OFF**. Religious activity is sensitive (GDPR Art. 9), so the consent timestamp and version are stored.
- Friends never read another user's tables directly. They go through SECURITY DEFINER RPCs that return only the fields the owner opted to share.
- No free text between users. Nudges are a closed set of presets.
- Everything cascades on account deletion.

---

## Prompt 1: Core tables and RLS

```
Add the following to the Supabase database. First inspect the existing `profiles`, `user_blocks` and `content_reports` tables and reuse them. Do not recreate them. Use `auth.uid()` for ownership everywhere. All new tables get RLS enabled.

1. `friend_sharing_prefs`
   - user_id uuid primary key references auth.users(id) on delete cascade
   - share_streak boolean not null default false
   - share_weekly_chapters boolean not null default false
   - share_verses_memorized boolean not null default false
   - allow_nudges boolean not null default false
   - consent_at timestamptz null (set when the user first turns any share_* on)
   - consent_version text null
   - updated_at timestamptz not null default now()
   RLS: the owner can SELECT, INSERT and UPDATE their own row (user_id = auth.uid()). No one else can read it directly.

2. `friend_activity_snapshot` (ONE row per user, aggregates only, never raw reading history)
   - user_id uuid primary key references auth.users(id) on delete cascade
   - current_streak int not null default 0
   - read_today boolean not null default false
   - chapters_this_week int not null default 0
   - verses_memorized int not null default 0
   - week_start date not null
   - updated_at timestamptz not null default now()
   RLS: the owner can SELECT, INSERT and UPDATE their own row. No other direct access. Friends read it only through the RPC in Prompt 2.

3. `friendships`
   - id uuid primary key default gen_random_uuid()
   - user_a uuid not null references auth.users(id) on delete cascade
   - user_b uuid not null references auth.users(id) on delete cascade
   - created_at timestamptz not null default now()
   - check (user_a < user_b)  -- canonical ordering so a pair is stored once
   - unique (user_a, user_b)
   RLS: a user can SELECT rows where they are user_a or user_b. No direct INSERT or UPDATE (only the RPCs in Prompt 2). A user can DELETE rows they are part of.

4. `friend_invites`
   - id uuid primary key default gen_random_uuid()
   - inviter_id uuid not null references auth.users(id) on delete cascade
   - code text not null unique  -- 8 chars, unambiguous alphabet (no 0/O/1/I/L)
   - expires_at timestamptz not null default now() + interval '7 days'
   - used_by uuid null references auth.users(id) on delete set null
   - used_at timestamptz null
   - created_at timestamptz not null default now()
   RLS: the inviter can SELECT and DELETE their own invites. No direct INSERT or UPDATE (RPC only).

5. `friend_mutes`
   - user_id uuid not null references auth.users(id) on delete cascade
   - muted_id uuid not null references auth.users(id) on delete cascade
   - created_at timestamptz not null default now()
   - primary key (user_id, muted_id)
   RLS: the owner can SELECT, INSERT and DELETE their own rows.

6. `push_tokens`
   - token text primary key
   - user_id uuid not null references auth.users(id) on delete cascade
   - platform text not null default 'ios'
   - environment text not null check (environment in ('sandbox','production'))
   - updated_at timestamptz not null default now()
   RLS: the owner can SELECT, INSERT, UPDATE and DELETE rows where user_id = auth.uid(). Upserts must be able to move a token to a new user (the same device signing in as a different account): handle this inside the `register_push_token` RPC in Prompt 2, not through client RLS.

7. `friend_nudges` (audit and rate-limit log)
   - id uuid primary key default gen_random_uuid()
   - sender_id uuid not null references auth.users(id) on delete cascade
   - recipient_id uuid not null references auth.users(id) on delete cascade
   - kind text not null check (kind in ('encourage','praying','read_reminder','celebrate'))
   - created_at timestamptz not null default now()
   - delivered_at timestamptz null
   index on (sender_id, created_at) and (sender_id, recipient_id, created_at)
   RLS: enabled with NO client policies. Only service role and SECURITY DEFINER functions touch it.

Do not touch any other tables. Show me the SQL you ran.
```

---

## Prompt 2: RPC functions (all `SECURITY DEFINER`, `set search_path = public`)

```
Create these Postgres functions. Each is SECURITY DEFINER with `set search_path = public`, uses auth.uid() internally (never trust a client-passed user id for "me"), and raises a clear exception message on any failed check. Grant EXECUTE to `authenticated` only and revoke from `anon` and `public`.

Helper: `is_blocked_pair(_a uuid, _b uuid) returns boolean`: true if a row exists in the existing `user_blocks` table in either direction between the two users. Inspect `user_blocks` for its actual column names.

Helper: `profile_age(_uid uuid) returns int`: age in whole years from profiles.birth_date (match on the profile row for that auth user), null if birth_date is null.

1. `create_friend_invite() returns text`
   - Requires the caller's profile_age >= 13 (null age => error 'age_required').
   - Max 5 unexpired, unused invites per user (else error 'too_many_invites').
   - Generates a random 8-char code from the alphabet ABCDEFGHJKMNPQRSTUVWXYZ23456789, retries on collision, inserts, returns the code.

2. `redeem_friend_invite(_code text) returns uuid` (returns the inviter's user id)
   - Normalise the code with upper(trim()). Reject expired, used or unknown codes with the single generic error 'invalid_invite'. Do not reveal which.
   - Reject self-redeem ('invalid_invite').
   - Both users must have profile_age >= 13 ('age_required').
   - Child-safety rule: if one user is under 18 and the other is 18 or older, reject with 'not_allowed'. Make the threshold a constant near the top of the function so I can change it.
   - Reject if is_blocked_pair.
   - Insert the friendship as (least(a,b), greatest(a,b)) ON CONFLICT DO NOTHING, mark the invite used, return the inviter id.
   - Limit each user to 200 friends ('friend_limit').

3. `remove_friend(_friend_id uuid) returns void`: deletes the pair row and any friend_mutes between them, in both directions.

4. `upsert_my_activity(_streak int, _read_today boolean, _chapters_week int, _verses_memorized int, _week_start date) returns void`
   - Upserts the caller's friend_activity_snapshot row. Clamp the values: streak 0..10000, chapters 0..1500, verses 0..5000.

5. `get_friends_activity() returns table (friend_id uuid, display_name text, avatar_path text, current_streak int, read_today boolean, chapters_this_week int, verses_memorized int, snapshot_updated_at timestamptz, is_muted boolean)`
   - Returns one row per friend of the caller, EXCLUDING pairs where is_blocked_pair is true.
   - display_name and avatar_path come from `profiles`. Use only the first name or display name field and never email. Fall back to 'Friend'.
   - Each metric is returned only if that friend's friend_sharing_prefs flag (share_streak, share_weekly_chapters, share_verses_memorized) is true. Otherwise return NULL for that column. read_today follows share_streak.
   - A friend with no prefs row shares nothing (all NULL). Always return the friend row itself so the friendship still shows.
   - A stale week: if the snapshot's week_start is older than the current week (date_trunc('week', now())), return chapters_this_week as 0.

6. `set_friend_sharing(_streak boolean, _chapters boolean, _verses boolean, _allow_nudges boolean, _consent_version text) returns void`
   - Upserts the caller's friend_sharing_prefs. If any share_* flag is being turned on and consent_at is null, set consent_at = now() and consent_version = _consent_version. Turning everything off keeps the history but shares nothing. Do not clear consent_at.

7. `register_push_token(_token text, _environment text) returns void`
   - Upserts into push_tokens on token, setting user_id = auth.uid() (this reassigns a device that changed accounts). Validate environment.

8. `unregister_push_token(_token text) returns void`: deletes the caller's row for that token (call on sign-out).

9. `mute_friend(_friend_id uuid, _muted boolean) returns void`: insert or delete the friend_mutes row. The caller must actually be friends with that user.

10. `authorize_nudge(_recipient_id uuid, _kind text) returns void`  -- called ONLY by the edge function using the caller's JWT
   - Validate kind is one of encourage, praying, read_reminder, celebrate.
   - Caller and recipient must be in `friendships`; not is_blocked_pair; the recipient's friend_sharing_prefs.allow_nudges must be true (else 'nudges_off'); the recipient must not have the caller in friend_mutes (return silently as success without inserting, so the sender cannot tell they are muted).
   - Rate limits: max 1 nudge per sender to the same recipient per 24h ('rate_limited'); max 10 nudges per sender per 24h overall ('rate_limited'); max 5 nudges received per recipient per 24h from all senders (silently drop).
   - On success insert a friend_nudges row and return.
   - 'read_reminder' is only permitted when the recipient's snapshot shows read_today = false AND the recipient has share_streak on.

11. `delete_my_friend_data() returns void`: deletes the caller's rows from friendships, friend_invites, friend_mutes, friend_sharing_prefs, friend_activity_snapshot, push_tokens, friend_nudges (as sender or recipient). Everything also cascades on auth user deletion. Make sure the existing account-deletion path (if there is one) calls this or relies on the cascades.

Also add a trigger or extend the existing block flow so that when a row is inserted into `user_blocks`, any friendship between the two users is deleted.

Show me the SQL and list any assumption you made about `profiles` or `user_blocks` columns.
```

---

## Prompt 3: Edge function `send-friend-nudge` + APNs

```
Create a Supabase Edge Function `send-friend-nudge` (Deno, verify_jwt = true).

Request body: { "recipient_id": "<uuid>", "kind": "encourage" | "praying" | "read_reminder" | "celebrate" }

Flow:
1. Create a Supabase client that forwards the caller's Authorization header (the user's JWT) and call RPC `authorize_nudge(_recipient_id, _kind)`. If it raises, return the matching HTTP status (429 for rate_limited, 403 for the others) with a generic JSON error and NO details about the recipient's settings.
2. Use a service-role client to read the sender's display name from `profiles` (first name or display name only, truncated to 20 characters, fallback "A friend") and the recipient's rows in `push_tokens`. If the recipient has no tokens, return 200 {"sent":0}.
3. Build the notification from fixed server-side templates (never accept client text):
   - encourage: title "{name} is cheering you on", body "Keep going: God's Word is worth it today."
   - praying: title "{name} is praying for you", body "You're not walking alone."
   - read_reminder: title "{name} read today", body "Your turn! A few verses is enough."
   - celebrate: title "{name} hit a streak milestone", body "Send some encouragement back."
   Payload: {"aps":{"alert":{"title":..., "body":...},"sound":"default","thread-id":"friends"},"type":"friend_nudge","kind":kind,"sender_id":<id>}
4. Send via APNs HTTP/2 with token-based auth:
   - host api.push.apple.com for environment 'production' tokens, api.sandbox.push.apple.com for 'sandbox' tokens
   - header apns-topic = secret APNS_BUNDLE_ID (com.reforged.app), apns-push-type alert, apns-priority 5, apns-expiration now + 24h
   - provider JWT signed ES256 with secrets APNS_KEY_P8 (the .p8 contents), APNS_KEY_ID, APNS_TEAM_ID; cache the JWT for up to 50 minutes (APNs rejects tokens older than 60 minutes)
5. On APNs status 410 or 400 BadDeviceToken / Unregistered, delete that token row from push_tokens.
6. Mark friend_nudges.delivered_at for the row created in step 1 if at least one send succeeded.
7. Return {"sent": <count>}.

Tell me exactly which secrets to add (APNS_KEY_P8, APNS_KEY_ID, APNS_TEAM_ID, APNS_BUNDLE_ID) and where to paste them. I will add the values myself. Do not hardcode or log any secret or device token. Log only status codes.
```

---

## Prompt 4: Verification (ask Lovable to run or describe these checks)

```
Please verify and report results:
1. Using two test users A and B (both with birth_date making them 13+ and both under 18, or both 18+): A calls create_friend_invite, B calls redeem_friend_invite, then both see each other in get_friends_activity with all metrics NULL.
2. B calls set_friend_sharing(true,false,false,true,'v1') and A's get_friends_activity now shows B's current_streak and read_today only.
3. A direct `select * from friend_activity_snapshot` as user A returns only A's own row, and `select * from friendships` returns only pairs A belongs to.
4. After B inserts a user_blocks row for A, the friendship is gone and get_friends_activity no longer returns either side.
5. An under-18 and an 18+ user cannot redeem each other's invite (error 'not_allowed').
6. The second nudge from A to B within 24h returns 'rate_limited'.
7. A nudge to a user with allow_nudges = false returns 'nudges_off'.
Also confirm no new table is readable by the `anon` role.
```

---

## After Lovable finishes: what I will build in the app
1. **Models and `FriendsService`** (Supabase REST and RPC, same pattern as `GroupsService`).
2. **Consent and sharing settings** screen: toggles, plain-language explanation, links to the Privacy Policy, default off.
3. **Invite flow**: code, QR and share link `reforged://join-friend?code=…`, with deep-link handling next to the existing group join.
4. **Friends list** with streaks, mute, remove, block and report.
5. **Preset nudges** (4 kinds) and a per-type notification toggle that defaults off.
6. **Push token registration** on sign-in and unregistration on sign-out, plus enabling the Push capability / `aps-environment` entitlement.
7. Activity sync (`upsert_my_activity`) from `ReadingStreakManager`, so the streak keeps a single source of truth.
8. Privacy Policy, Terms and `PrivacyInfo.xcprivacy` updates.

## Things only you can do
- Create an APNs auth key (.p8) in the Apple Developer portal (Keys, Apple Push Notifications service) and note the Key ID and Team ID.
- Paste those secrets into Lovable/Supabase when Prompt 3 asks.
- Enable the Push Notifications capability on the app ID.
- Have a privacy lawyer review the consent text and the under-18 / 18+ separation rule before launch.

---

## Prompt 5: `set_my_birth_date` (needed before Friends works for regular users)

`upgrade_to_leader` requires 18+, grants leader_role, and overwrites birth_date, so it can't be used for regular 13+ users. This adds a dedicated function.

```
Create a Postgres function `public.set_my_birth_date(_birth_date date) returns void`, SECURITY DEFINER, `set search_path = public`.

Rules, in order, each raising a short exception message exactly as written:
1. If auth.uid() is null: 'not_authenticated'.
2. If _birth_date is null: 'birth_date_required'.
3. If _birth_date is in the future or more than 120 years ago: 'birth_date_invalid'.
4. If the age in whole years is under 13: 'under_13'.
5. Look up the caller's profile row. If birth_date is already set:
   - if it equals _birth_date, return silently (idempotent success);
   - otherwise raise 'already_set'. A birth date can NOT be changed once set.
6. Otherwise set profiles.birth_date = _birth_date and updated_at = now() for the caller's own profile row. If the caller has no profile row yet, insert one the same way upgrade_to_leader does. It must NOT touch leader_role or any other column.

To get past the existing `protect_profile_leader_role` trigger, set the same transaction-local flag upgrade_to_leader uses (`app.allow_leader_role_change`), but only around this birth_date update. Confirm the trigger still blocks a client from setting leader_role directly and from editing birth_date directly.

Grants: revoke execute from public and anon, grant execute to authenticated.

Second, a hardening change to the existing `upgrade_to_leader`: stop it from overwriting a birth_date that is already set. If birth_date is already set and differs from the supplied one, raise 'already_set' instead of overwriting. If it is null or equal, behave exactly as today. Reason: friendships block adult/under-18 pairs using birth_date, so a minor must not be able to rewrite it to look 18+.

Don't change anything else. Show me the SQL and confirm the trigger behaviour.
```

Test accounts that already went through the leader check have a birth date and are now leaders. That's fine for testing, but note both would count as adults for the adult/minor rule.

---

## Prompt 6: Opt-in "find friends from contacts" (email, 18+, requests)

Design: members opt in to being findable by their verified sign-in email. The phone hashes the emails in the user's contacts (SHA-256) and sends only the hashes. The server compares them against a keyed hash of opted-in members' emails, returns only opted-in matches, and never stores the uploaded list. A match only lets the caller send a friend request. Nothing connects until the other person accepts.

```
Add the following to the Supabase database. All new tables have RLS enabled with NO client policies (RPC access only). Functions are SECURITY DEFINER with `set search_path = public`, use auth.uid() for "me", and are granted to `authenticated` only (revoke from anon and public). Reuse is_blocked_pair() and profile_age() from earlier. Put the age threshold for discovery in a constant at the top of the functions (18).

Secret: create a random 32-byte pepper and keep it out of the tables (Supabase Vault preferred, otherwise a database secret). Never return it, and tell me where you put it.

Tables:
1. `friend_discoverability`
   - user_id uuid primary key references auth.users(id) on delete cascade
   - find_by_email boolean not null default false
   - email_lookup_hash text null  -- HMAC-SHA256(pepper, sha256_hex(lower(trim(email)))) as hex
   - consent_at timestamptz null
   - updated_at timestamptz not null default now()
   - index on email_lookup_hash

2. `friend_discovery_calls` (rate limiting only; NEVER store hashes or counts of matches)
   - id uuid primary key default gen_random_uuid()
   - user_id uuid not null references auth.users(id) on delete cascade
   - called_at timestamptz not null default now()
   - index on (user_id, called_at)

3. `friend_requests`
   - id uuid primary key default gen_random_uuid()
   - from_user uuid not null references auth.users(id) on delete cascade
   - to_user uuid not null references auth.users(id) on delete cascade
   - created_at timestamptz not null default now()
   - unique (from_user, to_user), check (from_user <> to_user)

Functions:

1. `set_discoverable(_enabled boolean) returns void`
   - Caller needs profile_age >= 18 ('age_required' if null, 'not_allowed' if under 18).
   - If enabling: read the caller's email and email_confirmed_at from auth.users. Reject with 'email_unverified' if not confirmed, and 'relay_email' if the domain is privaterelay.appleid.com. Compute email_lookup_hash with the pepper (HMAC-SHA256 over the lowercase hex SHA-256 of the lowercased, trimmed email). Upsert with find_by_email = true, consent_at = coalesce(consent_at, now()).
   - If disabling: set find_by_email = false and email_lookup_hash = NULL, and delete the caller's pending friend_requests rows as recipient.

2. `get_my_discoverability() returns boolean`: returns find_by_email for the caller (false if no row). If enabled, also recompute and refresh email_lookup_hash in case the user's email changed.

3. `find_friends_by_hashes(_hashes text[]) returns table (user_id uuid, display_name text)`
   - Caller must have find_by_email = true (you must be findable to look) and profile_age >= 18, else 'not_allowed'.
   - Reject if array length > 500 ('too_many'). Ignore entries that are not 64-char lowercase hex.
   - Rate limit: at most 10 calls per caller per 24h using friend_discovery_calls ('rate_limited'). Insert a row per call.
   - For each valid input, compute the pepper HMAC and match against friend_discoverability.email_lookup_hash where find_by_email = true. Never match the caller. Process in memory only; do not log, store or return the input.
   - EXCLUDE: existing friends, blocked pairs (is_blocked_pair), anyone under 18, and anyone with a pending friend_request in either direction with the caller.
   - Return at most 100 rows. display_name = first non-empty of profiles.display_name, profiles.first_name, 'Friend'; trimmed to 30 characters. Return no email, hash or other field.

4. `send_friend_request(_to uuid) returns void`
   - Caller age >= 18; target must be find_by_email = true and age >= 18; not blocked; not already friends; the same 200-friend limit. All failures use the single error 'not_available' so existence isn't revealed.
   - Max 20 pending outgoing requests, and max 20 requests sent per 24h ('rate_limited').
   - Insert (ON CONFLICT DO NOTHING).

5. `get_friend_requests() returns table (id uuid, from_user uuid, display_name text, created_at timestamptz)`: INCOMING requests for the caller, newest first, excluding blocked pairs and anything older than 30 days. Same display_name rule.

6. `respond_friend_request(_id uuid, _accept boolean) returns void`
   - The caller must be the to_user. Always delete the request row.
   - If accepting: re-check blocked pair, both ages >= 18, and friend limit, then insert the friendship as (least, greatest) ON CONFLICT DO NOTHING. If declining: just delete (the sender is NOT told).

Also:
- Extend `delete_my_friend_data()` to delete from friend_discoverability, friend_discovery_calls and friend_requests (either side).
- Extend the existing user_blocks trigger so blocking also deletes any pending friend_requests between the pair.
- Add the new tables to anything that purges on account deletion (cascades are enough).

Don't change anything else. Show me the SQL, say where the pepper lives, and confirm: (a) a user with find_by_email = false cannot call find_friends_by_hashes, (b) no table stores uploaded hashes, (c) results never include existing friends, blocked users, minors or the caller.
```

Known limits to accept for v1: Apple "Hide My Email" users can't be matched; phone-number matching is intentionally not included until numbers can be verified by SMS; an 18+ opted-in member can still probe up to 5,000 emails a day, which the opt-in, the 18+ rule and the rate limit keep small.

---

## Prompt 7: Invite links that open the app (iOS only for now)

App side is done: invite messages now use `https://reforgedapp.org/friend/CODE`, and the app has the associated-domains entitlement `applinks:reforgedapp.org` and handles that URL. This prompt makes reforgedapp.org serve the files and the landing page that complete it. Replace `APP_STORE_ID` and the URL with the real values before sending (the number in `apps.apple.com/app/id123456789`).

```
reforgedapp.org must support iOS universal links for friend invites. Do the following in this project (the one that serves reforgedapp.org, including the existing /leader pages).

1. Apple App Site Association file
   - Serve it at exactly `/.well-known/apple-app-site-association` (no file extension), over HTTPS, with `Content-Type: application/json`, status 200, and NO redirects (Apple won't follow them). Put it in the static/public folder so it isn't handled by the SPA router, and make sure the hosting config does not rewrite it to index.html.
   - Content:
     {
       "applinks": {
         "details": [
           {
             "appIDs": ["53998XCUML.com.reforged.app"],
             "components": [ { "/": "/friend/*", "comment": "Friend invites" } ]
           }
         ]
       }
     }
   - Only /friend/* for now. Do not add /join/* or any other path.

2. Landing page route `/friend/:code`
   - Detect the platform. iPhone and iPad (including iPadOS Safari that reports as Mac with touch) count as iOS.
   - On iOS, show: heading "A friend invited you to Reforged", one line "Read and memorize Scripture together.", the invite code in large monospace type with a Copy button, and three steps: 1. Get Reforged, 2. Open the app and go to the Friends tab, 3. Enter the code above (or tap Open in Reforged if it's already installed). Buttons: "Open in Reforged" (a plain link to `reforged://friend?code=:code`, only on tap, never auto-run) and "Download on the App Store" linking to `https://apps.apple.com/app/idAPP_STORE_ID`.
   - On Android and other mobile platforms, show: "Reforged is available on iPhone and iPad for now. Android is coming later." with no buttons and no email form.
   - On desktop, show: "Open this link on your iPhone or iPad to join Reforged." plus the same note about Android.
   - Normalise the code: uppercase, only A-Z and 2-9, max 8 characters. If it's empty or invalid, show the generic page without a code.
   - Add `<meta name="apple-itunes-app" content="app-id=APP_STORE_ID, app-argument=https://reforgedapp.org/friend/:code">` on this route only (Smart App Banner).
   - Add `<meta name="robots" content="noindex, nofollow">` and `<meta name="referrer" content="no-referrer">` on this route.
   - Match the existing site's styling (gold accent, clean, mobile first, light and dark mode).

3. Privacy
   - Do not add analytics, tracking pixels, cookies or any network request that includes the code. The code must never be sent to a third party or logged. The page is static and needs no backend call.
   - Do not collect emails or any other personal data on this page.

Don't change any other route. After deploying, tell me the exact URLs so I can verify the AASA file, and confirm the response headers of /.well-known/apple-app-site-association (status 200, content-type application/json, no redirect).
```

### Your steps (Apple side)
1. Apple Developer, Identifiers, `com.reforged.app`, tick **Associated Domains**, Save. (Needed before a device or TestFlight build is signed; the simulator doesn't need it.)
2. After Lovable deploys, verify the file:
   `curl -sI https://reforgedapp.org/.well-known/apple-app-site-association` should show `200` and `content-type: application/json` with no redirect.
3. Apple caches this file via its CDN; check `https://app-site-association.cdn-apple.com/a/v1/reforgedapp.org`. Changes can take hours to appear. On a real device, delete and reinstall the app after the file is live so iOS re-fetches it.
4. Universal links don't trigger when you paste the link into Safari's address bar or tap it from the same domain. Test by tapping it in Messages or Notes.

---

## Prompt 8: Privacy Policy update (Friends, contacts, push, age)

Send this to the Lovable project that serves reforgedapp.org/privacy. It was checked against the live page on October 9, 2026. The existing contact email on that page is boaz.briddick@gmail.com; the prompt keeps whatever contact the page already uses. It is written to match what the app actually does today, so re-check it if behavior changes (for example if you add log purging, phone matching, or a leaderboard). Have a privacy lawyer review the final text before you ship.

```
Update the Privacy Policy page at reforgedapp.org/privacy. It currently has sections 1-12 (Information We Collect, Cookies, How We Use Information, Data Storage and Security, Data Sharing, Third-Party Services, Data Retention, Your Rights and Choices, Account and Data Deletion, Children's Privacy, Changes, Contact). Keep that structure and styling, keep the "Effective Date" line but set it to October 9, 2026, keep the existing contact email wherever the policy tells people to contact us (do not change it), and add or revise the content below in plain, friendly language (no legalese walls). Add a short "What changed" note at the top. Do not invent facts beyond what is written here. If the existing policy contradicts anything below, the text below wins; list any contradictions you found so I can review them.

NEW SECTION: "Friends"
Explain that Reforged has an optional Friends feature for people 13 and older, and list exactly what we handle:
- Friend connections: which two accounts are friends, and when they connected.
- Invites: invite codes you create (they expire after 7 days), who created them, and who used them.
- Friend requests: requests between adults who chose to be findable (pending requests expire after 30 days).
- Sharing choices: what you let friends see (streak, whether you read today, chapters read this week, verses memorized) and whether you allow encouragement. Everything is OFF until you turn it on. We also record when you gave consent and which version of the consent text you saw.
- Activity summary: ONLY if you turn sharing on, we store a small summary of your totals (current streak, read today, chapters read this week, number of verses memorized, and the time it was updated). Friends see only the items you chose to share. Friends never see what you read, your notes, prayers, journal, or which verses you are memorizing.
- Your first name or display name, which friends and people who find you can see.
- Encouragement: a log of who sent which preset encouragement type to whom and when (we do not store free-text messages because there is no free text). We use this to enforce limits and prevent abuse.
- Push notifications: if you allow encouragement, we store your device's push notification token so friends' encouragement can reach you. We send it to Apple's Push Notification service to deliver the notification.
- Muting, blocking and removing: your choices are stored so they are respected.

NEW SECTION: "Your religious information" (sensitive data)
State that sharing your Bible reading or memorization with friends may reveal information about your religious beliefs, which some laws treat as sensitive. We only share it with friends if you explicitly turn it on, separately for each item, it is never on by default, you can turn it off at any time, and turning it off stops sharing. We do not use this data for advertising, profiling or any purpose other than showing it to the friends you chose. We never sell it.

NEW SECTION: "Contacts and finding friends"
- Invite from Contacts: uses the iPhone's built-in contact picker. Reforged only receives the one contact you tap, to open a message to them with your invite link. We do not get access to the rest of your contacts, and we do not store the contact you chose.
- Find friends on Reforged (adults 18+ only, optional): if you turn on "Let people with my email find me", we store a scrambled (keyed, one-way) fingerprint of your verified sign-in email so people who have your email in their contacts can find you. They see only your first name and can send a friend request; nothing is shared until you accept. When you use "Find friends", Reforged asks for permission to read Contacts, reads only email addresses on your device, scrambles them (SHA-256) on your device, and sends only those scrambled values to our server to check for matches. The server compares them to opted-in members, returns only matches, and discards the list. We do not store or keep your contacts or the scrambled values you send. We keep a log of the time of each lookup, to limit abuse. You must turn on being findable yourself in order to look for others. You can turn it off at any time, which deletes your fingerprint and any pending requests to you. Emails hidden with Sign in with Apple's "Hide My Email" cannot be matched.

NEW SECTION: "Age and children"
- Reforged's Friends features are for people 13 and older. We ask for your date of birth to enforce this. It is stored on your account, can't be changed after you set it, and is also used to keep people under 18 from connecting with adults and to limit finding friends by contacts to adults. We do not knowingly collect personal information from children under 13; if we learn we have, we delete it.
- There is no open chat and no public profiles or public search. Friends connect only by invite code, invite link, or an accepted request. You can mute, remove or block anyone, and report concerns at the existing contact email on the page.

CORRECT THESE EXISTING STATEMENTS (they are now false):
- Section 4 says data is stored locally and "does not sync across devices". Reforged now has optional accounts (sign in with email and password, or Sign in with Apple) and syncs study data across the user's devices through Apple iCloud/CloudKit. Rewrite section 4 to say so: personal study content (journal, notes, memory progress, preferences) is stored on the device and synced through the user's own iCloud; account, profile, community and Friends data is stored on our servers hosted on Supabase (managed through Lovable).
- Section 1 lists only on-device data. Add an "Account data" group: email address, sign-in method, display name and first name, avatar, XP/level/streak mirrored to the account profile, and date of birth for age checks.
- Section 10 says the app "does not specify a minimum age". Replace with: accounts, Groups and Friends are for people 13 and older; we ask for a date of birth to enforce this; we do not knowingly collect personal information from children under 13 and delete it if we learn we have.
- Section 9 (Account and Data Deletion): keep the Account Deletion page instructions and add that in the app, Friends > "Delete my Friends data" removes Friends data immediately.
- Section 2 (Cookies): keep as is.

UPDATE EXISTING SECTIONS:
- "Information we collect": add date of birth (for age checks), push notification token (if you allow encouragement), and the Friends data above.
- "How we use information": add enforcing age rules and safety, delivering friend encouragement, and preventing abuse.
- "Third-Party Services" (section 6): add Supabase (hosting, managed through Lovable) for accounts and Friends, and Apple's Push Notification service and Apple iCloud/CloudKit. Keep the existing provider categories. Do not add other providers.
- "Sharing": we do not sell personal information and we do not share it for advertising. Friends see only what you chose to share. We may disclose information if required by law or to protect safety.
- "Retention and deletion": Friends data is kept while your account exists, except that invites expire after 7 days and unanswered friend requests after 30 days. In the app, Friends > "Delete my Friends data" removes your friendships, sharing choices, activity summary, invites, requests, push tokens and encouragement log. Deleting your account deletes all of it. You can also email the existing contact email on the page.
- "Your rights": for people in the EU/UK, state our legal bases: providing the service you ask for, our legitimate interest in safety and preventing abuse, and your explicit consent for sharing religious information and for being findable; the right to withdraw consent at any time, access, correct, delete, export, object and complain to your data protection authority. For California and other US state residents: the right to know, delete, correct and opt out of sale or sharing, and that we do not sell or share personal information; and we use sensitive information only to provide the service you request. Mention that data may be processed in the United States.

When done, also give me the final text of the whole policy as plain text so I can paste it into the app, which currently shows a separate, older copy.
```

### Also update (not Lovable)
- **App Store Connect > App Privacy** (my reading of Apple's definitions; confirm in the form): add or confirm these, all "linked to the user", not used for tracking, purpose "App Functionality":
  - *Contact Info*: Email Address and Name (account, findability lookup).
  - *Identifiers*: User ID and Device ID (push token).
  - *Usage Data* > Other Usage Data: streak, chapters, verses count shared with friends.
  - *Sensitive Info*: declare it for the shared reading and memorization activity out of caution, since it can reveal religious belief and your consent screen already treats it as sensitive. Ask your lawyer if you'd rather not.
  - *Other Data Types*: date of birth.
  - Contacts hashes are processed in real time and not retained, so by Apple's definition I read them as not "collected"; the Contacts permission text in the app already explains this.
- **In-app Privacy Policy** (`AboutSection.swift`): it is a separate, older copy (last updated February 2025) and disagrees with the website. Better than pasting text: make "Privacy Policy" open https://reforgedapp.org/privacy so there is one version to maintain. I can make that change in the app; say the word.
- **Not covered by the live policy and not checked by me:** please review with your lawyer whether the policy should also mention the AI features that send text to Google Gemini, Screen Time / Focus blocking, the Tip Jar (StoreKit purchases), the Reforged Shop (Printful orders and shipping addresses), Groups and prayer requests, and the contact email being a personal Gmail address (a support@reforgedapp.org address would look more professional and keep personal contact details off a public policy).
- **Retention gap:** the policy says the encouragement log is kept while the account exists. A scheduled purge (for example, delete nudge rows older than 30 days) would let you shorten that promise; add it if you want.

---

## Prompt 9: Memorize Together (shared verses, quizzes, XP)

Pairs only. Two friends memorize the same verse, see each other's level, and quiz each other. No free text. The server stores only the verse REFERENCE and translation code, never Scripture text (translations are licensed; each phone fetches text from its own licensed source and builds quiz blanks locally).

```
Add the following to the Supabase database. All new tables have RLS enabled with NO client policies (RPC access only). All functions are SECURITY DEFINER with `set search_path = public`, use auth.uid() for "me", raise short exception messages exactly as written, and are granted to `authenticated` only (revoke from anon and public). Reuse is_blocked_pair() and the existing friendships table. "Friends" means a row exists in friendships for the pair (canonical user_a < user_b).

TABLES

1. `shared_verses`
   - id uuid primary key default gen_random_uuid()
   - user_a uuid not null references auth.users(id) on delete cascade
   - user_b uuid not null references auth.users(id) on delete cascade   -- canonical order, user_a < user_b
   - reference text not null          -- e.g. "Romans 8:1" or "John 3:16-17"
   - translation text not null        -- code like ESV, KJV, NKJV, CSB, NASB, NLT, NET, RVR1960
   - created_by uuid not null references auth.users(id) on delete cascade
   - status text not null default 'pending' check (status in ('pending','active'))
   - created_at timestamptz not null default now()
   - accepted_at timestamptz null
   - check (user_a < user_b)
   - check (char_length(reference) between 3 and 40 and reference ~ '^[1-3]? ?[A-Za-z][A-Za-z .]{0,28} [0-9]{1,3}(:[0-9]{1,3}([-–][0-9]{1,3})?)?$')
   - check (translation ~ '^[A-Za-z0-9]{2,10}$')
   - unique (user_a, user_b, reference, translation)

2. `shared_verse_progress`
   - shared_verse_id uuid references shared_verses(id) on delete cascade
   - user_id uuid references auth.users(id) on delete cascade
   - level int not null default 1 check (level between 1 and 5)       -- the app's own 1..5 level
   - review_count int not null default 0 check (review_count between 0 and 100000)
   - last_reviewed_at timestamptz null
   - updated_at timestamptz not null default now()
   - primary key (shared_verse_id, user_id)

3. `shared_verse_days` (one row per user per local day they reviewed that verse; used for the pair streak)
   - shared_verse_id uuid references shared_verses(id) on delete cascade
   - user_id uuid references auth.users(id) on delete cascade
   - day date not null
   - primary key (shared_verse_id, user_id, day)

4. `verse_quizzes`
   - id uuid primary key default gen_random_uuid()
   - shared_verse_id uuid not null references shared_verses(id) on delete cascade
   - sender_id uuid not null references auth.users(id) on delete cascade
   - recipient_id uuid not null references auth.users(id) on delete cascade
   - difficulty text not null check (difficulty in ('easy','medium','hard'))   -- 3, 6 or 10 blanks
   - status text not null default 'sent' check (status in ('sent','completed'))
   - blanks_total int null, blanks_correct int null, score int null          -- score 0..100
   - sender_reaction text null check (sender_reaction in ('nailed_it','so_close','keep_going','amen'))
   - recipient_xp_claimed boolean not null default false
   - sender_xp_claimed boolean not null default false
   - recipient_xp int not null default 0, sender_xp int not null default 0
   - created_at timestamptz not null default now()
   - completed_at timestamptz null
   - index on (recipient_id, status), (sender_id, created_at)

FUNCTIONS

1. `propose_shared_verse(_friend_id uuid, _reference text, _translation text) returns uuid`
   - Must be friends and not blocked ('not_allowed'). Validate reference and translation with the same rules as the table checks ('invalid_verse').
   - If a row already exists for the pair + reference + translation: return its id (idempotent).
   - Limits: at most 20 shared verses (pending + active) per pair ('verse_limit'); at most 10 pending proposals sent by the caller ('rate_limited'); at most 20 proposals per caller per 24h ('rate_limited').
   - Insert with canonical ordering, status 'pending', created_by = caller. Return the id.

2. `respond_shared_verse(_id uuid, _accept boolean) returns void`
   - Caller must be the recipient (the member who is NOT created_by) of a pending row ('not_allowed' otherwise). Re-check friendship and blocked pair.
   - Accept: set status 'active', accepted_at = now(), and insert initial shared_verse_progress rows (level 1, review_count 0) for both users. Decline: delete the row (the sender is NOT told).

3. `end_shared_verse(_id uuid) returns void`: either member may delete the row; progress, days and quizzes cascade.

4. `report_verse_progress(_shared_verse_id uuid, _level int, _review_count int, _reviewed boolean, _today date) returns void`
   - Caller must be a member of an ACTIVE row. Clamp level 1..5 and review_count 0..100000. _today must be within 1 day of the server's current date (else 'invalid_date').
   - Upsert the caller's progress row. If _reviewed is true, set last_reviewed_at = now() and insert (verse, caller, _today) into shared_verse_days ON CONFLICT DO NOTHING.

5. `get_shared_verses(_today date) returns table (id uuid, friend_id uuid, friend_name text, reference text, translation text, status text, created_by_me boolean, my_level int, my_review_count int, my_last_reviewed_at timestamptz, friend_level int, friend_review_count int, friend_last_reviewed_at timestamptz, friend_reviewed_today boolean, i_reviewed_today boolean, pair_streak int, mastered_together boolean, created_at timestamptz)`
   - All rows (pending and active) where the caller is a member, excluding blocked pairs and pairs that are no longer friends.
   - friend_name = first non-empty of profiles.display_name, profiles.first_name, 'Friend' (max 30 chars). Return no other personal data.
   - For PENDING rows return null for all progress fields.
   - pair_streak = number of consecutive days ending at _today (or _today - 1 if today is not complete yet) on which BOTH members have a shared_verse_days row for that verse.
   - mastered_together = both members' level = 5.
   - Sharing a verse is the consent: accepting makes that one verse's progress visible to the partner. It does NOT depend on the friend_sharing_prefs flags.

6. `send_verse_quiz(_shared_verse_id uuid, _difficulty text) returns uuid`
   - Caller must be a member of an ACTIVE row; recipient is the other member. Not blocked.
   - At most one quiz in status 'sent' per sender per shared verse ('quiz_pending'); at most 5 quizzes sent per sender per 24h ('rate_limited').
   - Insert and return the id. Quizzes older than 7 days are treated as expired everywhere (ignore them in the other functions).

7. `complete_verse_quiz(_quiz_id uuid, _blanks_total int, _blanks_correct int) returns int`
   - Caller must be the recipient, quiz status 'sent' and not expired ('not_allowed').
   - Validate: _blanks_total must equal 3, 6 or 10 matching the difficulty; 0 <= _blanks_correct <= _blanks_total ('invalid_result').
   - score = round(100 * correct / total). Set status 'completed', completed_at = now(). Compute XP and store it: recipient_xp = 5 + round(10 * score / 100) (range 5..15); sender_xp = 5. Return score.

8. `react_to_quiz(_quiz_id uuid, _reaction text) returns void`: caller must be the sender of a COMPLETED quiz; reaction must be one of nailed_it, so_close, keep_going, amen. Set sender_reaction (can be changed).

9. `claim_quiz_xp(_quiz_id uuid) returns int`
   - Caller must be the sender or recipient of a COMPLETED quiz and not have claimed already (second call returns 0). Mark their claimed flag true in the same statement so XP is awarded exactly once.
   - Anti-farming: a user may receive paid XP from at most 3 quizzes per 24h in total, and from at most one quiz per (shared verse, direction) per 24h. If a cap applies, mark claimed and return 0.
   - Otherwise return the stored recipient_xp or sender_xp. XP itself is applied by the app on the device; the server only validates and meters it.

10. `get_my_quizzes() returns table (id uuid, shared_verse_id uuid, role text, friend_name text, reference text, translation text, difficulty text, status text, score int, blanks_total int, blanks_correct int, reaction text, xp_claimable boolean, created_at timestamptz, completed_at timestamptz)`
    - role = 'recipient' (quizzes sent to me that I still need to take, status 'sent', not expired) or 'sender' (my quizzes that are completed, from the last 30 days). xp_claimable is true when I haven't claimed and XP > 0. Newest first, max 50. Exclude blocked pairs.

NOTIFICATIONS
Extend `authorize_nudge` and the `send-friend-nudge` edge function to support these extra kinds, with an optional `shared_verse_id` in the request: 'verse_request' (someone proposed a verse), 'verse_quiz' (a quiz is waiting), 'verse_nudge' (a reminder to review a shared verse), 'verse_celebrate' (you both mastered it). Rules: sender and recipient must be members of that shared verse; the reference is read from the shared_verses row on the server, never from the client; same allow_nudges, mute, block and rate-limit rules as before (max 1 per sender to the same recipient per 24h per kind, 10 per sender per 24h, 5 received per day). Templates (server side):
  - verse_request: "{name} wants to memorize {reference} with you"
  - verse_quiz: "{name} sent you a quiz on {reference}"
  - verse_nudge: "Your turn on {reference}" / body "{name} is keeping at it. Join them today."
  - verse_celebrate: "You and {name} mastered {reference}!"
The recipient must also be a member of an active shared verse for verse_nudge/verse_quiz/verse_celebrate, and a pending one for verse_request.

CLEANUP RULES
- Removing a friend (remove_friend) and blocking (user_blocks trigger) must delete all shared_verses between the pair (progress, days and quizzes cascade).
- Extend delete_my_friend_data() to delete every shared_verses row the caller is a member of.
- Disabling allow_nudges must not break any of the above; it only stops the push notifications.

Don't change anything else. Show me the SQL, and confirm: (a) no Scripture text is stored anywhere, (b) a user cannot read another pair's rows, (c) a decline is silent to the sender, (d) claim_quiz_xp cannot pay twice for one quiz and respects the caps, (e) blocking or unfriending removes the shared verses.
```

### What the app will do with this
- **Memory deck.** Accepting a proposal adds the verse to your normal Memory deck, tagged as shared. Each time you review it, the app reports your level and review count (`report_verse_progress`). Nothing else leaves the device.
- **Quizzes.** The sender picks easy, medium or hard. The recipient's phone builds fill-in-the-blank from their own licensed Bible text and sends back only "N of M correct". Both people can then claim XP through `claim_quiz_xp`, and the sender can react with a preset.
- **XP.** The server meters it (caps above) and the app awards it locally. XP lives on the device, so a modified client could report a perfect score. That is accepted because XP is cosmetic and the caps are small.
- **Privacy policy.** Prompt 8 should get one addition: "Memorize Together stores the verse reference, translation, your level and review counts for each verse you share, and quiz results, visible only to the friend you share it with." I haven't written that update yet.

---

## Prompt 10: Quiz result and reaction notifications (fixes a gap in Prompt 9)

Prompt 9 never notified anyone when a quiz was finished or reacted to, and the person who took a quiz had no way to see the reaction. This adds both.

```
Make these changes. Don't touch anything else.

1. get_my_quizzes()
   - Also return COMPLETED quizzes where the caller is the RECIPIENT (role = 'recipient', status = 'completed') from the last 14 days, including score, blanks_total, blanks_correct and the sender's reaction. Keep every existing rule: quizzes I still need to take stay role 'recipient' / status 'sent'; completed quizzes I SENT stay role 'sender'. Exclude blocked pairs. Keep max 50 rows, newest first.

2. Two new push notification kinds in authorize_nudge and the send-friend-nudge edge function, with a new optional request field `quiz_id` (uuid) in addition to the existing `shared_verse_id`:
   - 'quiz_result': sent by the quiz RECIPIENT to the quiz SENDER after completing it. Caller must be the recipient of a COMPLETED quiz; recipient of the notification is its sender. Template: title "{name} finished your quiz", body "{score}% on {reference}".
   - 'quiz_reaction': sent by the quiz SENDER to the quiz RECIPIENT after reacting. Caller must be the sender of a COMPLETED quiz with a non-null sender_reaction. Template: title "{name} sent you {reaction label}", body "On your {reference} quiz". Reaction labels (server side): nailed_it = "🙌 Nailed it", so_close = "👏 So close", keep_going = "💪 Keep going", amen = "🙏 Amen".
   - The score, reference and reaction must be read from the database row, never from the request.
   - Same checks as other nudges: friends, not blocked, recipient's allow_nudges, mutes, and the 5-per-day received cap. Extra rule: at most one 'quiz_result' per quiz, and at most one 'quiz_reaction' per quiz per 5 minutes (so changing a reaction doesn't spam).
   - Both kinds are exempt from the 'one nudge per sender per recipient per 24h' rule (they're responses to an action), but still count toward the 10-per-sender-per-day limit.

Show me the SQL and confirm: (a) a recipient can see the reaction on a quiz they completed, (b) a user cannot trigger 'quiz_reaction' for a quiz they didn't send or that has no reaction, (c) nothing client-supplied appears in the notification text.
```

---

## Prompt 11: Read Together (shared plan or passage, daily ticks)

Pairs only. Two friends read the same built-in plan or the same passage, each at their own pace, and each ticks off their own reading. The server stores only a plan ID (for built-in plans, an opaque slug), or a passage reference, plus counts and dates. No titles, no free text. Each phone looks up the plan name and passages in its own app.

```
Add the following to the Supabase database. All new tables have RLS enabled with NO client policies (RPC access only). All functions are SECURITY DEFINER with `set search_path = public`, use auth.uid() for "me", raise short exception messages exactly as written, and are granted to `authenticated` only (revoke from anon and public). Reuse is_blocked_pair() and the friendships table. "Friends" means a row exists in friendships for the pair (canonical user_a < user_b).

TABLES

1. `shared_readings`
   - id uuid primary key default gen_random_uuid()
   - user_a uuid not null references auth.users(id) on delete cascade
   - user_b uuid not null references auth.users(id) on delete cascade     -- canonical order, user_a < user_b
   - kind text not null check (kind in ('plan','passage'))
   - plan_id text null            -- built-in plan slug, only for kind = 'plan'
   - reference text null          -- e.g. "Psalm 23", "John 1-3", "Romans 8:1-17", only for kind = 'passage'
   - total_days int not null check (total_days between 1 and 400)         -- passage = 1
   - created_by uuid not null references auth.users(id) on delete cascade
   - status text not null default 'pending' check (status in ('pending','active'))
   - created_at timestamptz not null default now()
   - accepted_at timestamptz null
   - check (user_a < user_b)
   - check ((kind = 'plan' and plan_id ~ '^[a-z0-9][a-z0-9-]{1,63}$' and reference is null)
         or (kind = 'passage' and plan_id is null and total_days = 1 and char_length(reference) between 3 and 40
             and reference ~ '^[1-3]? ?[A-Za-z][A-Za-z .]{0,28} [0-9]{1,3}([:-][0-9]{1,3})?(-[0-9]{1,3}(:[0-9]{1,3})?)?$'))
   - unique (user_a, user_b, kind, plan_id, reference)  -- treat nulls as equal (use a unique index with coalesce)

2. `shared_reading_progress`
   - shared_reading_id uuid references shared_readings(id) on delete cascade
   - user_id uuid references auth.users(id) on delete cascade
   - days_completed int not null default 0       -- clamped to 0..total_days
   - finished_at timestamptz null                -- set once days_completed >= total_days
   - last_read_at timestamptz null
   - updated_at timestamptz not null default now()
   - primary key (shared_reading_id, user_id)

3. `shared_reading_days` (one row per user per local day they ticked reading for that shared reading; used for the together streak)
   - shared_reading_id uuid references shared_readings(id) on delete cascade
   - user_id uuid references auth.users(id) on delete cascade
   - day date not null
   - primary key (shared_reading_id, user_id, day)

FUNCTIONS

1. `propose_shared_reading(_friend_id uuid, _kind text, _plan_id text, _reference text, _total_days int) returns uuid`
   - Must be friends and not blocked ('not_allowed'). Validate with the same rules as the table checks ('invalid_reading'). For kind 'passage' force total_days = 1.
   - If the same pair + kind + plan/reference already exists: return its id (idempotent).
   - Limits: at most 5 shared readings (pending + active) per pair ('reading_limit'); at most 10 pending proposals sent by the caller and 20 proposals per caller per 24h ('rate_limited').
   - Insert with canonical ordering, status 'pending', created_by = caller. Return the id.

2. `respond_shared_reading(_id uuid, _accept boolean) returns void`
   - Caller must be the member who is NOT created_by, on a pending row ('not_allowed' otherwise). Re-check friendship and blocked pair.
   - Accept: status 'active', accepted_at = now(), insert progress rows for both users (days_completed 0). Decline: delete the row; the sender is NOT told.

3. `end_shared_reading(_id uuid) returns void`: either member may delete the row; progress and days cascade.

4. `report_reading_progress(_id uuid, _days_completed int, _read_today boolean, _today date) returns void`
   - Caller must be a member of an ACTIVE row. Clamp days_completed to 0..total_days. _today must be within 1 day of the server's current date ('invalid_date').
   - Upsert the caller's progress. Set finished_at the first time days_completed >= total_days. If _read_today is true, set last_read_at = now() and insert (id, caller, _today) into shared_reading_days ON CONFLICT DO NOTHING.

5. `get_shared_readings(_today date) returns table (id uuid, friend_id uuid, friend_name text, kind text, plan_id text, reference text, total_days int, status text, created_by_me boolean, my_days int, friend_days int, i_read_today boolean, friend_read_today boolean, pair_streak int, finished_together boolean, friend_last_read_at timestamptz, created_at timestamptz)`
   - All rows (pending and active) where the caller is a member, excluding blocked pairs and pairs no longer friends. friend_name = first non-empty of profiles.display_name, profiles.first_name, 'Friend' (max 30 chars). Pending rows return null for all progress fields.
   - pair_streak = consecutive days ending at _today (or _today - 1 if today isn't complete yet) on which BOTH members have a shared_reading_days row.
   - finished_together = both members have finished_at not null.
   - Accepting is the consent: it makes that one reading's progress visible to the partner. It does NOT depend on friend_sharing_prefs.

NOTIFICATIONS
Extend authorize_nudge and the send-friend-nudge edge function with new kinds and an optional `shared_reading_id` request field: 'reading_request' (proposal), 'reading_nudge' (reminder to read today), 'reading_celebrate' (both finished). Sender and recipient must be the two members of that shared reading (pending for reading_request; active for the others). Same allow_nudges, mute, block and rate-limit rules as other nudges. Templates, built server-side from the row:
  - reading_request: "{name} wants to read together" / body: "Plan" if kind = plan, else the passage reference
  - reading_nudge: "Today's reading with {name}" / body "They're counting on you. A little each day adds up."
  - reading_celebrate: "You and {name} finished!" / body "You read it together to the end."
Do not put plan names in notifications (the server doesn't have them).

CLEANUP RULES
- remove_friend and the user_blocks trigger must delete all shared_readings between the pair (progress and days cascade).
- Extend delete_my_friend_data() to delete every shared_readings row the caller is a member of.

Don't change anything else. Show me the SQL and confirm: (a) no plan titles, free text or Scripture text are stored, (b) a decline is silent, (c) a user can't read another pair's rows, (d) unfriending or blocking removes the shared readings.
```

### What the app will do with this
- **Start one:** from the Friends tab (or a plan's detail screen), pick a built-in plan or type a passage, then pick a friend. They accept or decline.
- **Each person reads at their own pace.** The card shows "You: day 5 of 30" next to "Sam: day 7 of 30", a ✓ for who read today, and a together streak when you both read the same day.
- **Ticking is automatic for plans.** When you mark a plan day complete in the existing Reading Plans screen, the app reports it; for a single passage you tap "I read it".
- **Open today's reading** jumps to the passage in the Bible reader.
- **Celebration** when you both finish, with a push to the other person.

---

## Prompt 12: Fix push delivery regression and rate-limit accounting

Symptom (verified from the app, iPad + iPhone simulators, Oct 9): the app uploads the device token successfully (`register_push_token` returns OK on every launch), but `send-friend-nudge` returns `{"sent":0}`, so the sender is told the friend "isn't registered". Everything worked until Prompt 11 changed `authorize_nudge` and the edge function. Also, failed attempts still count against the 24h limits, and the "one per recipient per 24h" rule appears to be shared across ALL notification kinds, so a few test taps lock out even the preset encouragements.

```
Please investigate and fix the push notification path. Do not change anything unrelated.

STEP 1: Diagnose (report before changing anything)
1. Show me the last 20 invocations of the `send-friend-nudge` edge function from its logs: HTTP status returned, and for each APNs call the APNs HTTP status and the `reason` string (for example BadDeviceToken, BadEnvironment, DeviceTokenNotForTopic, TopicDisallowed, BadPayload, ExpiredProviderToken, InvalidProviderToken). Never print the .p8 key, the provider JWT, or full device tokens (first 8 characters only).
2. For the user who is the recipient in those calls, show how many rows `push_tokens` has (count, environment, platform, updated_at). Confirm the edge function reads tokens with the same user id the app registers them under.
3. Diff the current `send-friend-nudge` and `authorize_nudge` against what they did before Prompt 11 and tell me what changed that could stop tokens being found or sent (for example a changed query, a new filter on kind, a recipient/sender swap, a payload field that is now null, or the new `shared_reading_id` / `quiz_id` handling throwing before the APNs call).

STEP 2: Fix
1. Token lookup: fetch ALL tokens for the recipient's user_id, send to each one, and use the right APNs host per token environment ('sandbox' => api.sandbox.push.apple.com, 'production' => api.push.apple.com). Use apns-topic = the APNS_BUNDLE_ID secret, apns-push-type alert, and a payload that always has non-empty title and body strings (fall back to a generic title/body if a template lookup fails; never send null).
2. Only delete a push_tokens row when APNs returns 410, or 400 with reason BadDeviceToken or Unregistered, or DeviceTokenNotForTopic. Do NOT delete tokens for any other error (BadPayload, ExpiredProviderToken, TooManyRequests, 5xx, network errors).
3. Response: return `{ "sent": <number of tokens APNs accepted>, "attempted": <tokens tried>, "failures": [ { "status": 400, "reason": "BadDeviceToken" } ] }` (reasons and statuses only, no token values) so the app can tell "no token" from "APNs rejected it". `sent` must equal accepted sends, and `attempted` 0 means the recipient has no tokens.
4. Rate limits must only count DELIVERED nudges: count rows in friend_nudges where delivered_at is not null, and set delivered_at only when at least one APNs send was accepted. A nudge that fails to deliver must not use up any quota (delete the log row, or leave delivered_at null and exclude it from every limit).
5. Make the "one per sender to the same recipient per 24h" limit apply PER KIND, not across all kinds. Keep the other caps: 10 per sender per 24h and 5 received per recipient per 24h, both counting delivered nudges only. 'quiz_result' and 'quiz_reaction' keep their own special rules from Prompt 10.
6. Re-verify that every kind still works end to end: encourage, praying, read_reminder, celebrate, verse_request, verse_quiz, verse_nudge, verse_celebrate, quiz_result, quiz_reaction, reading_request, reading_nudge, reading_celebrate. Send a test of each to a user who has a registered sandbox token and report the APNs result for each.

Show me the SQL and edge function diff, the diagnosis from step 1, and the per-kind test results. Do not log or return secrets or full tokens.
```

### After Lovable applies it
- In the app, a failed delivery will keep saying "isn't registered", because the app only knows `sent: 0`. I'll update the app to read `attempted` and `failures` and say which it is ("no device registered" vs "Apple rejected the device token"). Tell me when the prompt is applied.

---

## Prompt 13: `authorize_nudge` refusing a valid reminder (not_allowed)

After Prompt 12, sending **verse_nudge** (the "Remind Test User" action on an active Memorize Together verse) from the iPad account to the iPhone account is refused with `not_allowed`. The two users are friends, the shared verse is active, and the reverse direction (iPhone → iPad) is reaching the 5-per-day cap correctly, so only this direction fails.

```
Diagnose why authorize_nudge raises 'not_allowed' for this case and fix it. Don't change anything else.

Case: sender = the iPad test account (7d8ec7ba…), recipient = the iPhone test account (7bbf0613…), kind = 'verse_nudge', shared_verse_id = the active shared verse "Romans 8:2" between them. Also test 'reading_nudge' for the active shared reading (The Foundation Plan) in the same direction.

1. Evaluate each check in authorize_nudge for this exact sender/recipient/kind and tell me which one fails (friendship row exists in canonical order; is_blocked_pair false in both directions; shared verse or shared reading row has status 'active' and BOTH users are its members; the caller is a member and the recipient is the OTHER member, regardless of who created it; recipient's friend_sharing_prefs row exists and allow_nudges is true; recipient does not have the sender in friend_mutes).
2. Common culprits to check: the membership test only allowing created_by (or only the non-creator) to nudge, user_a/user_b canonical ordering applied to the wrong column, a missing friend_sharing_prefs row for one user being treated as 'not allowed' instead of 'nudges_off', and the Prompt 11/12 changes treating verse_* kinds differently from reading_* kinds.
3. Fix it so that EITHER member of an active shared verse/reading can send verse_nudge / reading_nudge to the other. Use distinct error messages: 'not_allowed' only for non-friends, blocked, or non-members; 'nudges_off' when the recipient disallows nudges; 'rate_limited' for caps. Don't use 'not_allowed' for the missing-prefs case.
4. Show me the check that was failing, the SQL change, and the result of sending verse_nudge and reading_nudge in BOTH directions (iPad → iPhone and iPhone → iPad).
```
