-- Record the manually-created FK indexes as a tracked migration
-- so future branches inherit them automatically.
CREATE INDEX IF NOT EXISTS properties_owner_id_idx          ON public.properties           USING btree (owner_id);
CREATE INDEX IF NOT EXISTS property_photos_property_id_idx  ON public.property_photos      USING btree (property_id);
CREATE INDEX IF NOT EXISTS property_rooms_property_id_idx   ON public.property_rooms       USING btree (property_id);
CREATE INDEX IF NOT EXISTS room_inventory_items_room_id_idx ON public.room_inventory_items USING btree (room_id);
