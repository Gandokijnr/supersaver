<script setup lang="ts">
import type { CatalogItem, Category } from '~/lib/types'

const route = useRoute()
const branchStore = useBranchStore()
const { fetchByCategory, fetchCategories } = useCatalog()

const products = ref<CatalogItem[]>([])
const categories = ref<Category[]>([])
const loading = ref(true)
const error = ref('')
const sortBy = ref('relevance')
const priceFilter = ref<string>('all')

const categorySlug = computed(() => route.params.slug as string)
const currentCategory = computed(() => categories.value.find(c => c.slug === categorySlug.value))

const filtered = computed(() => {
  let result = [...products.value]
  if (priceFilter.value === 'low') result.sort((a, b) => a.selling_price - b.selling_price)
  else if (priceFilter.value === 'high') result.sort((a, b) => b.selling_price - a.selling_price)
  else if (priceFilter.value === 'discount') result.sort((a, b) => (b.discount_percent || 0) - (a.discount_percent || 0))
  return result
})

onMounted(async () => {
  if (!branchStore.currentBranch) { loading.value = false; return }
  try {
    const [prods, cats] = await Promise.all([
      fetchByCategory(branchStore.currentBranch.id, categorySlug.value),
      fetchCategories(),
    ])
    products.value = prods
    categories.value = cats
  } catch { error.value = 'Could not load products.' } finally { loading.value = false }
})

watch(categorySlug, async () => {
  if (!branchStore.currentBranch) return
  loading.value = true
  products.value = await fetchByCategory(branchStore.currentBranch.id, categorySlug.value)
  loading.value = false
})
</script>

<template>
  <div class="max-w-7xl mx-auto px-4 py-6 md:py-10">
    <nav class="flex items-center gap-2 text-sm text-ink-400 mb-4">
      <NuxtLink to="/" class="hover:text-brand-600">Home</NuxtLink>
      <span>/</span>
      <span class="text-ink-600 font-medium capitalize">{{ currentCategory?.name || categorySlug }}</span>
    </nav>

    <div class="flex items-center justify-between mb-6">
      <div>
        <h1 class="text-2xl font-bold text-ink-800 capitalize">{{ currentCategory?.name || categorySlug }}</h1>
        <p class="text-sm text-ink-400 mt-1">{{ branchStore.currentBranch?.name }} · {{ loading ? '...' : filtered.length }} products</p>
      </div>
      <select v-model="priceFilter" class="input w-auto text-sm py-2">
        <option value="all">Sort: Relevance</option>
        <option value="low">Price: Low to High</option>
        <option value="high">Price: High to Low</option>
        <option value="discount">Highest Discount</option>
      </select>
    </div>

    <!-- Category pills -->
    <div class="flex gap-2 overflow-x-auto no-scrollbar pb-3 mb-6">
      <NuxtLink v-for="cat in categories" :key="cat.id" :to="`/category/${cat.slug}`"
        class="px-4 py-2 rounded-full text-sm font-medium whitespace-nowrap transition-colors"
        :class="cat.slug === categorySlug ? 'bg-brand-600 text-white' : 'bg-white text-ink-600 hover:bg-ink-100'">
        {{ cat.name }}
      </NuxtLink>
    </div>

    <div v-if="loading" class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-3">
      <ProductCardSkeleton v-for="n in 10" :key="n" />
    </div>
    <div v-else-if="error" class="card p-8 text-center text-ink-600">{{ error }}</div>
    <div v-else-if="filtered.length === 0" class="card p-10 text-center">
      <div class="text-5xl mb-4">📦</div>
      <h2 class="text-lg font-bold text-ink-800">No products in this category at your branch</h2>
      <p class="text-ink-500 mt-2">Try selecting a different branch or browsing other categories.</p>
      <NuxtLink to="/" class="btn-primary inline-block mt-4">Back to Home</NuxtLink>
    </div>
    <div v-else class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-3">
      <ProductCard v-for="product in filtered" :key="product.id" :product="product" />
    </div>
  </div>
</template>
