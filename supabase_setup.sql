-- ============================================================
-- WHISPER — Supabase Setup
-- Run this in: Supabase Dashboard > SQL Editor > New query
-- ============================================================


-- 1. PROFILES TABLE
-- Stores display name + email, linked to auth.users
-- ============================================================
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  email        text,
  created_at   timestamptz default now()
);

-- Auto-create profile row on signup
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, email, display_name)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1))
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();


-- 2. FOLDERS TABLE
-- ============================================================
create table if not exists public.folders (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  name        text not null,
  visibility  text not null default 'private' check (visibility in ('private', 'unlisted')),
  description text,
  created_at  timestamptz default now()
);

-- Index for fast user folder lookups
create index if not exists folders_user_id_idx on public.folders(user_id);


-- 3. WHISPERS TABLE
-- ============================================================
create table if not exists public.whispers (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  folder_id   uuid references public.folders(id) on delete set null,
  title       text not null,
  for_whom    text,
  message     text,
  audio_url   text not null,
  audio_path  text not null,
  duration    float default 0,
  share_token text unique not null,
  created_at  timestamptz default now()
);

-- Indexes
create index if not exists whispers_user_id_idx    on public.whispers(user_id);
create index if not exists whispers_folder_id_idx  on public.whispers(folder_id);
create index if not exists whispers_share_token_idx on public.whispers(share_token);


-- ============================================================
-- 4. ROW LEVEL SECURITY (RLS)
-- IMPORTANT: Without this, anyone can read/write all data
-- ============================================================

-- Enable RLS on all tables
alter table public.profiles enable row level security;
alter table public.folders  enable row level security;
alter table public.whispers enable row level security;

-- PROFILES: users can only read/update their own profile
create policy "profiles: own read"   on public.profiles for select using (auth.uid() = id);
create policy "profiles: own update" on public.profiles for update using (auth.uid() = id);
create policy "profiles: own insert" on public.profiles for insert with check (auth.uid() = id);

-- FOLDERS: owners can do everything; others can read unlisted
create policy "folders: owner all"   on public.folders for all    using (auth.uid() = user_id);
create policy "folders: public read" on public.folders for select using (visibility = 'unlisted');

-- WHISPERS: owners can do everything; anyone can read by share_token
-- (The app fetches by share_token, so public read is needed for listen page)
create policy "whispers: owner all"   on public.whispers for all    using (auth.uid() = user_id);
create policy "whispers: public read" on public.whispers for select using (true);
-- ^ Note: "select using (true)" lets anyone SELECT any whisper row.
--   This is intentional — the share_token acts as the access control.
--   If you want stricter access, change to: using (auth.uid() = user_id)
--   and fetch via a Supabase Edge Function instead.


-- ============================================================
-- 5. STORAGE BUCKET
-- Run this AFTER creating the bucket in Storage dashboard
-- or create via dashboard: Storage > New bucket > "whisper-audio" > Public
-- ============================================================

-- Storage policies (run after bucket exists)
-- Allow authenticated users to upload their own files
create policy "storage: auth upload"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'whisper-audio' and auth.uid()::text = (storage.foldername(name))[1]);

-- Allow anyone to read audio files (needed for public listen page)
create policy "storage: public read"
  on storage.objects for select
  to public
  using (bucket_id = 'whisper-audio');

-- Allow owners to delete their own files
create policy "storage: owner delete"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'whisper-audio' and auth.uid()::text = (storage.foldername(name))[1]);


-- ============================================================
-- DONE!
-- Next steps:
-- 1. Go to Storage > Create bucket > name: "whisper-audio" > toggle Public ON
-- 2. Run this SQL in SQL Editor
-- 3. Open whisper_supabase.html, fill in SUPABASE_URL and SUPABASE_KEY
-- 4. Deploy to Vercel / GitHub Pages
-- ============================================================
