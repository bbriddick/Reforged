# Lovable prompts: onboarding / new-device restore

## Prompt 14: `profiles.preferences` (optional; for people without iCloud)

Why: on a new device, a signed-in user's look-and-reading choices (translation, theme, font, reading format, reminder time, tour progress) restore from their iCloud profile. For people without iCloud (or email users who haven't synced yet) the app keeps a copy in the Supabase profile. The app writes and reads it separately from the main profile upsert and ignores failures, so nothing breaks until this exists.

```
Add one column to public.profiles and nothing else:

  alter table public.profiles add column if not exists preferences jsonb;

Requirements:
1. The existing RLS policies already let a signed-in user read and update their own profile row (user_id = auth.uid()). Confirm that PATCH /rest/v1/profiles?user_id=eq.<uid> with {"preferences": {...}} and GET /rest/v1/profiles?user_id=eq.<uid>&select=preferences both work for the owner, and that no other user can read or write someone else's preferences. If a policy is column-restricted or uses a trigger that blocks unknown columns, adjust it so `preferences` is writable by the owner only.
2. Do NOT expose `preferences` to the friends RPCs, group member lists, or any public view. It is private to the owner.
3. Limit its size: add a check constraint so pg_column_size(preferences) <= 8192.
4. Don't change birth_date, leader_role, or any other column or trigger behavior.

Show me the SQL and confirm the owner can read and write it and nobody else can.
```
