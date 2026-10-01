-- Fix admin audit updates across heterogeneous tables.
-- The previous trigger function referenced OLD/NEW.revoked_at directly inside
-- a shared trigger function. PostgreSQL can fail record-field resolution for
-- UPDATEs on tables that do not have that column. JSON extraction keeps the
-- audit trigger additive and safe for every attached table.

create or replace function private.write_finetime_admin_audit()
returns trigger
language plpgsql
security definer
set search_path = 'pg_catalog', 'public', 'private'
as $function$
declare
  v_admin uuid := auth.uid();
  v_action text;
  v_entity_type text := tg_table_name;
  v_entity_id uuid;
  v_metadata jsonb := '{}'::jsonb;
  old_json jsonb := case when tg_op <> 'INSERT' then to_jsonb(old) else '{}'::jsonb end;
  new_json jsonb := case when tg_op <> 'DELETE' then to_jsonb(new) else '{}'::jsonb end;
begin
  if v_admin is null or not exists (
    select 1
    from public.admin_memberships am
    where am.user_id = v_admin
      and am.role = 'admin'
  ) then
    return coalesce(new, old);
  end if;

  if tg_op = 'INSERT' then
    v_entity_id := new.id;
    v_action := case tg_table_name
      when 'businesses' then 'business_create'
      when 'activation_codes' then 'activation_code_create'
      when 'news' then 'news_create'
      when 'site_modules' then 'future_module_create'
      else tg_table_name || '_create'
    end;
    v_metadata := jsonb_build_object('new', new_json);

  elsif tg_op = 'DELETE' then
    v_entity_id := old.id;
    v_action := case tg_table_name
      when 'businesses' then 'business_delete'
      when 'activation_codes' then 'activation_code_delete'
      when 'news' then 'news_delete'
      when 'site_modules' then 'future_module_delete'
      else tg_table_name || '_delete'
    end;
    v_metadata := jsonb_build_object('old', old_json);

  else
    v_entity_id := new.id;
    v_action := case tg_table_name
      when 'businesses' then
        case
          when (old_json->>'is_published') is distinct from (new_json->>'is_published')
            then case when (new_json->>'is_published')::boolean
              then 'business_publish' else 'business_hide' end
          else 'business_edit'
        end
      when 'activation_codes' then
        case
          when old_json->>'revoked_at' is null and new_json->>'revoked_at' is not null
            then 'activation_code_revoke'
          else 'activation_code_edit'
        end
      when 'news' then
        case
          when (old_json->>'is_published') is distinct from (new_json->>'is_published')
            then case when (new_json->>'is_published')::boolean
              then 'news_publish' else 'news_hide' end
          else 'news_edit'
        end
      when 'site_modules' then
        case
          when (old_json->>'is_enabled') is distinct from (new_json->>'is_enabled')
            then case when (new_json->>'is_enabled')::boolean
              then 'future_module_enable' else 'future_module_disable' end
          else 'future_module_edit'
        end
      else tg_table_name || '_edit'
    end;
    v_metadata := jsonb_build_object('old', old_json, 'new', new_json);
  end if;

  insert into public.admin_audit_logs(admin_user_id, action, entity_type, entity_id, metadata)
  values (v_admin, v_action, v_entity_type, v_entity_id, v_metadata);

  return coalesce(new, old);
end;
$function$;

revoke execute on function private.write_finetime_admin_audit() from public;
