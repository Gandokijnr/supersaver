import type { CatalogItem, Category, Brand } from '~/lib/types'

export function useCatalog() {
  const supabase = useSupabase()

  async function fetchCategories(): Promise<Category[]> {
    const { data, error } = await supabase
      .from('categories')
      .select('*')
      .order('sort_order')
    if (error) throw error
    return data as Category[]
  }

  async function fetchBrands(): Promise<Brand[]> {
    const { data, error } = await supabase
      .from('brands')
      .select('*')
      .order('name')
    if (error) throw error
    return data as Brand[]
  }

  async function fetchBranchProducts(branchId: string, limit: number = 50): Promise<CatalogItem[]> {
    const { data, error } = await supabase
      .from('branch_products')
      .select(`
        id,
        stock_quantity,
        selling_price,
        compare_at_price,
        is_available,
        product:products!inner(
          id, name, slug, description, brand_id, category_id,
          sku, barcode, image_url, unit, is_active,
          brand:brands(name, slug),
          category:categories(name, slug)
        )
      `)
      .eq('branch_id', branchId)
      .eq('is_active', true)
      .eq('is_available', true)
      .eq('product.is_active', true)
      .limit(limit)

    if (error) throw error

    return (data || []).map((row: any) => {
      const p = row.product
      return {
        id: p.id,
        name: p.name,
        slug: p.slug,
        description: p.description,
        brand_id: p.brand_id,
        category_id: p.category_id,
        sku: p.sku,
        barcode: p.barcode,
        image_url: p.image_url,
        unit: p.unit,
        is_active: p.is_active,
        branch_product_id: row.id,
        stock_quantity: Number(row.stock_quantity),
        selling_price: Number(row.selling_price),
        compare_at_price: row.compare_at_price ? Number(row.compare_at_price) : null,
        brand_name: p.brand?.name ?? null,
        brand_slug: p.brand?.slug ?? null,
        category_name: p.category?.name ?? null,
        category_slug: p.category?.slug ?? null,
        discount_percent: row.compare_at_price && Number(row.compare_at_price) > Number(row.selling_price)
          ? Math.round(((Number(row.compare_at_price) - Number(row.selling_price)) / Number(row.compare_at_price)) * 100)
          : null,
      } as CatalogItem
    })
  }

  async function fetchByCategory(branchId: string, categorySlug: string): Promise<CatalogItem[]> {
    const all = await fetchBranchProducts(branchId, 200)
    return all.filter((p) => p.category_slug === categorySlug)
  }

  async function searchProducts(branchId: string, query: string): Promise<CatalogItem[]> {
    const all = await fetchBranchProducts(branchId, 200)
    const q = query.toLowerCase().trim()
    if (!q) return []
    return all.filter((p) =>
      p.name.toLowerCase().includes(q) ||
      (p.brand_name?.toLowerCase().includes(q) ?? false) ||
      (p.category_name?.toLowerCase().includes(q) ?? false) ||
      (p.sku?.toLowerCase().includes(q) ?? false)
    )
  }

  async function fetchProductBySlug(branchId: string, slug: string): Promise<CatalogItem | null> {
    const all = await fetchBranchProducts(branchId, 200)
    return all.find((p) => p.slug === slug) ?? null
  }

  return {
    fetchCategories,
    fetchBrands,
    fetchBranchProducts,
    fetchByCategory,
    searchProducts,
    fetchProductBySlug,
  }
}
