-- SoulChoice Initial Schema
-- Run in Supabase SQL Editor

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- Cities
create table cities (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  country text not null,
  lat float,
  lng float,
  is_active boolean default true,
  created_at timestamptz default now()
);

-- Seed cities
insert into cities (name, country, lat, lng) values
  ('Moskova', 'RU', 55.7558, 37.6173),
  ('İstanbul', 'TR', 41.0082, 28.9784),
  ('Londra', 'GB', 51.5074, -0.1278),
  ('Dubai', 'AE', 25.2048, 55.2708),
  ('Berlin', 'DE', 52.5200, 13.4050);

-- Users
create table users (
  id uuid primary key references auth.users(id) on delete cascade,
  phone text unique,
  country_code text,
  language text default 'tr',
  name text,
  age int check (age >= 21 and age <= 60),
  gender text check (gender in ('female', 'male')),
  city_id uuid references cities(id),
  bio text check (char_length(bio) <= 200),
  job text,
  education text,
  interests jsonb default '[]'::jsonb,
  verified boolean default false,
  verified_at timestamptz,
  subscription_status text default 'free' check (subscription_status in ('free', 'premium')),
  subscription_provider text,
  warning_count int default 0,
  banned boolean default false,
  created_at timestamptz default now(),
  last_active_at timestamptz default now()
);

-- User photos
create table user_photos (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references users(id) on delete cascade,
  url text not null,
  is_primary boolean default false,
  is_selfie boolean default false,
  moderation_status text default 'pending' check (moderation_status in ('pending', 'approved', 'rejected')),
  ai_scan_result jsonb,
  order_index int default 0,
  created_at timestamptz default now()
);

-- User prompts
create table user_prompts (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references users(id) on delete cascade,
  question_key text not null,
  answer text,
  created_at timestamptz default now(),
  unique(user_id, question_key)
);

-- Invitations
create table invitations (
  id uuid primary key default uuid_generate_v4(),
  owner_id uuid references users(id) on delete cascade,
  flow_type text not null check (flow_type in ('invite', 'request')),
  category text not null check (category in ('food', 'concert', 'travel', 'culture', 'cinema', 'theater', 'coffee')),
  title text not null,
  description text,
  venue_name text,
  venue_lat float,
  venue_lng float,
  event_date timestamptz,
  city_id uuid references cities(id),
  slots_total int default 1 check (slots_total in (1, 2)),
  status text default 'active' check (status in ('active', 'matched', 'closed', 'cancelled')),
  created_at timestamptz default now(),
  expires_at timestamptz generated always as (created_at + interval '24 hours') stored
);

-- Applications
create table applications (
  id uuid primary key default uuid_generate_v4(),
  invitation_id uuid references invitations(id) on delete cascade,
  applicant_id uuid references users(id) on delete cascade,
  status text default 'pending' check (status in ('pending', 'selected', 'accepted', 'rejected', 'expired')),
  selected_at timestamptz,
  responded_at timestamptz,
  created_at timestamptz default now(),
  unique(invitation_id, applicant_id)
);

-- Matches
create table matches (
  id uuid primary key default uuid_generate_v4(),
  invitation_id uuid references invitations(id),
  user1_id uuid references users(id),
  user2_id uuid references users(id),
  meeting_date timestamptz,
  meeting_status text default 'scheduled' check (meeting_status in ('scheduled', 'happened', 'no_show')),
  chat_archived boolean default false,
  created_at timestamptz default now()
);

-- Messages
create table messages (
  id uuid primary key default uuid_generate_v4(),
  match_id uuid references matches(id) on delete cascade,
  sender_id uuid references users(id) on delete cascade,
  content text not null,
  read_at timestamptz,
  created_at timestamptz default now()
);

-- Reports
create table reports (
  id uuid primary key default uuid_generate_v4(),
  reporter_id uuid references users(id),
  reported_user_id uuid references users(id),
  reason text,
  description text,
  status text default 'pending' check (status in ('pending', 'reviewed', 'resolved')),
  created_at timestamptz default now()
);

-- Blocks
create table blocks (
  id uuid primary key default uuid_generate_v4(),
  blocker_id uuid references users(id) on delete cascade,
  blocked_id uuid references users(id) on delete cascade,
  created_at timestamptz default now(),
  unique(blocker_id, blocked_id)
);

-- User devices
create table user_devices (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references users(id) on delete cascade,
  device_id text,
  device_name text,
  last_active_at timestamptz default now(),
  created_at timestamptz default now()
);

-- Notification preferences
create table notification_preferences (
  user_id uuid primary key references users(id) on delete cascade,
  push_new_application boolean default true,
  push_selected boolean default true,
  push_message boolean default true,
  push_match boolean default true,
  quiet_hours_enabled boolean default false,
  quiet_hours_start time,
  quiet_hours_end time
);

-- Feature flags
create table feature_flags (
  key text primary key,
  value jsonb not null,
  description text,
  updated_at timestamptz default now()
);

-- Seed feature flags (launch values)
insert into feature_flags (key, value, description) values
  ('monetization_enabled', 'false', 'Global monetization switch'),
  ('max_active_invitations', '1', 'Max active invitations per user'),
  ('max_active_applications', '20', 'Max active applications per user'),
  ('verification_required', 'true', 'Require selfie verification'),
  ('social_login_enabled', 'false', 'Apple/Google login'),
  ('referral_system_enabled', 'false', 'Referral system'),
  ('min_age', '21', 'Minimum user age'),
  ('max_age', '60', 'Maximum user age');

-- Subscriptions
create table subscriptions (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references users(id) on delete cascade,
  status text check (status in ('active', 'cancelled', 'expired')),
  provider text check (provider in ('yookassa', 'apple', 'google', 'stripe')),
  started_at timestamptz,
  expires_at timestamptz,
  auto_renew boolean default true,
  price_paid int,
  currency text check (currency in ('RUB', 'USD')),
  created_at timestamptz default now()
);

-- User stats (admin only, hidden from users)
create table user_stats (
  user_id uuid primary key references users(id) on delete cascade,
  total_invitations int default 0,
  total_applications int default 0,
  total_matches int default 0,
  total_meetings int default 0,
  no_show_count int default 0,
  cancel_count int default 0
);

-- Indexes for performance
create index idx_invitations_city_status on invitations(city_id, status);
create index idx_invitations_owner on invitations(owner_id);
create index idx_invitations_expires on invitations(expires_at);
create index idx_applications_invitation on applications(invitation_id);
create index idx_applications_applicant on applications(applicant_id);
create index idx_messages_match on messages(match_id, created_at);
create index idx_blocks_blocker on blocks(blocker_id);

-- RLS Policies
alter table users enable row level security;
alter table user_photos enable row level security;
alter table invitations enable row level security;
alter table applications enable row level security;
alter table matches enable row level security;
alter table messages enable row level security;
alter table blocks enable row level security;

-- Users: read own, write own
create policy "users_select" on users for select using (true);
create policy "users_insert" on users for insert with check (auth.uid() = id);
create policy "users_update" on users for update using (auth.uid() = id);

-- Photos: read approved, write own
create policy "photos_select" on user_photos for select using (
  moderation_status = 'approved' or user_id = auth.uid()
);
create policy "photos_insert" on user_photos for insert with check (user_id = auth.uid());

-- Invitations: read active, write own
create policy "invitations_select" on invitations for select using (status = 'active' or owner_id = auth.uid());
create policy "invitations_insert" on invitations for insert with check (owner_id = auth.uid());
create policy "invitations_update" on invitations for update using (owner_id = auth.uid());

-- Applications: own only
create policy "applications_select" on applications for select using (
  applicant_id = auth.uid() or
  invitation_id in (select id from invitations where owner_id = auth.uid())
);
create policy "applications_insert" on applications for insert with check (applicant_id = auth.uid());
create policy "applications_update" on applications for update using (
  applicant_id = auth.uid() or
  invitation_id in (select id from invitations where owner_id = auth.uid())
);

-- Matches: participants only
create policy "matches_select" on matches for select using (
  user1_id = auth.uid() or user2_id = auth.uid()
);

-- Messages: match participants only
create policy "messages_select" on messages for select using (
  match_id in (select id from matches where user1_id = auth.uid() or user2_id = auth.uid())
);
create policy "messages_insert" on messages for insert with check (
  sender_id = auth.uid() and
  match_id in (select id from matches where user1_id = auth.uid() or user2_id = auth.uid())
);

-- Blocks: own
create policy "blocks_select" on blocks for select using (blocker_id = auth.uid());
create policy "blocks_insert" on blocks for insert with check (blocker_id = auth.uid());
