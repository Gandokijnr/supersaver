import type { AdminUser } from '~/lib/types'

export function useAdminAuth() {
  const supabase = useSupabase()
  const admin = useState<AdminUser | null>('admin_user', () => null)
  const token = useState<string | null>('admin_token', () => null)

  const isLoggedIn = computed(() => !!admin.value)
  const role = computed(() => admin.value?.role || null)
  const branchId = computed(() => admin.value?.branch_id || null)

  function canAccess(requiredRole: string[]): boolean {
    if (!admin.value) return false
    return requiredRole.includes(admin.value.role)
  }

  async function login(email: string, password: string): Promise<{ success: boolean; error?: string }> {
    const { data, error: rpcError } = await supabase.rpc('admin_login', {
      p_email: email,
      p_password: password,
    })
    if (rpcError) return { success: false, error: 'Authentication failed.' }
    const result = data as any
    if (!result || !result.id || !result.session_token) return { success: false, error: 'Invalid credentials or account migration is not installed.' }
    admin.value = result as AdminUser
    token.value = result.session_token
    if (import.meta.client) {
      localStorage.setItem('ss_admin', JSON.stringify(result))
      localStorage.setItem('ss_admin_token', result.session_token)
    }
    return { success: true }
  }

  function restore() {
    if (!import.meta.client) return
    const saved = localStorage.getItem('ss_admin')
    token.value = localStorage.getItem('ss_admin_token')
    if (saved && token.value) {
      try { admin.value = JSON.parse(saved) } catch { localStorage.removeItem('ss_admin') }
    }
  }

  function logout() {
    admin.value = null
    token.value = null
    if (import.meta.client) localStorage.removeItem('ss_admin')
    if (import.meta.client) localStorage.removeItem('ss_admin_token')
  }

  return { admin, isLoggedIn, role, branchId, canAccess, login, logout, restore }
}
