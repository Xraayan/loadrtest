create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  job_id text references public.jobs(id) on delete cascade,
  trip_id uuid references public.trips(id) on delete set null,
  sender_uid text not null references public.profiles(firebase_uid) on delete cascade,
  receiver_uid text not null references public.profiles(firebase_uid) on delete cascade,
  message text not null,
  created_at timestamptz not null default now()
);

create index if not exists chat_messages_job_created_idx
on public.chat_messages (job_id, created_at);

create index if not exists chat_messages_sender_created_idx
on public.chat_messages (sender_uid, created_at desc);

create index if not exists chat_messages_receiver_created_idx
on public.chat_messages (receiver_uid, created_at desc);

alter table public.chat_messages enable row level security;

grant select, insert, update, delete on public.chat_messages to authenticated, service_role;

notify pgrst, 'reload schema';
