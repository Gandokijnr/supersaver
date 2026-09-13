<script setup lang="ts">
const cartStore = useCartStore()
const route = useRoute()

const items = [
  { label: 'Home', icon: 'home', to: '/' },
  { label: 'Categories', icon: 'grid', to: '/categories' },
  { label: 'Search', icon: 'search', to: '/search' },
  { label: 'Orders', icon: 'bag', to: '/orders' },
  { label: 'Cart', icon: 'cart', to: '/cart' },
]

function isActive(to: string) {
  if (to === '/') return route.path === '/'
  return route.path.startsWith(to)
}
</script>

<template>
  <nav class="md:hidden fixed bottom-0 left-0 right-0 z-40 bg-white/95 backdrop-blur-lg border-t border-ink-200 shadow-[0_-2px_12px_rgba(0,0,0,0.06)]">
    <div class="flex items-center justify-around h-16 px-2 safe-area-pb">
      <NuxtLink
        v-for="item in items"
        :key="item.to"
        :to="item.to"
        class="flex flex-col items-center justify-center gap-0.5 px-2.5 py-1 rounded-xl transition-all duration-200 relative"
        :class="isActive(item.to) ? 'text-brand-600' : 'text-ink-400 active:text-ink-600'"
      >
        <div class="relative">
          <svg v-if="item.icon === 'home'" class="w-6 h-6 transition-transform duration-200" :class="isActive(item.to) ? 'scale-110' : ''" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
          </svg>
          <svg v-else-if="item.icon === 'grid'" class="w-6 h-6 transition-transform duration-200" :class="isActive(item.to) ? 'scale-110' : ''" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z" />
          </svg>
          <svg v-else-if="item.icon === 'search'" class="w-6 h-6 transition-transform duration-200" :class="isActive(item.to) ? 'scale-110' : ''" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
          </svg>
          <svg v-else-if="item.icon === 'bag'" class="w-6 h-6 transition-transform duration-200" :class="isActive(item.to) ? 'scale-110' : ''" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 11V7a4 4 0 00-8 0v4M5 9h14l1 12H4L5 9z" />
          </svg>
          <svg v-else class="w-6 h-6 transition-transform duration-200" :class="isActive(item.to) ? 'scale-110' : ''" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z" />
          </svg>
          <span
            v-if="item.icon === 'cart' && cartStore.itemCount > 0"
            class="absolute -top-1.5 -right-2 bg-accent-500 text-white text-[9px] font-bold rounded-full min-w-[16px] h-[16px] flex items-center justify-center px-1 animate-fade-in"
          >{{ cartStore.itemCount }}</span>
        </div>
        <span class="text-[10px] font-medium" :class="isActive(item.to) ? 'font-semibold' : ''">{{ item.label }}</span>
        <span v-if="isActive(item.to)" class="absolute -bottom-0.5 w-1 h-1 bg-brand-500 rounded-full" />
      </NuxtLink>
    </div>
  </nav>
</template>
