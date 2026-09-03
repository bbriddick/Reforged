-- Group prayer requests + responses (Groups tab, Requirements §4).
--
-- Backs the iOS client added in GroupsService/GroupPrayerReviewView:
--   * prayer_requests    — one row per shared request (submitPrayer / myPrayerRequests /
--                          prayerQueueIds / prayer(id:) / deletePrayer)
--   * prayer_interactions — one row per response, a CLOSED set of kinds (no free text):
--                          'prayed' + preset encouragements 'lifting_up' / 'with_you' /
--                          'amen'  (respond(prayerId:kind:) / responseTally)
--
-- Schema matches the REAL groups tables on this project: groups live in
-- public.leader_groups(id) and membership in public.group_members(group_id,user_id)
-- where user_id = auth.uid(). RLS below scopes every read to group members and every
-- write to the acting user, so a prayer never crosses to a non-member and nobody can
-- speak for someone else.

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table if not exists public.prayer_requests (
  id          uuid primary key default gen_random_uuid(),
  group_id    uuid not null references public.leader_groups (id) on delete cascade,
  author_id   uuid not null references auth.users (id) on delete cascade,
  author_name text null,                        -- denormalised for attribution (no profile join)
  text        text not null check (char_length(text) between 1 and 2000),
  created_at  timestamptz not null default now()
);

create index if not exists prayer_requests_group_created_at_idx
  on public.prayer_requests (group_id, created_at desc);

create index if not exists prayer_requests_author_idx
  on public.prayer_requests (author_id);

create table if not exists public.prayer_interactions (
  id         uuid primary key default gen_random_uuid(),
  prayer_id  uuid not null references public.prayer_requests (id) on delete cascade,
  user_id    uuid not null references auth.users (id) on delete cascade,
  kind       text not null check (kind in ('prayed', 'lifting_up', 'with_you', 'amen')),
  created_at timestamptz not null default now(),
  -- One response per (request, user, kind); the client relies on this to make
  -- respond(...) idempotent (a duplicate POST returns 409, swallowed as success).
  unique (prayer_id, user_id, kind)
);

create index if not exists prayer_interactions_prayer_idx
  on public.prayer_interactions (prayer_id);

-- ---------------------------------------------------------------------------
-- Membership helper
-- ---------------------------------------------------------------------------
-- SECURITY DEFINER so the membership check itself isn't subject to group_members
-- RLS (avoids recursive policy evaluation). Returns true when the given user is a
-- member of the given group.

create or replace function public.is_prayer_group_member(_group_id uuid, _user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.group_members gm
    where gm.group_id = _group_id
      and gm.user_id  = _user_id
  );
$$;

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

alter table public.prayer_requests     enable row level security;
alter table public.prayer_interactions enable row level security;

-- prayer_requests --------------------------------------------------------------

-- Members of the group can read every request in it (the SRS deck + "Your requests").
drop policy if exists prayer_requests_select_members on public.prayer_requests;
create policy prayer_requests_select_members
  on public.prayer_requests
  for select
  using (public.is_prayer_group_member(group_id, (select auth.uid())));

-- A member can create a request only as themselves, only in a group they belong to.
drop policy if exists prayer_requests_insert_own on public.prayer_requests;
create policy prayer_requests_insert_own
  on public.prayer_requests
  for insert
  with check (
    author_id = (select auth.uid())
    and public.is_prayer_group_member(group_id, (select auth.uid()))
  );

-- Only the author can delete their own request (cascades to its interactions).
drop policy if exists prayer_requests_delete_own on public.prayer_requests;
create policy prayer_requests_delete_own
  on public.prayer_requests
  for delete
  using (author_id = (select auth.uid()));

-- prayer_interactions ----------------------------------------------------------

-- Members of the request's group can read responses (author sees tallies; the
-- select only exposes kinds, never free text — there is none).
drop policy if exists prayer_interactions_select_members on public.prayer_interactions;
create policy prayer_interactions_select_members
  on public.prayer_interactions
  for select
  using (
    exists (
      select 1
      from public.prayer_requests pr
      where pr.id = prayer_interactions.prayer_id
        and public.is_prayer_group_member(pr.group_id, (select auth.uid()))
    )
  );

-- A member can respond only as themselves, only to a request in their group.
drop policy if exists prayer_interactions_insert_own on public.prayer_interactions;
create policy prayer_interactions_insert_own
  on public.prayer_interactions
  for insert
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1
      from public.prayer_requests pr
      where pr.id = prayer_interactions.prayer_id
        and public.is_prayer_group_member(pr.group_id, (select auth.uid()))
    )
  );

-- A user may withdraw their own response (not used by the client yet, but keeps
-- the row owner in control of their data).
drop policy if exists prayer_interactions_delete_own on public.prayer_interactions;
create policy prayer_interactions_delete_own
  on public.prayer_interactions
  for delete
  using (user_id = (select auth.uid()));
