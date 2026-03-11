ALTER TABLE public.profiles
ALTER COLUMN business_details TYPE text
USING business_details::text;
