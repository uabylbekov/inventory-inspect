-- Allow authenticated users to upload to their own folder
CREATE POLICY "Users can upload their own logo"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'company-logos'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow authenticated users to update their own logo
CREATE POLICY "Users can update their own logo"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'company-logos'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Public read access (logo appears in PDFs on any device)
CREATE POLICY "Anyone can read company logos"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'company-logos');
