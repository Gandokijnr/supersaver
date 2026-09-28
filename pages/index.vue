<script setup lang="ts">
import type { CatalogItem, CatalogPromotion, Category } from '~/lib/types'

const branchStore = useBranchStore()
const { fetchBranchProducts, fetchCategories, fetchPromotionProducts } = useCatalog()
const promotions = ref<CatalogPromotion[]>([])
const promotionsLoading = ref(true)
const promotionsError = ref('')
const products = ref<CatalogItem[]>([])
const categories = ref<Category[]>([])
const loading = ref(true)
const error = ref('')

const categoryStyles: Record<string, { bg: string; icon: string }> = {
  groceries: { bg: 'bg-amber-50', icon: '🧺' },
  beverages: { bg: 'bg-sky-50', icon: '🥤' },
  dairy: { bg: 'bg-blue-50', icon: '🥛' },
  snacks: { bg: 'bg-orange-50', icon: '🍿' },
  'personal-care': { bg: 'bg-rose-50', icon: '🧴' },
  household: { bg: 'bg-teal-50', icon: '🧹' },
  bakery: { bg: 'bg-yellow-50', icon: '🍞' },
  'fresh-produce': { bg: 'bg-lime-50', icon: '🥬' },
}

const branchName = computed(() => branchStore.currentBranch?.name.replace('Supersaver ', '') || '')
const flashDeals = computed(() => products.value.filter(p => p.discount_percent && p.discount_percent >= 15).slice(0, 6))
const bestSellers = computed(() => products.value.slice(0, 8))
const essentials = computed(() => products.value.filter(p => ['groceries', 'dairy', 'bakery'].includes(p.category_slug || '')).slice(0, 8))

onMounted(async () => {
  if (!branchStore.currentBranch) return
  try {
    const [productData, categoryData] = await Promise.all([
      fetchBranchProducts(branchStore.currentBranch.id, 200),
      fetchCategories(),
    ])
    products.value = productData
    categories.value = categoryData
  } catch {
    error.value = 'We could not load the store right now. Please refresh and try again.'
  } finally {
    loading.value = false
  }
})

let promotionRequest = 0
async function loadPromotions() {
  const request = ++promotionRequest
  const branchId = branchStore.currentBranch?.id
  promotions.value = []
  promotionsError.value = ''
  promotionsLoading.value = !!branchId
  if (!branchId) return
  try {
    const items = await fetchPromotionProducts(branchId)
    if (request === promotionRequest) promotions.value = items
  } catch {
    if (request === promotionRequest) promotionsError.value = 'We could not load promotions. Please try again.'
  } finally {
    if (request === promotionRequest) promotionsLoading.value = false
  }
}

onMounted(loadPromotions)
watch(() => branchStore.currentBranch?.id, loadPromotions)
</script>

<template>
  <div>
    <!-- Hero -->
    <section class="bg-brand-700 text-white overflow-hidden">
      <div class="max-w-7xl mx-auto px-4 py-10 md:py-16 relative">
        <div class="max-w-xl relative z-10">
          <span class="inline-flex items-center gap-2 bg-white/10 text-brand-100 text-xs font-semibold px-3 py-1.5 rounded-full mb-5">
            <span class="w-2 h-2 bg-brand-300 rounded-full animate-pulse" />
            Shopping from {{ branchName }} Branch
          </span>
          <h1 class="text-3xl md:text-5xl font-extrabold leading-tight tracking-tight">Fresh groceries.<br /><span class="text-brand-300">Better prices.</span><br />Delivered.</h1>
          <p class="text-brand-100 mt-5 text-sm md:text-base max-w-md leading-relaxed">Everything your home needs, handpicked from your nearest Supersaver branch and delivered to your door.</p>
          <div class="flex flex-wrap gap-3 mt-7">
            <NuxtLink to="/category/groceries" class="bg-white text-brand-700 font-bold px-5 py-3 rounded-xl hover:bg-brand-50 transition-colors">Shop groceries</NuxtLink>
            <NuxtLink to="/category/fresh-produce" class="border border-white/30 text-white font-semibold px-5 py-3 rounded-xl hover:bg-white/10 transition-colors">Fresh produce</NuxtLink>
          </div>
        </div>
        <div class="absolute -right-20 -bottom-32 md:right-0 md:-bottom-44 w-96 h-96 md:w-[34rem] md:h-[34rem] rounded-full bg-brand-600/50" />
        <div class="hidden md:flex absolute right-20 top-12 w-64 h-64 rounded-full bg-brand-500/30 items-center justify-center rotate-6">
          <div class="w-48 h-48 rounded-full bg-brand-400/20 flex items-center justify-center -rotate-6">
            <span class="text-8xl">🛒</span>
          </div>
        </div>
      </div>
    </section>

    <div class="max-w-7xl mx-auto px-4 py-8 md:py-10 space-y-10">
      <!-- Trust strip -->
      <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div class="card p-4 flex items-center gap-3"><div class="w-9 h-9 rounded-lg bg-brand-50 flex items-center justify-center text-brand-600">✓</div><div><p class="font-semibold text-sm text-ink-800">Authentic products</p><p class="text-xs text-ink-400">Quality guaranteed</p></div></div>
        <div class="card p-4 flex items-center gap-3"><div class="w-9 h-9 rounded-lg bg-sky-50 flex items-center justify-center text-sky-600">⌁</div><div><p class="font-semibold text-sm text-ink-800">Fast delivery</p><p class="text-xs text-ink-400">Across Lagos</p></div></div>
        <div class="card p-4 flex items-center gap-3"><div class="w-9 h-9 rounded-lg bg-amber-50 flex items-center justify-center text-amber-600">₦</div><div><p class="font-semibold text-sm text-ink-800">Great prices</p><p class="text-xs text-ink-400">Every day savings</p></div></div>
        <div class="card p-4 flex items-center gap-3"><div class="w-9 h-9 rounded-lg bg-rose-50 flex items-center justify-center text-rose-600">♡</div><div><p class="font-semibold text-sm text-ink-800">Easy shopping</p><p class="text-xs text-ink-400">Made for you</p></div></div>
      </div>

      <!-- Categories -->
      <section>
        <SectionHeader title="Shop by category" link="/categories" />
        <div class="grid grid-cols-4 md:grid-cols-8 gap-3">
          <NuxtLink v-for="category in categories" :key="category.id" :to="`/category/${category.slug}`" class="group text-center">
            <div :class="categoryStyles[category.slug]?.bg || 'bg-ink-100'" class="aspect-square rounded-2xl flex items-center justify-center text-3xl md:text-4xl group-hover:scale-105 transition-transform">
              {{ categoryStyles[category.slug]?.icon || '🛍️' }}
            </div>
            <p class="text-xs md:text-sm font-semibold text-ink-700 mt-2 leading-tight">{{ category.name }}</p>
          </NuxtLink>
        </div>
      </section>

      <!-- Promotions -->
      <div v-if="promotionsLoading" aria-label="Loading promotions" aria-busy="true">
        <div class="skeleton h-7 w-48 rounded mb-4" />
        <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-6 gap-3">
          <ProductCardSkeleton v-for="n in 6" :key="n" />
        </div>
      </div>
      <p v-else-if="promotionsError" role="alert" class="card p-5 text-sm text-ink-600">
          {{ promotionsError }} <button class="font-semibold underline" @click="loadPromotions">Retry</button>
      </p>
      <section v-for="promotion in promotions" :key="promotion.id">
        <SectionHeader :title="promotion.name" />
        <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-6 gap-3">
          <ProductCard v-for="product in promotion.products" :key="product.id" :product="product" />
        </div>
      </section>

      <!-- Flash deals -->
      <section v-if="loading || flashDeals.length">
        <SectionHeader title="Flash deals" link="/category/groceries" link-text="View all deals" />
        <div v-if="loading" class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-6 gap-3"><ProductCardSkeleton v-for="n in 6" :key="n" /></div>
        <div v-else class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-6 gap-3"><ProductCard v-for="product in flashDeals" :key="product.id" :product="product" /></div>
      </section>

      <!-- Banner -->
      <section class="rounded-2xl bg-accent-50 border border-accent-100 p-6 md:p-8 flex items-center justify-between overflow-hidden relative">
        <div class="relative z-10"><p class="text-accent-700 text-xs font-bold uppercase tracking-wider">Stock up & save</p><h2 class="text-xl md:text-2xl font-extrabold text-ink-900 mt-1">Everyday essentials,<br />at everyday prices.</h2><NuxtLink to="/category/groceries" class="inline-block mt-4 text-sm font-bold text-accent-700 hover:text-accent-800">Explore essentials →</NuxtLink></div>
        <div class="text-7xl md:text-9xl opacity-80 -mr-4 md:mr-8">🧺</div>
      </section>

      <!-- Best sellers -->
      <section>
        <SectionHeader title="Popular in your branch" link="/category/groceries" />
        <div v-if="loading" class="grid grid-cols-2 sm:grid-cols-4 md:grid-cols-8 gap-3"><ProductCardSkeleton v-for="n in 8" :key="n" /></div>
        <div v-else class="grid grid-cols-2 sm:grid-cols-4 md:grid-cols-8 gap-3"><ProductCard v-for="product in bestSellers" :key="product.id" :product="product" /></div>
      </section>

      <!-- Essentials -->
      <section>
        <SectionHeader title="Everyday essentials" />
        <div v-if="loading" class="grid grid-cols-2 sm:grid-cols-4 md:grid-cols-8 gap-3"><ProductCardSkeleton v-for="n in 8" :key="n" /></div>
        <div v-else class="grid grid-cols-2 sm:grid-cols-4 md:grid-cols-8 gap-3"><ProductCard v-for="product in essentials" :key="product.id" :product="product" /></div>
      </section>

      <div v-if="error" class="card p-8 text-center text-ink-600">{{ error }}</div>
    </div>
  </div>
</template>
