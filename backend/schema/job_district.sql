alter table if exists public.jobs
add column if not exists district text;

update public.jobs
set district = coalesce(nullif(district, ''), nullif(city, ''), '')
where district is null or district = '';
