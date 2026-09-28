export default defineNuxtPlugin(() => {
  const { user, ready } = useCustomerAuth()
  const profile = useState('customer-profile', () => ({ name: '', phone: '', email: '', address: '' }))
  useSupabase().auth.onAuthStateChange((_event, session) => {
    if (user.value?.id !== session?.user?.id) {
      profile.value = { name: '', phone: '', email: '', address: '' }
    }
    user.value = session?.user || null
    ready.value = true
  })
})
