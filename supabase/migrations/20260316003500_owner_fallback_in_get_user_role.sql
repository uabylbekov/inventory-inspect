create or replace function public.get_user_role(pid uuid)
returns text
language sql
security definer
set search_path = public
as $$
  select role
  from (
    select pm.role, 0 as priority
    from public.property_members pm
    where pm.property_id = pid
      and pm.user_id = auth.uid()

    union all

    select 'owner'::text as role, 1 as priority
    from public.properties p
    where p.id = pid
      and p.owner_id = auth.uid()
  ) roles
  order by priority
  limit 1;
$$;
