/*
# Storage policies for inventory import files

Allow anon/authenticated to upload and read CSV files in the
inventory-imports bucket. Files are stored privately and accessed
via the service role key in the edge function.
*/

CREATE POLICY "anon_upload_inventory_imports" ON storage.objects
  FOR INSERT TO anon, authenticated
  WITH CHECK (bucket_id = 'inventory-imports');

CREATE POLICY "anon_read_inventory_imports" ON storage.objects
  FOR SELECT TO anon, authenticated
  USING (bucket_id = 'inventory-imports');

CREATE POLICY "anon_delete_inventory_imports" ON storage.objects
  FOR DELETE TO anon, authenticated
  USING (bucket_id = 'inventory-imports');
