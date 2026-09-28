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

  async function fetchBranchProducts(branchId: string, limit: number = 50, productIds?: string[]): Promise<CatalogItem[]> {
    if (productIds?.length === 0) return []
    let query = supabase
      .from('branch_products')
      .select(`
        id,
        stock_quantity,
        selling_price,
        compare_at_price,
        is_available,
        product:products!inner(
          id, name, slug, description, brand_id, category_id,
          sku, barcode, image_url, images, unit, is_active,
          brand:brands(name, slug),
          category:categories(name, slug)
        )
      `)
      .eq('branch_id', branchId)
      .eq('is_active', true)
      .eq('is_available', true)
      .eq('product.is_active', true)
      .limit(limit)

    if (productIds) query = query.in('product_id', productIds)
    const { data, error } = await query
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
        images: p.images,
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

  async function fetchPromotionProducts(branchId: string): Promise<CatalogItem[]> {
    const now = new Date().toISOString()
    const { data, error } = await supabase
      .from('promotions')
      .select('id, promotion_products!inner(product_id)')
      .eq('is_active', true)
      .eq('promotion_products.branch_id', branchId)
      .or(`start_at.is.null,start_at.lte.${now}`)
      .or(`end_at.is.null,end_at.gte.${now}`)

    if (error) throw error
    const ids = [...new Set((data || []).flatMap(promotion =>
      promotion.promotion_products.map(item => item.product_id as string)
    ))]
    const products: CatalogItem[] = []
    for (let offset = 0; offset < ids.length; offset += 100) {
      products.push(...await fetchBranchProducts(branchId, 100, ids.slice(offset, offset + 100)))
    }
    return products
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
    fetchPromotionProducts,
    fetchByCategory,
    searchProducts,
    fetchProductBySlug,
  }
}
