BEGIN;

-- Admins also need to manage items on scheduled/inactive promotions.
CREATE POLICY admin_read_promotions ON public.promotions FOR SELECT TO anon, authenticated
  USING (EXISTS (SELECT 1 FROM public.branches b WHERE public.admin_can_access(b.id)));

DROP POLICY IF EXISTS anon_insert_promotion_products ON public.promotion_products;
DROP POLICY IF EXISTS anon_update_promotion_products ON public.promotion_products;
DROP POLICY IF EXISTS anon_delete_promotion_products ON public.promotion_products;

CREATE FUNCTION public.manage_promotion_items(p_promotion_id uuid, p_branch_id uuid, p_product_ids uuid[], p_remove boolean DEFAULT false)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_count integer;
BEGIN
  IF NOT public.admin_can_access(p_branch_id) THEN RAISE EXCEPTION 'Admin access to this branch is required'; END IF;
  IF p_product_ids IS NULL OR cardinality(p_product_ids) = 0 OR cardinality(p_product_ids) > 100 OR array_position(p_product_ids, NULL) IS NOT NULL THEN
    RAISE EXCEPTION 'Select between 1 and 100 items';
  END IF;
  -- Serialize changes to a promotion to prevent duplicate links on simultaneous saves.
  PERFORM 1 FROM public.promotions WHERE id = p_promotion_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Promotion not found'; END IF;
  IF p_remove THEN
    DELETE FROM public.promotion_products WHERE promotion_id = p_promotion_id AND branch_id = p_branch_id AND product_id = ANY(p_product_ids);
  ELSE
    IF EXISTS (
      SELECT 1 FROM unnest(p_product_ids) AS chosen(id)
      WHERE NOT EXISTS (
        SELECT 1 FROM public.branch_products bp JOIN public.products p ON p.id = bp.product_id
        WHERE bp.branch_id = p_branch_id AND bp.product_id = chosen.id AND bp.is_active AND p.is_active
      )
    ) THEN RAISE EXCEPTION 'Every selected item must be active inventory in this branch'; END IF;
    INSERT INTO public.promotion_products(promotion_id, branch_id, product_id)
    SELECT p_promotion_id, p_branch_id, chosen.id FROM (SELECT DISTINCT unnest(p_product_ids) AS id) chosen
    WHERE NOT EXISTS (SELECT 1 FROM public.promotion_products pp WHERE pp.promotion_id = p_promotion_id AND pp.branch_id = p_branch_id AND pp.product_id = chosen.id);
  END IF;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END $$;
REVOKE ALL ON FUNCTION public.manage_promotion_items(uuid, uuid, uuid[], boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.manage_promotion_items(uuid, uuid, uuid[], boolean) TO anon, authenticated;
COMMIT;
