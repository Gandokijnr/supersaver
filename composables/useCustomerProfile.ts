interface CustomerProfile {
  name: string
  phone: string
  email: string
  address: string
}

export function useCustomerProfile() {
  const supabase = useSupabase()
  const { user, restore: restoreAuth } = useCustomerAuth()
  const profile = useState<CustomerProfile>('customer-profile', () => ({ name: '', phone: '', email: '', address: '' }))

  async function restore() {
    await restoreAuth()
    const id = user.value?.id
    profile.value = { name: '', phone: '', email: '', address: '' }
    if (!id) return
    const { data, error } = await supabase.from('customer_profiles').select('name, phone, address').eq('id', id).maybeSingle()
    if (error) throw error
    if (user.value?.id !== id) return
    profile.value = { name: data?.name || user.value.user_metadata?.name || '', phone: data?.phone || '', address: data?.address || '', email: user.value.email || '' }
  }

  async function save(details: CustomerProfile) {
    if (!user.value) throw new Error('Please sign in to save your profile.')
    const cleaned = { name: details.name.trim(), phone: details.phone.trim(), address: details.address.trim() }
    const { error } = await supabase.from('customer_profiles').upsert({ id: user.value.id, ...cleaned, updated_at: new Date().toISOString() })
    if (error) throw error
    profile.value = { ...cleaned, email: user.value.email || '' }
  }

  return { profile, restore, save }
}
