-- ============================================================
-- BASELINE SCHEMA - exported from production 2026-03-08
-- Order: tables -> functions -> RLS -> policies -> triggers
-- Reconstructed so fresh branches can build from migrations.
-- ============================================================

-- STEP 1: Tables

CREATE TABLE public.properties (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  owner_id uuid NOT NULL,
  name text NOT NULL,
  description text,
  property_type text NOT NULL,
  status text DEFAULT 'active' NOT NULL,
  country text NOT NULL,
  state_region text,
  city text,
  address_line1 text,
  address_line2 text,
  postal_code text,
  latitude double precision,
  longitude double precision,
  bedrooms_count integer DEFAULT 1 NOT NULL,
  bathrooms_count numeric DEFAULT 1 NOT NULL,
  max_guests integer,
  airbnb_listing_id text,
  vrbo_listing_id text,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL,
  PRIMARY KEY (id),
  CONSTRAINT properties_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

CREATE TABLE public.property_photos (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  property_id uuid NOT NULL,
  storage_path text NOT NULL,
  sort_order integer DEFAULT 0 NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  PRIMARY KEY (id),
  CONSTRAINT property_photos_property_id_fkey FOREIGN KEY (property_id) REFERENCES public.properties(id) ON DELETE CASCADE
);

CREATE TABLE public.property_rooms (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  property_id uuid NOT NULL,
  name text NOT NULL,
  room_type text,
  sort_order integer DEFAULT 0 NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  description text,
  PRIMARY KEY (id),
  CONSTRAINT property_rooms_property_id_fkey FOREIGN KEY (property_id) REFERENCES public.properties(id) ON DELETE CASCADE
);

CREATE TABLE public.room_inventory_items (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  room_id uuid NOT NULL,
  name text NOT NULL,
  category text,
  expected_qty integer DEFAULT 1 NOT NULL,
  notes text,
  created_at timestamptz DEFAULT now() NOT NULL,
  description text,
  PRIMARY KEY (id),
  CONSTRAINT room_inventory_items_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.property_rooms(id) ON DELETE CASCADE
);

CREATE TABLE public.property_members (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  property_id uuid NOT NULL,
  user_id uuid NOT NULL,
  role text NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  PRIMARY KEY (id),
  UNIQUE (property_id, user_id),
  CONSTRAINT property_members_role_check CHECK (role = ANY (ARRAY['owner','manager','cleaner'])),
  CONSTRAINT property_members_property_id_fkey FOREIGN KEY (property_id) REFERENCES public.properties(id) ON DELETE CASCADE,
  CONSTRAINT property_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

CREATE TABLE public.inspections (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  property_id uuid NOT NULL,
  inspector_id uuid NOT NULL,
  inspection_type text NOT NULL,
  status text DEFAULT 'in_progress' NOT NULL,
  notes text,
  started_at timestamptz DEFAULT now() NOT NULL,
  completed_at timestamptz,
  PRIMARY KEY (id),
  CONSTRAINT inspections_status_check CHECK (status = ANY (ARRAY['in_progress','completed','cancelled'])),
  CONSTRAINT inspections_inspection_type_check CHECK (inspection_type = ANY (ARRAY['check-in','check-out','routine'])),
  CONSTRAINT inspections_inspector_id_fkey FOREIGN KEY (inspector_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT inspections_property_id_fkey FOREIGN KEY (property_id) REFERENCES public.properties(id) ON DELETE CASCADE
);

CREATE TABLE public.inspection_items (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  inspection_id uuid NOT NULL,
  room_id uuid NOT NULL,
  inventory_item_id uuid NOT NULL,
  status text DEFAULT 'present' NOT NULL,
  notes text,
  updated_at timestamptz DEFAULT now() NOT NULL,
  image_url text,
  PRIMARY KEY (id),
  UNIQUE (inspection_id, inventory_item_id),
  CONSTRAINT inspection_items_status_check CHECK (status = ANY (ARRAY['present','missing','damaged','resolved'])),
  CONSTRAINT inspection_items_inventory_item_id_fkey FOREIGN KEY (inventory_item_id) REFERENCES public.room_inventory_items(id) ON DELETE CASCADE,
  CONSTRAINT inspection_items_inspection_id_fkey FOREIGN KEY (inspection_id) REFERENCES public.inspections(id) ON DELETE CASCADE,
  CONSTRAINT inspection_items_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.property_rooms(id) ON DELETE CASCADE
);

CREATE TABLE public.notifications (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  user_id uuid,
  title text NOT NULL,
  body text NOT NULL,
  type text NOT NULL,
  data jsonb DEFAULT '{}',
  is_read boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY (id),
  CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

CREATE TABLE public.user_push_tokens (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  user_id uuid,
  device_token text NOT NULL,
  platform text DEFAULT 'ios',
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY (id),
  UNIQUE (user_id, device_token),
  CONSTRAINT user_push_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

CREATE TABLE public.pending_invitations (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  property_id uuid NOT NULL,
  email text NOT NULL,
  role text DEFAULT 'manager' NOT NULL,
  invited_by uuid NOT NULL,
  status text DEFAULT 'pending' NOT NULL,
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY (id),
  UNIQUE (property_id, email),
  CONSTRAINT pending_invitations_property_id_fkey FOREIGN KEY (property_id) REFERENCES public.properties(id),
  CONSTRAINT pending_invitations_invited_by_fkey FOREIGN KEY (invited_by) REFERENCES auth.users(id)
);

-- STEP 2: Enable RLS
ALTER TABLE public.properties ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_inventory_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.property_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inspections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inspection_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_push_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pending_invitations ENABLE ROW LEVEL SECURITY;

-- STEP 3: Functions

CREATE OR REPLACE FUNCTION public.get_user_role(pid uuid)
RETURNS text
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT role FROM public.property_members WHERE property_id = pid AND user_id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.extract_storage_path(url text)
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  bucket_part text := 'inspection-images/';
  pos int;
BEGIN
  pos := strpos(url, bucket_part);
  IF pos > 0 THEN
    RETURN substring(url from pos + length(bucket_part));
  END IF;
  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_property_team_members(p_property_id uuid)
RETURNS TABLE(id uuid, user_id uuid, email varchar, name varchar, role text)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.property_members pm
    WHERE pm.property_id = p_property_id
      AND pm.user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'You are not a member of this property.';
  END IF;

  RETURN QUERY
  SELECT pm.id, pm.user_id, u.email::varchar, (u.raw_user_meta_data->>'full_name')::varchar, pm.role
  FROM public.property_members pm
  JOIN auth.users u ON pm.user_id = u.id
  WHERE pm.property_id = p_property_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_current_user()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_uid uuid;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  DELETE FROM auth.users WHERE id = v_uid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found or already deleted (uid: %)', v_uid;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.invite_user_to_property(p_email text, p_property_id uuid, p_role text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid;
  v_member_id uuid;
BEGIN
  p_email := lower(trim(p_email));

  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email = p_email;

  IF v_user_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM public.property_members
      WHERE property_id = p_property_id AND user_id = v_user_id
    ) THEN
      RAISE EXCEPTION 'User is already a member of this property';
    END IF;

    INSERT INTO public.property_members (property_id, user_id, role)
    VALUES (p_property_id, v_user_id, p_role)
    RETURNING id INTO v_member_id;

    RETURN jsonb_build_object('success', true, 'status', 'joined', 'member_id', v_member_id);
  ELSE
    INSERT INTO public.pending_invitations (property_id, email, role, invited_by)
    VALUES (p_property_id, p_email, p_role, auth.uid())
    ON CONFLICT (property_id, email) DO UPDATE
    SET role = EXCLUDED.role, created_at = now();

    RETURN jsonb_build_object('success', true, 'status', 'pending_created');
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_all_notifications_read()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.notifications
  SET is_read = true
  WHERE user_id = auth.uid()
    AND is_read = false;
END;
$$;

CREATE OR REPLACE FUNCTION public.add_property_owner_member()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.property_members (property_id, user_id, role)
  VALUES (NEW.id, NEW.owner_id, 'owner');
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.on_inspection_complete_notify()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_property_name text;
  v_team_member record;
BEGIN
  IF NEW.status = 'completed' AND (OLD.status = 'in_progress' OR OLD.status IS NULL) THEN
    SELECT p.name INTO v_property_name
    FROM public.properties p
    WHERE p.id = NEW.property_id;

    FOR v_team_member IN
      SELECT user_id
      FROM public.property_members
      WHERE property_id = NEW.property_id
        AND role IN ('owner','manager')
    LOOP
      IF v_team_member.user_id != NEW.inspector_id THEN
        INSERT INTO public.notifications (user_id, title, body, type, data)
        VALUES (
          v_team_member.user_id,
          'Inspection Completed',
          'An inspection for ' || v_property_name || ' has been completed.',
          'inspection_completed',
          jsonb_build_object(
            'inspection_id', NEW.id,
            'property_id', NEW.property_id,
            'inspector_id', NEW.inspector_id
          )
        );
      END IF;
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.on_property_member_invite_notify()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  property_name text;
BEGIN
  SELECT name INTO property_name
  FROM public.properties
  WHERE id = NEW.property_id;

  INSERT INTO public.notifications (user_id, title, body, type, data)
  VALUES (
    NEW.user_id,
    'New Property Access',
    'You have been added to ' || property_name || ' as a ' || NEW.role || '.',
    'invitation',
    jsonb_build_object('property_id', NEW.property_id)
  );

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.on_auth_user_created_accept_invites()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.property_members (property_id, user_id, role)
  SELECT property_id, NEW.id, role
  FROM public.pending_invitations
  WHERE email = lower(NEW.email);

  DELETE FROM public.pending_invitations
  WHERE email = lower(NEW.email);

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.on_inspection_item_delete_cleanup_storage()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  file_path text;
BEGIN
  IF OLD.image_url IS NOT NULL THEN
    file_path := public.extract_storage_path(OLD.image_url);
    IF file_path IS NOT NULL THEN
      DELETE FROM storage.objects
      WHERE bucket_id = 'inspection-images'
        AND name = file_path;
    END IF;
  END IF;
  RETURN OLD;
END;
$$;

CREATE OR REPLACE FUNCTION public.on_inspection_item_update_cleanup_storage()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  old_file_path text;
  new_file_path text;
BEGIN
  IF OLD.image_url IS NOT NULL AND (NEW.image_url IS NULL OR NEW.image_url != OLD.image_url) THEN
    old_file_path := public.extract_storage_path(OLD.image_url);
    new_file_path := public.extract_storage_path(NEW.image_url);

    IF old_file_path IS NOT NULL AND (new_file_path IS NULL OR new_file_path != old_file_path) THEN
      DELETE FROM storage.objects
      WHERE bucket_id = 'inspection-images'
        AND name = old_file_path;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- STEP 4: RLS Policies

CREATE POLICY "Owners can manage their properties"
ON public.properties
FOR ALL
USING (auth.uid() = owner_id)
WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Users can insert their own properties"
ON public.properties
FOR INSERT
WITH CHECK (owner_id = auth.uid());

CREATE POLICY "Users can view properties"
ON public.properties
FOR SELECT
USING (get_user_role(id) IS NOT NULL);

CREATE POLICY "Managers and Owners can update properties"
ON public.properties
FOR UPDATE
USING (get_user_role(id) = ANY (ARRAY['owner','manager']));

CREATE POLICY "Only owners can delete properties"
ON public.properties
FOR DELETE
USING (get_user_role(id) = 'owner');

CREATE POLICY "Managers and Owners can manage photos"
ON public.property_photos
FOR ALL
USING (get_user_role(property_id) = ANY (ARRAY['owner','manager']));

CREATE POLICY "Team members can view photos"
ON public.property_photos
FOR SELECT
USING (get_user_role(property_id) IS NOT NULL);

CREATE POLICY "Managers and Owners can manage rooms"
ON public.property_rooms
FOR ALL
USING (get_user_role(property_id) = ANY (ARRAY['owner','manager']));

CREATE POLICY "Team members can view rooms"
ON public.property_rooms
FOR SELECT
USING (get_user_role(property_id) IS NOT NULL);

CREATE POLICY "Managers and Owners can manage inventory items"
ON public.room_inventory_items
FOR ALL
USING (
  EXISTS (
    SELECT 1
    FROM public.property_rooms r
    WHERE r.id = room_inventory_items.room_id
      AND get_user_role(r.property_id) = ANY (ARRAY['owner','manager'])
  )
);

CREATE POLICY "Team members can view inventory items"
ON public.room_inventory_items
FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM public.property_rooms r
    WHERE r.id = room_inventory_items.room_id
      AND get_user_role(r.property_id) IS NOT NULL
  )
);

CREATE POLICY "Users can view team members"
ON public.property_members
FOR SELECT
USING (get_user_role(property_id) IS NOT NULL);

CREATE POLICY "Owners can add members"
ON public.property_members
FOR INSERT
WITH CHECK (get_user_role(property_id) = 'owner');

CREATE POLICY "Owners can update members"
ON public.property_members
FOR UPDATE
USING (get_user_role(property_id) = 'owner');

CREATE POLICY "Owners can remove members"
ON public.property_members
FOR DELETE
USING (get_user_role(property_id) = 'owner');

CREATE POLICY "Users can remove themselves"
ON public.property_members
FOR DELETE
USING (user_id = auth.uid());

CREATE POLICY "Team members can view inspections"
ON public.inspections
FOR SELECT
USING (get_user_role(property_id) IS NOT NULL);

CREATE POLICY "Team members can start inspections"
ON public.inspections
FOR INSERT
WITH CHECK (get_user_role(property_id) IS NOT NULL);

CREATE POLICY "Inspectors, Managers, and Owners can update"
ON public.inspections
FOR UPDATE
USING ((inspector_id = auth.uid()) OR (get_user_role(property_id) = ANY (ARRAY['owner','manager'])));

CREATE POLICY "Only owners can delete inspections"
ON public.inspections
FOR DELETE
USING (get_user_role(property_id) = 'owner');

CREATE POLICY "Team members can view inspection items"
ON public.inspection_items
FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM public.inspections i
    WHERE i.id = inspection_items.inspection_id
      AND get_user_role(i.property_id) IS NOT NULL
  )
);

CREATE POLICY "Team members can insert inspection items"
ON public.inspection_items
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.inspections i
    WHERE i.id = inspection_items.inspection_id
      AND get_user_role(i.property_id) IS NOT NULL
  )
);

CREATE POLICY "Inspectors, Managers, and Owners can update items"
ON public.inspection_items
FOR UPDATE
USING (
  EXISTS (
    SELECT 1
    FROM public.inspections i
    WHERE i.id = inspection_items.inspection_id
      AND ((i.inspector_id = auth.uid()) OR (get_user_role(i.property_id) = ANY (ARRAY['owner','manager'])))
  )
);

CREATE POLICY "Only owners can delete inspection items"
ON public.inspection_items
FOR DELETE
USING (
  EXISTS (
    SELECT 1
    FROM public.inspections i
    WHERE i.id = inspection_items.inspection_id
      AND get_user_role(i.property_id) = 'owner'
  )
);

CREATE POLICY "Users can view their own notifications"
ON public.notifications
FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own notifications"
ON public.notifications
FOR UPDATE
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own notifications"
ON public.notifications
FOR DELETE
USING (auth.uid() = user_id);

CREATE POLICY "System can insert notifications"
ON public.notifications
FOR INSERT
WITH CHECK (true);

CREATE POLICY "Users can manage their own tokens"
ON public.user_push_tokens
FOR ALL
USING (auth.uid() = user_id);

CREATE POLICY "Property owners/managers can view invitations"
ON public.pending_invitations
FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM public.property_members
    WHERE property_members.property_id = pending_invitations.property_id
      AND property_members.user_id = auth.uid()
      AND property_members.role = ANY (ARRAY['owner','manager'])
  )
);

CREATE POLICY "Invitors can view their own invitations"
ON public.pending_invitations
FOR SELECT
USING (auth.uid() = invited_by);

-- STEP 5: Triggers

CREATE TRIGGER on_property_created
AFTER INSERT ON public.properties
FOR EACH ROW
EXECUTE FUNCTION public.add_property_owner_member();

CREATE TRIGGER on_property_member_invite
AFTER INSERT ON public.property_members
FOR EACH ROW
EXECUTE FUNCTION public.on_property_member_invite_notify();

CREATE TRIGGER on_inspection_complete
AFTER UPDATE ON public.inspections
FOR EACH ROW
EXECUTE FUNCTION public.on_inspection_complete_notify();

CREATE TRIGGER tr_cleanup_inspection_images
AFTER DELETE ON public.inspection_items
FOR EACH ROW
EXECUTE FUNCTION public.on_inspection_item_delete_cleanup_storage();

CREATE TRIGGER tr_cleanup_inspection_images_update
AFTER UPDATE ON public.inspection_items
FOR EACH ROW
EXECUTE FUNCTION public.on_inspection_item_update_cleanup_storage();

CREATE OR REPLACE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.on_auth_user_created_accept_invites();
