<script setup lang="ts">
const { admin, logout, isLoggedIn } = useAdminAuth()
const route = useRoute()
const sidebarOpen = ref(false)

onMounted(() => {
  if (import.meta.client) {
    const { restore } = useAdminAuth()
    restore()
  }
})

const navItems = [
  { label: 'Dashboard', icon: 'dashboard', to: '/supersaver_ipass', roles: ['super_admin', 'admin', 'branch_manager', 'order_manager', 'inventory_manager'] },
  { label: 'Orders', icon: 'orders', to: '/supersaver_ipass/orders', roles: ['super_admin', 'admin', 'branch_manager', 'order_manager'] },
  { label: 'Inventory', icon: 'inventory', to: '/supersaver_ipass/inventory', roles: ['super_admin', 'admin', 'branch_manager', 'inventory_manager'] },
  { label: 'Import', icon: 'import', to: '/supersaver_ipass/inventory/import', roles: ['super_admin', 'admin', 'branch_manager', 'inventory_manager'] },
  { label: 'Import History', icon: 'history', to: '/supersaver_ipass/inventory/imports', roles: ['super_admin', 'admin', 'branch_manager', 'inventory_manager'] },
  { label: 'Products', icon: 'products', to: '/supersaver_ipass/products', roles: ['super_admin', 'admin', 'inventory_manager'] },
  { label: 'Categories', icon: 'categories', to: '/supersaver_ipass/categories', roles: ['super_admin', 'admin'] },
  { label: 'Branches', icon: 'branches', to: '/supersaver_ipass/branches', roles: ['super_admin', 'admin'] },
  { label: 'Customers', icon: 'customers', to: '/supersaver_ipass/customers', roles: ['super_admin', 'admin'] },
  { label: 'Promotions', icon: 'promotions', to: '/supersaver_ipass/promotions', roles: ['super_admin', 'admin'] },
  { label: 'Audit Logs', icon: 'audit', to: '/supersaver_ipass/audit-logs', roles: ['super_admin'] },
  { label: 'System', icon: 'system', to: '/supersaver_ipass/system', roles: ['super_admin', 'admin'] },
]

const visibleNav = computed(() => {
  if (!admin.value) return []
  return navItems.filter(item => item.roles.includes(admin.value!.role))
})

function isActive(to: string) {
  if (to === '/supersaver_ipass') return route.path === '/supersaver_ipass'
  return route.path.startsWith(to)
}

function doLogout() {
  logout()
  navigateTo('/supersaver_ipass/login')
}

watch(() => route.path, () => {
  sidebarOpen.value = false
})
</script>

<template>
  <div class="min-h-screen bg-ink-100">
    <!-- Desktop sidebar (in-flow, always visible on lg+) -->
    <aside class="hidden lg:flex flex-col fixed top-0 left-0 h-screen w-64 bg-ink-900 text-white flex-shrink-0 z-40">
      <div class="flex items-center gap-2 px-5 h-16 border-b border-ink-800 flex-shrink-0">
        <div class="w-8 h-8 bg-brand-600 rounded-lg flex items-center justify-center flex-shrink-0">
          <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z" /></svg>
        </div>
        <div class="min-w-0"><p class="font-extrabold text-sm leading-tight">Supersaver</p><p class="text-[10px] text-ink-400 leading-tight">Admin Console</p></div>
      </div>
      <nav class="p-3 space-y-0.5 overflow-y-auto flex-1">
        <NuxtLink v-for="item in visibleNav" :key="item.to" :to="item.to"
          class="flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-colors whitespace-nowrap"
          :class="isActive(item.to) ? 'bg-brand-600 text-white' : 'text-ink-300 hover:bg-ink-800 hover:text-white'">
          <span class="w-5 text-center flex-shrink-0">{{ navIcon(item.icon) }}</span>
          <span class="truncate">{{ item.label }}</span>
        </NuxtLink>
      </nav>
    </aside>

    <!-- Mobile sidebar drawer -->
    <Teleport to="body">
      <div v-if="sidebarOpen" class="lg:hidden fixed inset-0 z-[60]">
        <div class="absolute inset-0 bg-black/50" @click="sidebarOpen = false" />
        <aside class="absolute top-0 left-0 h-screen w-72 max-w-[85vw] bg-ink-900 text-white flex flex-col">
          <div class="flex items-center gap-2 px-5 h-14 border-b border-ink-800 flex-shrink-0">
            <div class="w-8 h-8 bg-brand-600 rounded-lg flex items-center justify-center flex-shrink-0">
              <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z" /></svg>
            </div>
            <div class="min-w-0"><p class="font-extrabold text-sm leading-tight">Supersaver</p><p class="text-[10px] text-ink-400 leading-tight">Admin Console</p></div>
            <button @click="sidebarOpen = false" class="ml-auto p-1.5 rounded-lg hover:bg-ink-800 text-ink-400 flex-shrink-0">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" /></svg>
            </button>
          </div>
          <nav class="p-3 space-y-0.5 overflow-y-auto flex-1">
            <NuxtLink v-for="item in visibleNav" :key="item.to" :to="item.to"
              class="flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-colors whitespace-nowrap"
              :class="isActive(item.to) ? 'bg-brand-600 text-white' : 'text-ink-300 hover:bg-ink-800 hover:text-white'">
              <span class="w-5 text-center flex-shrink-0">{{ navIcon(item.icon) }}</span>
              <span class="truncate">{{ item.label }}</span>
            </NuxtLink>
          </nav>
        </aside>
      </div>
    </Teleport>

    <!-- Main content area -->
    <div class="lg:pl-64 flex flex-col min-h-screen">
      <!-- Top bar -->
      <header class="sticky top-0 z-30 bg-white border-b border-ink-200 h-14 lg:h-16 flex items-center justify-between px-3 sm:px-4 flex-shrink-0">
        <button @click="sidebarOpen = true" class="lg:hidden p-2 -ml-2 rounded-lg hover:bg-ink-100 flex-shrink-0">
          <svg class="w-6 h-6 text-ink-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" /></svg>
        </button>
        <div class="flex items-center gap-2 sm:gap-3 ml-auto">
          <div class="text-right hidden sm:block">
            <p class="text-sm font-semibold text-ink-800 leading-tight">{{ admin?.name || 'Admin' }}</p>
            <p class="text-xs text-ink-400 capitalize leading-tight">{{ admin?.role?.replace(/_/g, ' ') }}</p>
          </div>
          <div class="w-8 h-8 sm:w-9 sm:h-9 rounded-full bg-brand-100 text-brand-700 flex items-center justify-center font-bold text-sm flex-shrink-0">
            {{ (admin?.name || 'A')[0] }}
          </div>
          <button @click="doLogout" class="p-2 rounded-lg hover:bg-ink-100 text-ink-500 flex-shrink-0" title="Logout">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" /></svg>
          </button>
        </div>
      </header>

      <main class="flex-1 p-3 sm:p-4 md:p-6 overflow-x-hidden">
        <slot />
      </main>
    </div>
  </div>
</template>

<script lang="ts">
function navIcon(icon: string): string {
  const icons: Record<string, string> = {
    dashboard: '▦', orders: '☰', inventory: '📦', import: '↑', history: '↻',
    products: '🏷', categories: '☰', branches: '🏪', customers: '👥',
    promotions: '★', audit: '📋', system: '⚙',
  }
  return icons[icon] || '●'
}
</script>
