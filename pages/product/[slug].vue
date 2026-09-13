<script setup lang="ts">
import { formatNaira } from '~/lib/format'
import type { CatalogItem } from '~/lib/types'

const route = useRoute()
const branchStore = useBranchStore()
const { fetchProductBySlug, fetchBranchProducts } = useCatalog()
const cartStore = useCartStore()

const product = ref<CatalogItem | null>(null)
const related = ref<CatalogItem[]>([])
const loading = ref(true)
const error = ref('')
const quantity = ref(1)
const adding = ref(false)
const justAdded = ref(false)
const addError = ref('')

onMounted(async () => {
  if (!branchStore.currentBranch) { loading.value = false; return }
  try {
    const slug = route.params.slug as string
    const p = await fetchProductBySlug(branchStore.currentBranch.id, slug)
    if (!p) { error.value = 'This product is not available at your selected branch.'; loading.value = false; return }
    product.value = p
    const all = await fetchBranchProducts(branchStore.currentBranch.id, 200)
    related.value = all.filter(x => x.category_slug === p.category_slug && x.id !== p.id).slice(0, 4)
  } catch { error.value = 'Could not load this product.' } finally { loading.value = false }
})

async function addToCart() {
  if (!product.value) return
  adding.value = true; addError.value = ''
  try {
    await cartStore.addToCart(product.value, quantity.value)
    justAdded.value = true; setTimeout(() => justAdded.value = false, 2000)
  } catch (e: any) { addError.value = e.message } finally { adding.value = false }
}

function buyNow() {
  if (!product.value) return
  addToCart().then(() => { if (!addError.value) navigateTo('/cart') })
}

const lowStock = computed(() => product.value && product.value.stock_quantity <= 5)
</script>

<template>
  <div class="max-w-6xl mx-auto px-4 py-6 md:py-10">
    <div v-if="loading" class="grid md:grid-cols-2 gap-8">
      <div class="aspect-square skeleton rounded-2xl" />
      <div class="space-y-4"><div class="h-6 w-1/3 skeleton" /><div class="h-8 w-3/4 skeleton" /><div class="h-6 w-1/2 skeleton" /><div class="h-12 w-full skeleton" /></div>
    </div>
    <div v-else-if="error" class="card p-10 text-center">
      <div class="text-5xl mb-4">🔍</div>
      <h2 class="text-xl font-bold text-ink-800">{{ error }}</h2>
      <NuxtLink to="/" class="btn-primary inline-block mt-4">Back to Home</NuxtLink>
    </div>
    <div v-else-if="product" class="animate-fade-in">
      <div class="grid md:grid-cols-2 gap-8">
        <div class="card overflow-hidden rounded-2xl">
          <img :src="product.image_url || ''" :alt="product.name" class="w-full aspect-square object-cover" />
        </div>
        <div>
          <p v-if="product.brand_name" class="text-sm text-ink-400 font-medium">{{ product.brand_name }}</p>
          <h1 class="text-2xl md:text-3xl font-extrabold text-ink-800 mt-1">{{ product.name }}</h1>
          <p v-if="product.unit" class="text-ink-500 mt-1">{{ product.unit }}</p>

          <div class="flex items-baseline gap-3 mt-4">
            <span class="text-3xl font-extrabold text-ink-900">{{ formatNaira(product.selling_price) }}</span>
            <span v-if="product.compare_at_price" class="text-lg text-ink-400 line-through">{{ formatNaira(product.compare_at_price) }}</span>
            <span v-if="product.discount_percent" class="badge bg-accent-100 text-accent-700">{{ product.discount_percent }}% OFF</span>
          </div>

          <div class="mt-3 flex items-center gap-2">
            <span v-if="product.stock_quantity > 0" class="badge bg-brand-50 text-brand-700">In stock</span>
            <span v-else class="badge bg-red-50 text-red-700">Out of stock</span>
            <span v-if="lowStock && product.stock_quantity > 0" class="text-xs text-accent-600 font-semibold">Only {{ product.stock_quantity }} left</span>
          </div>

          <p class="text-sm text-ink-600 mt-2 flex items-center gap-1">
            <svg class="w-4 h-4 text-brand-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" /><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" /></svg>
            Available at {{ branchStore.currentBranch?.name }}
          </p>

          <div class="mt-6 flex items-center gap-3">
            <div class="flex items-center gap-2 bg-ink-50 rounded-xl p-1">
              <button @click="quantity = Math.max(1, quantity - 1)" class="w-9 h-9 rounded-lg bg-white text-ink-600 hover:bg-ink-100 flex items-center justify-center font-bold">−</button>
              <span class="w-10 text-center font-semibold">{{ quantity }}</span>
              <button @click="quantity = Math.min(product.stock_quantity, quantity + 1)" class="w-9 h-9 rounded-lg bg-white text-ink-600 hover:bg-ink-100 flex items-center justify-center font-bold">+</button>
            </div>
            <button @click="addToCart" :disabled="adding || product.stock_quantity <= 0" class="btn-primary flex-1 disabled:opacity-50">
              {{ justAdded ? 'Added to Cart ✓' : adding ? 'Adding...' : 'Add to Cart' }}
            </button>
          </div>
          <button @click="buyNow" :disabled="product.stock_quantity <= 0" class="btn-accent w-full mt-2 disabled:opacity-50">Buy Now</button>
          <p v-if="addError" class="text-sm text-accent-600 mt-2">{{ addError }}</p>

          <div v-if="product.description" class="mt-8">
            <h3 class="font-bold text-ink-800 mb-2">Description</h3>
            <p class="text-sm text-ink-600 leading-relaxed">{{ product.description }}</p>
          </div>
        </div>
      </div>

      <section v-if="related.length" class="mt-12">
        <SectionHeader title="Related products" />
        <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
          <ProductCard v-for="p in related" :key="p.id" :product="p" />
        </div>
      </section>
    </div>
  </div>
</template>
