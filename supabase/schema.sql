-- Rate by Restaurants
-- Supabase → SQL Editor → illeszd be ezt a fájlt → Run.
-- Újra is lefuttatható.

create table if not exists public.restaurants (
  id uuid primary key default gen_random_uuid(),
  place_key text not null unique,
  name text not null,
  city text not null,
  country_code text not null,
  country_name text not null,
  address text not null default '',
  latitude double precision not null,
  longitude double precision not null,
  created_at timestamptz not null default now()
);

create table if not exists public.ratings (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  stars integer not null check (stars between 1 and 5),
  created_at timestamptz not null default now(),
  unique (restaurant_id, user_id)
);

create table if not exists public.dishes (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 80),
  created_at timestamptz not null default now()
);

create unique index if not exists dishes_one_vote
  on public.dishes (restaurant_id, user_id, lower(name));

create index if not exists restaurants_country_city
  on public.restaurants (country_code, city);

alter table public.restaurants
  add column if not exists cuisine text default 'General';

create index if not exists restaurants_city_cuisine
  on public.restaurants (city, cuisine);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  restaurant_id uuid not null references public.restaurants (id) on delete cascade,
  dish_id uuid references public.dishes (id) on delete set null,
  reason text not null check (char_length(btrim(reason)) between 1 and 200),
  created_at timestamptz not null default now()
);

alter table public.restaurants enable row level security;
alter table public.ratings enable row level security;
alter table public.dishes enable row level security;
alter table public.reports enable row level security;

grant select on public.restaurants to anon, authenticated;
grant insert on public.restaurants to authenticated;
grant select on public.ratings to anon, authenticated;
grant insert, update, delete on public.ratings to authenticated;
grant select on public.dishes to anon, authenticated;
grant insert, delete on public.dishes to authenticated;
grant insert on public.reports to authenticated;
grant select on public.reports to authenticated;

drop policy if exists "restaurants readable" on public.restaurants;
drop policy if exists "restaurants insert" on public.restaurants;
create policy "restaurants readable" on public.restaurants
  for select using (true);
create policy "restaurants insert" on public.restaurants
  for insert to authenticated with check (true);

drop policy if exists "ratings readable" on public.ratings;
drop policy if exists "ratings insert own" on public.ratings;
drop policy if exists "ratings update own" on public.ratings;
drop policy if exists "ratings delete own" on public.ratings;
create policy "ratings readable" on public.ratings
  for select using (true);
create policy "ratings insert own" on public.ratings
  for insert to authenticated with check (auth.uid() = user_id);
create policy "ratings update own" on public.ratings
  for update to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "ratings delete own" on public.ratings
  for delete to authenticated using (auth.uid() = user_id);

drop policy if exists "dishes readable" on public.dishes;
drop policy if exists "dishes insert own" on public.dishes;
drop policy if exists "dishes delete own" on public.dishes;
create policy "dishes readable" on public.dishes
  for select using (true);
create policy "dishes insert own" on public.dishes
  for insert to authenticated with check (auth.uid() = user_id);
create policy "dishes delete own" on public.dishes
  for delete to authenticated using (auth.uid() = user_id);

drop policy if exists "reports insert own" on public.reports;
drop policy if exists "reports read own" on public.reports;
create policy "reports insert own" on public.reports
  for insert to authenticated with check (auth.uid() = user_id);
create policy "reports read own" on public.reports
  for select to authenticated using (auth.uid() = user_id);

create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_own_account() from public;
grant execute on function public.delete_own_account() to authenticated;

create table if not exists public.favorites (
  user_id uuid primary key references auth.users (id) on delete cascade,
  country_code text,
  place_key text,
  name text,
  city text,
  country_name text,
  address text,
  latitude double precision,
  longitude double precision,
  updated_at timestamptz not null default now()
);

alter table public.favorites enable row level security;

grant select, insert, update on public.favorites to authenticated;

drop policy if exists "favorites read own" on public.favorites;
drop policy if exists "favorites insert own" on public.favorites;
drop policy if exists "favorites update own" on public.favorites;
create policy "favorites read own" on public.favorites
  for select to authenticated using (auth.uid() = user_id);
create policy "favorites insert own" on public.favorites
  for insert to authenticated with check (auth.uid() = user_id);
create policy "favorites update own" on public.favorites
  for update to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

create table if not exists public.favorite_countries (
  user_id uuid not null references auth.users (id) on delete cascade,
  country_code text not null,
  created_at timestamptz not null default now(),
  primary key (user_id, country_code)
);

alter table public.favorite_countries enable row level security;

grant select, insert, delete on public.favorite_countries to authenticated;

drop policy if exists "favorite countries read own" on public.favorite_countries;
drop policy if exists "favorite countries insert own" on public.favorite_countries;
drop policy if exists "favorite countries delete own" on public.favorite_countries;

create or replace function public.can_add_favorite_country(target uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid() = target
    and (
      select count(*) from public.favorite_countries f where f.user_id = target
    ) < (
      case
        when (select count(*) from public.ratings r where r.user_id = target) >= 10
         and (select count(*) from public.ratings r where r.user_id = target and r.stars >= 4) >= 5
         and (select count(*) from public.favorite_countries f where f.user_id = target) >= 3
        then 10
        when (select count(*) from public.ratings r where r.user_id = target) >= 3
         and (select count(*) from public.favorite_countries f where f.user_id = target) >= 1
        then 3
        else 1
      end
    );
$$;

revoke all on function public.can_add_favorite_country(uuid) from public;
grant execute on function public.can_add_favorite_country(uuid) to authenticated;

create policy "favorite countries read own" on public.favorite_countries
  for select to authenticated using (auth.uid() = user_id);

create policy "favorite countries delete own" on public.favorite_countries
  for delete to authenticated using (auth.uid() = user_id);

create policy "favorite countries insert own" on public.favorite_countries
  for insert to authenticated
  with check (public.can_add_favorite_country(user_id));
