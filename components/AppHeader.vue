<script setup lang="ts">
const branchStore = useBranchStore()
const cartStore = useCartStore()
const router = useRouter()
const searchQuery = ref('')
const showSearch = ref(false)

function goToSearch() {
  if (searchQuery.value.trim()) {
    router.push(`/search?q=${encodeURIComponent(searchQuery.value.trim())}`)
    showSearch.value = false
    searchQuery.value = ''
  }
}

const cartCount = computed(() => cartStore.itemCount)
</script>

<template>
  <header class="sticky top-0 z-40 bg-white border-b border-ink-100 shadow-sm">
    <!-- Top bar -->
    <div class="bg-brand-700 text-white text-xs py-1.5 px-4 text-center hidden md:block">
      Fresh groceries, better prices, delivered to your door across Lagos
    </div>

    <div class="max-w-7xl mx-auto px-4">
      <div class="flex items-center gap-3 h-16">
        <!-- Logo -->
        <NuxtLink to="/" class="flex items-center gap-2 shrink-0">
          <div class="w-9 h-9 bg-brand-600 rounded-xl flex items-center justify-center">
            <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z" />
            </svg>
          </div>
          <span class="font-extrabold text-lg text-ink-800 hidden sm:block">Supersaver</span>
        </NuxtLink>

        <!-- Branch selector -->
        <NuxtLink
          to="/select-branch"
          class="flex items-center gap-1.5 shrink-0 px-3 py-2 rounded-xl hover:bg-ink-50 transition-colors"
        >
          <svg class="w-4 h-4 text-brand-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
          </svg>
          <div class="hidden sm:block text-left">
            <div class="text-[10px] text-ink-400 leading-none">Shopping from</div>
            <div class="text-sm font-semibold text-ink-800 leading-tight flex items-center gap-1">
              {{ branchStore.currentBranch?.name.replace('Supersaver ', '') }}
              <svg class="w-3 h-3 text-ink-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
              </svg>
            </div>
          </div>
          <span class="sm:hidden text-sm font-semibold text-ink-800">{{ branchStore.currentBranch?.name.replace('Supersaver ', '') }}</span>
        </NuxtLink>

        <!-- Search -->
        <div class="flex-1 max-w-2xl hidden md:block">
          <form @submit.prevent="goToSearch" class="relative">
            <input
              v-model="searchQuery"
              type="text"
              placeholder="Search products, brands, categories..."
              class="w-full pl-10 pr-4 py-2.5 rounded-xl bg-ink-50 border border-ink-200 focus:border-brand-500 focus:bg-white focus:ring-2 focus:ring-brand-100 outline-none transition-all text-sm"
            />
            <svg class="w-5 h-5 text-ink-400 absolute left-3 top-1/2 -translate-y-1/2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
            </svg>
          </form>
        </div>

        <!-- Actions -->
        <div class="flex items-center gap-1 ml-auto">
          <button
            @click="showSearch = !showSearch"
            class="md:hidden p-2 rounded-xl hover:bg-ink-50 transition-colors"
            aria-label="Search"
          >
            <svg class="w-6 h-6 text-ink-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
            </svg>
          </button>

          <NuxtLink to="/cart" class="relative p-2 rounded-xl hover:bg-ink-50 transition-colors" aria-label="Cart">
            <svg class="w-6 h-6 text-ink-700" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z" />
            </svg>
            <span
              v-if="cartCount > 0"
              class="absolute -top-0.5 -right-0.5 bg-accent-500 text-white text-[10px] font-bold rounded-full min-w-[18px] h-[18px] flex items-center justify-center px-1"
            >{{ cartCount }}</span>
          </NuxtLink>
        </div>
      </div>

      <!-- Category nav -->
      <nav class="hidden md:flex items-center gap-1 pb-2 -mt-1">
        <NuxtLink to="/" class="px-3 py-1.5 text-sm font-medium text-ink-600 hover:text-brand-600 hover:bg-brand-50 rounded-lg transition-colors">Home</NuxtLink>
        <NuxtLink to="/category/groceries" class="px-3 py-1.5 text-sm font-medium text-ink-600 hover:text-brand-600 hover:bg-brand-50 rounded-lg transition-colors">Groceries</NuxtLink>
        <NuxtLink to="/category/beverages" class="px-3 py-1.5 text-sm font-medium text-ink-600 hover:text-brand-600 hover:bg-brand-50 rounded-lg transition-colors">Beverages</NuxtLink>
        <NuxtLink to="/category/dairy" class="px-3 py-1.5 text-sm font-medium text-ink-600 hover:text-brand-600 hover:bg-brand-50 rounded-lg transition-colors">Dairy</NuxtLink>
        <NuxtLink to="/category/snacks" class="px-3 py-1.5 text-sm font-medium text-ink-600 hover:text-brand-600 hover:bg-brand-50 rounded-lg transition-colors">Snacks</NuxtLink>
        <NuxtLink to="/category/personal-care" class="px-3 py-1.5 text-sm font-medium text-ink-600 hover:text-brand-600 hover:bg-brand-50 rounded-lg transition-colors">Personal Care</NuxtLink>
        <NuxtLink to="/category/household" class="px-3 py-1.5 text-sm font-medium text-ink-600 hover:text-brand-600 hover:bg-brand-50 rounded-lg transition-colors">Household</NuxtLink>
        <NuxtLink to="/category/bakery" class="px-3 py-1.5 text-sm font-medium text-ink-600 hover:text-brand-600 hover:bg-brand-50 rounded-lg transition-colors">Bakery</NuxtLink>
        <NuxtLink to="/category/fresh-produce" class="px-3 py-1.5 text-sm font-medium text-ink-600 hover:text-brand-600 hover:bg-brand-50 rounded-lg transition-colors">Fresh Produce</NuxtLink>
      </nav>
    </div>

    <!-- Mobile search -->
    <div v-if="showSearch" class="md:hidden px-4 pb-3 animate-fade-in">
      <form @submit.prevent="goToSearch" class="relative">
        <input
          v-model="searchQuery"
          type="text"
          placeholder="Search products..."
          class="w-full pl-10 pr-4 py-2.5 rounded-xl bg-ink-50 border border-ink-200 focus:border-brand-500 focus:bg-white focus:ring-2 focus:ring-brand-100 outline-none transition-all text-sm"
          autofocus
        />
        <svg class="w-5 h-5 text-ink-400 absolute left-3 top-1/2 -translate-y-1/2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
        </svg>
      </form>
    </div>
  </header>
</template>
