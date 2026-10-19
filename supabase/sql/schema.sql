-- Midnightaffair database. Run once in Supabase > SQL Editor.
-- If you ran an older version first, run this line before everything else:
-- drop table if exists messages, conversations, admins, listings cascade;

create table listings (
  id uuid primary key default gen_random_uuid(),
  display_name text not null,
  age int not null check (age >= 18),
  city text, tag text, bio text,
  photo_urls text[] default '{}',
  age_verified_at timestamptz,
  consent_recorded_at timestamptz,
  status text not null default 'draft' check (status in ('draft','live','paused')),
  created_at timestamptz default now(),
  check (status <> 'live' or (age_verified_at is not null and consent_recorded_at is not null))
);
create table admins (user_id uuid primary key references auth.users(id) on delete cascade);
create table conversations (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references auth.users(id) on delete cascade,
  listing_id uuid not null references listings(id) on delete cascade,
  status text not null default 'open' check (status in ('open','booked','closed','flagged','blocked')),
  disclosure_accepted_at timestamptz not null,
  created_at timestamptz default now(),
  unique (client_id, listing_id)
);
create table messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references conversations(id) on delete cascade,
  sender_role text not null check (sender_role in ('client','concierge')),
  sender_user uuid references auth.users(id),
  body text not null check (length(body) between 1 and 2000),
  created_at timestamptz default now()
);
create index on messages (conversation_id, created_at);

alter table listings enable row level security;
alter table admins enable row level security;
alter table conversations enable row level security;
alter table messages enable row level security;

create function is_admin() returns boolean language sql stable as
  $$ select exists (select 1 from admins where user_id = auth.uid()) $$;

create policy "admin sees own row" on admins for select using (user_id = auth.uid());
create policy "live listings are public" on listings for select using (status = 'live' or is_admin());
create policy "admins manage listings" on listings for all using (is_admin()) with check (is_admin());
create policy "see own conversations" on conversations for select using (client_id = auth.uid() or is_admin());
create policy "start own conversation" on conversations for insert with check (client_id = auth.uid());
create policy "admin updates conversations" on conversations for update using (is_admin());
create policy "read messages" on messages for select using (
  is_admin() or exists (select 1 from conversations c where c.id = conversation_id and c.client_id = auth.uid()));
create policy "client sends" on messages for insert with check (
  sender_role = 'client' and sender_user = auth.uid() and exists (
    select 1 from conversations c where c.id = conversation_id and c.client_id = auth.uid() and c.status <> 'blocked'));
create policy "concierge sends" on messages for insert with check (
  sender_role = 'concierge' and sender_user = auth.uid() and is_admin());

-- Automatic first message from the concierge team
create function welcome() returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into messages (conversation_id, sender_role, body)
  select new.id, 'concierge', 'Hi, thanks for your interest in ' || l.display_name ||
    '. You’re chatting with the Midnightaffair concierge team. Tell us a little about yourself and what you’re looking for, and we’ll arrange an introduction.'
  from listings l where l.id = new.listing_id;
  return new;
end $$;
create trigger t_welcome after insert on conversations for each row execute function welcome();

-- Spam limit: 15 client messages per minute
create function throttle() returns trigger language plpgsql as $$
begin
  if new.sender_role = 'client' and (select count(*) from messages
     where sender_user = new.sender_user and created_at > now() - interval '1 minute') >= 15 then
    raise exception 'Slow down: too many messages';
  end if;
  return new;
end $$;
create trigger t_throttle before insert on messages for each row execute function throttle();

-- Photos
insert into storage.buckets (id, name, public) values ('photos', 'photos', true) on conflict do nothing;
create policy "admin uploads photos" on storage.objects for insert with check (bucket_id = 'photos' and is_admin());

alter publication supabase_realtime add table messages, conversations;
