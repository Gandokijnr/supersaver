export function useAdminData() {
  const supabase = useSupabase()

  async function fetchDashboardStats(branchId: string | null = null) {
    let orderQuery = supabase.from('orders').select('id, total, order_status, created_at, branch_id')
    if (branchId) orderQuery = orderQuery.eq('branch_id', branchId)
    const { data: orders } = await orderQuery

    const today = new Date().toISOString().split('T')[0]
    const todayOrders = (orders || []).filter((o: any) => o.created_at?.startsWith(today))
    const todayRevenue = todayOrders.reduce((s: number, o: any) => s + Number(o.total), 0)
    const pending = (orders || []).filter((o: any) => o.order_status === 'pending').length
    const processing = (orders || []).filter((o: any) => o.order_status === 'processing' || o.order_status === 'confirmed').length
    const completed = (orders || []).filter((o: any) => o.order_status === 'delivered').length
    const cancelled = (orders || []).filter((o: any) => o.order_status === 'cancelled' || o.order_status === 'failed').length
    const aov = todayOrders.length > 0 ? todayRevenue / todayOrders.length : 0

    let bpQuery = supabase.from('branch_products').select('id, stock_quantity, is_available, is_active, branch_id')
    if (branchId) bpQuery = bpQuery.eq('branch_id', branchId)
    const { data: bp } = await bpQuery
    const lowStock = (bp || []).filter((b: any) => Number(b.stock_quantity) <= 5 && Number(b.stock_quantity) > 0 && b.is_active).length
    const outOfStock = (bp || []).filter((b: any) => Number(b.stock_quantity) <= 0 && b.is_active).length

    const { count: productCount } = await supabase.from('products').select('id', { count: 'exact', head: true })
    const { count: bpCount } = await supabase.from('branch_products').select('id', { count: 'exact', head: true })

    const { data: branches } = await supabase.from('branches').select('*').order('sort_order')

    return {
      todayOrders: todayOrders.length,
      todayRevenue,
      pending, processing, completed, cancelled, aov,
      productCount: productCount || 0,
      bpCount: bpCount || 0,
      lowStock, outOfStock,
      branches: branches || [],
      allOrders: orders || [],
    }
  }

  async function fetchOrders(branchId: string | null = null, status: string | null = null, limit = 50) {
    let q = supabase.from('orders').select('*').order('created_at', { ascending: false }).limit(limit)
    if (branchId) q = q.eq('branch_id', branchId)
    if (status && status !== 'all') q = q.eq('order_status', status)
    const { data, error } = await q
    if (error) throw error
    return data || []
  }

  async function fetchOrder(orderId: string) {
    const { data: order } = await supabase.from('orders').select('*').eq('id', orderId).maybeSingle()
    if (!order) return null
    const { data: items } = await supabase.from('order_items').select('*').eq('order_id', orderId)
    const { data: history } = await supabase.from('order_status_history').select('*').eq('order_id', orderId).order('created_at', { ascending: false })
    return { order, items: items || [], history: history || [] }
  }

  async function fetchInventory(branchId: string, search: string = '', offset = 0, limit = 50) {
    let q = supabase
      .from('branch_products')
      .select(`
        id, stock_quantity, selling_price, compare_at_price, is_available, is_active, updated_at,
        product:products!inner(id, name, slug, sku, category_id, is_active,
          category:categories(name, slug)
        ),
        branch:branches(name, slug)
      `)
      .eq('branch_id', branchId)
      .eq('is_active', true)
      .range(offset, offset + limit - 1)

    if (search) {
      q = q.or(`product.name.ilike.%${search}%,product.sku.ilike.%${search}%`)
    }

    const { data, error } = await q
    if (error) throw error
    return data || []
  }

  async function fetchNotifications() {
    const { data } = await supabase.from('admin_notifications').select('*').order('created_at', { ascending: false }).limit(20)
    return data || []
  }

  async function fetchImportJobs() {
    const { data } = await supabase.from('inventory_import_jobs').select(`
      *, branch:branches(name, slug)
    `).order('created_at', { ascending: false })
    return data || []
  }

  async function fetchImportJob(jobId: string) {
    const { data: job } = await supabase.from('inventory_import_jobs').select('*').eq('id', jobId).maybeSingle()
    if (!job) return null
    const { data: errors } = await supabase.from('inventory_import_errors').select('*').eq('job_id', jobId).order('row_number').limit(100)
    const { data: changes } = await supabase.from('inventory_import_changes').select('*').eq('job_id', jobId).limit(100)
    return { job, errors: errors || [], changes: changes || [] }
  }

  async function fetchAuditLogs(limit = 50) {
    const { data } = await supabase.from('audit_logs').select('*').order('created_at', { ascending: false }).limit(limit)
    return data || []
  }

  return {
    fetchDashboardStats, fetchOrders, fetchOrder,
    fetchInventory, fetchNotifications, fetchImportJobs, fetchImportJob, fetchAuditLogs,
  }
}
