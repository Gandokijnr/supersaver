<script setup lang="ts">
import type { CatalogItem } from '~/lib/types'

const route = useRoute()
const router = useRouter()
const branchStore = useBranchStore()
const { searchProducts } = useCatalog()

const query = ref((route.query.q as string) || '')
const results = ref<CatalogItem[]>([])
const loading = ref(false)
const error = ref('')
const searchInput = ref(query.value)

async function doSearch() {
  if (!branchStore.currentBranch || !query.value.trim()) { results.value = []; return }
  loading.value = true; error.value = ''
  try {
    results.value = await searchProducts(branchStore.currentBranch.id, query.value)
  } catch { error.value = 'Search failed. Please try again.' } finally { loading.value = false }
}

onMounted(doSearch)
watch(() => route.query.q, (q) => { query.value = (q as string) || ''; searchInput.value = query.value; doSearch() })

function submitSearch() {
  router.push(`/search?q=${encodeURIComponent(searchInput.value.trim())}`)
}
</script>

<template>
  <div class="max-w-7xl mx-auto px-4 py-6 md:py-10">
    <div class="relative mb-6">
      <input v-model="searchInput" @keyup.enter="submitSearch" type="text" placeholder="Search products, brands, categories..."
        class="w-full pl-10 pr-4 py-3 rounded-xl bg-white border border-ink-200 focus:border-brand-500 focus:ring-2 focus:ring-brand-100 outline-none transition-all" />
      <svg class="w-5 h-5 text-ink-400 absolute left-3 top-1/2 -translate-y-1/2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" /></svg>
    </div>

    <div v-if="query">
      <h1 class="text-lg font-bold text-ink-800 mb-4">Results for "{{ query }}" — {{ loading ? '...' : results.length }} found at {{ branchStore.currentBranch?.name }}</h1>

      <div v-if="loading" class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-3">
        <ProductCardSkeleton v-for="n in 10" :key="n" />
      </div>
      <div v-else-if="error" class="card p-8 text-center text-ink-600">{{ error }}</div>
      <div v-else-if="results.length === 0" class="card p-10 text-center">
        <div class="text-5xl mb-4">🔍</div>
        <h2 class="text-lg font-bold text-ink-800">No products found for "{{ query }}"</h2>
        <p class="text-ink-500 mt-2">Try checking your spelling, using fewer words, or browsing categories.</p>
        <NuxtLink to="/" class="btn-primary inline-block mt-4">Browse Categories</NuxtLink>
      </div>
      <div v-else class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-3">
        <ProductCard v-for="product in results" :key="product.id" :product="product" />
      </div>
    </div>

    <div v-else class="card p-10 text-center">
      <div class="text-5xl mb-4">🔍</div>
      <h2 class="text-lg font-bold text-ink-800">Search for products</h2>
      <p class="text-ink-500 mt-2">Start typing to find groceries, beverages, household items and more at your branch.</p>
    </div>
  </div>
</template>
