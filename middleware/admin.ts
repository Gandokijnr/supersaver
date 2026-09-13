export default defineNuxtRouteMiddleware((to) => {
  if (import.meta.client) {
    const { admin, restore } = useAdminAuth()
    restore()
    if (!admin.value && to.path !== '/supersaver_ipass/login') {
      return navigateTo('/supersaver_ipass/login')
    }
  }
})
