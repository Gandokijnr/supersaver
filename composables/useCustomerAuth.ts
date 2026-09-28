import type { User } from '@supabase/supabase-js'

export function useCustomerAuth() {
  const supabase = useSupabase()
  const user = useState<User | null>('customer-user', () => null)
  const ready = useState('customer-auth-ready', () => false)
  async function restore() {
    const { data, error } = await supabase.auth.getSession()
    if (error) throw error
    user.value = data.session?.user || null
    ready.value = true
  }
  async function signOut() {
    const { error } = await supabase.auth.signOut()
    if (error) throw error
    user.value = null
  }
  return { user, ready, restore, signOut }
}
