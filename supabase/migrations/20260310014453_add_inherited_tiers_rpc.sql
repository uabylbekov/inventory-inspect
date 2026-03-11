CREATE OR REPLACE FUNCTION get_user_inherited_tiers(p_user_id uuid)
RETURNS TABLE (subscription_tier text) AS $$
BEGIN
  RETURN QUERY
  SELECT DISTINCT p_owner.subscription_tier
  FROM public.property_members pm
  JOIN public.properties prop ON pm.property_id = prop.id
  JOIN public.profiles p_owner ON prop.owner_id = p_owner.id
  WHERE pm.user_id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
