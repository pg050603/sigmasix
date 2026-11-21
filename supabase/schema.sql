-- SigmaSix accounts, step 1: profiles and saved scores.
-- Run once in the Supabase dashboard: SQL Editor > New query > paste > Run.

create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  display_name text,
  plan text not null default 'free' check (plan in ('free', 'paid')),
  created_at timestamptz not null default now()
);

create table if not exists public.scores (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  mode text not null check (mode in ('daily', 'unlimited')),
  discipline text not null default 'all',
  day date not null,
  score int not null check (score between 0 and 700),
  sigma numeric(3, 1) not null check (sigma between 0 and 6),
  rounds jsonb,
  created_at timestamptz not null default now()
);
create index if not exists scores_user_idx on public.scores (user_id, created_at desc);

alter table public.profiles enable row level security;
alter table public.scores enable row level security;

-- Each person can read their own profile. The plan column is changed only by the
-- server (payments, later), so there is no update policy for it here.
create policy "read own profile" on public.profiles
  for select using (auth.uid() = id);

create policy "read own scores" on public.scores
  for select using (auth.uid() = user_id);
create policy "add own scores" on public.scores
  for insert with check (auth.uid() = user_id);

-- Create a profile row whenever someone signs up.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id) values (new.id) on conflict do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
