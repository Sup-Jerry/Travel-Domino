create extension if not exists "pgcrypto";

create table if not exists user_account (
  user_id varchar(64) primary key,
  nickname varchar(128) not null,
  avatar_url text not null default '',
  mobile_masked varchar(32) not null default '',
  status varchar(32) not null,
  is_guest boolean not null default false,
  profile_completed boolean not null default false,
  default_login_method varchar(32) not null,
  register_time timestamptz not null,
  last_login_time timestamptz not null,
  mobile_bind_time timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists auth_identity (
  identity_id varchar(64) primary key,
  user_id varchar(64) not null references user_account(user_id),
  provider_type varchar(32) not null,
  provider_uid varchar(256) not null,
  provider_open_id varchar(256) not null default '',
  provider_union_id varchar(256) not null default '',
  phone_number varchar(32) not null default '',
  bind_status varchar(32) not null,
  bind_time timestamptz not null,
  last_used_time timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists ux_auth_identity_provider_uid on auth_identity(provider_type, provider_uid) where bind_status = 'BOUND';
create unique index if not exists ux_auth_identity_phone on auth_identity(phone_number) where provider_type = 'PHONE' and bind_status = 'BOUND';

create table if not exists user_session (
  session_id varchar(64) primary key,
  user_id varchar(64) not null references user_account(user_id),
  device_id varchar(128) not null,
  device_name varchar(128) not null,
  platform varchar(32) not null,
  access_token text not null,
  refresh_token text not null,
  issued_at timestamptz not null,
  expire_at timestamptz not null,
  refresh_expire_at timestamptz not null,
  status varchar(32) not null,
  login_method varchar(32) not null,
  last_active_time timestamptz not null,
  ip varchar(64) not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists ux_user_session_refresh_token on user_session(refresh_token);

create table if not exists verification_code (
  code_id varchar(64) primary key,
  biz_type varchar(64) not null,
  phone_number varchar(32) not null,
  code_hash varchar(128) not null,
  send_channel varchar(64) not null,
  expired_at timestamptz not null,
  verify_status varchar(32) not null,
  retry_count int not null default 0,
  created_at timestamptz not null,
  updated_at timestamptz not null default now()
);

create table if not exists guest_migration (
  migration_id varchar(64) primary key,
  guest_user_id varchar(64) not null,
  target_user_id varchar(64) not null,
  migrate_status varchar(32) not null,
  migrate_time timestamptz not null,
  created_at timestamptz not null
);

create table if not exists security_log (
  log_id varchar(64) primary key,
  user_id varchar(64) null,
  action_type varchar(64) not null,
  payload jsonb not null,
  created_at timestamptz not null
);

create index if not exists ix_security_log_user_time on security_log(user_id, created_at desc);

create table if not exists risk_counter (
  counter_id varchar(64) primary key,
  key_value varchar(256) not null unique,
  window_start timestamptz not null,
  count int not null,
  updated_at timestamptz not null
);
