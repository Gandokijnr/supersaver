<script setup lang="ts">
import type { CatalogItem } from '~/lib/types'
import { formatNaira } from '~/lib/format'

const props = defineProps<{ product: CatalogItem }>()
const cartStore = useCartStore()
const adding = ref(false)
const justAdded = ref(false)
const errorMsg = ref('')

async function quickAdd() {
  adding.value = true
  errorMsg.value = ''
  try {
    await cartStore.addToCart(props.product, 1)
    justAdded.value = true
    setTimeout(() => (justAdded.value = false), 1500)
  } catch (e: any) {
    errorMsg.value = e.message || 'Could not add to cart'
    setTimeout(() => (errorMsg.value = ''), 3000)
  } finally {
    adding.value = false
  }
}

const lowStock = computed(() => props.product.stock_quantity <= 5 && props.product.stock_quantity > 0)
const outOfStock = computed(() => props.product.stock_quantity <= 0)
</script>

<template>
  <div class="card overflow-hidden group hover:shadow-md transition-shadow duration-200 flex flex-col">
    <NuxtLink :to="`/product/${product.slug}`" class="relative block aspect-square bg-ink-50 overflow-hidden">
      <img
        :src="product.image_url || 'https://images.pexels.com/photos/264636/pexels-photo-264636.jpeg?auto=compress&cs=tinysrgb&w=400'"
        :alt="product.name"
        loading="lazy"
        class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
      />
      <span
        v-if="product.discount_percent"
        class="absolute top-2 left-2 bg-accent-500 text-white text-xs font-bold px-2 py-1 rounded-lg shadow-sm"
      >{{ product.discount_percent }}% OFF</span>
      <span
        v-if="lowStock"
        class="absolute bottom-2 left-2 bg-ink-900/80 text-white text-[10px] font-semibold px-2 py-0.5 rounded-md"
      >Only {{ product.stock_quantity }} left</span>
    </NuxtLink>

    <div class="p-3 flex flex-col flex-1">
      <p v-if="product.brand_name" class="text-[11px] text-ink-400 font-medium mb-0.5">{{ product.brand_name }}</p>
      <NuxtLink :to="`/product/${product.slug}`" class="text-sm font-semibold text-ink-800 leading-snug line-clamp-2 hover:text-brand-600 transition-colors">
        {{ product.name }}
      </NuxtLink>
      <p v-if="product.unit" class="text-xs text-ink-400 mt-0.5">{{ product.unit }}</p>

      <div class="mt-2 flex items-baseline gap-1.5">
        <span class="text-base font-bold text-ink-900">{{ formatNaira(product.selling_price) }}</span>
        <span v-if="product.compare_at_price" class="text-xs text-ink-400 line-through">{{ formatNaira(product.compare_at_price) }}</span>
      </div>

      <div class="mt-2 flex-1" />

      <div class="relative">
        <button
          @click="quickAdd"
          :disabled="adding || outOfStock"
          class="w-full py-2 rounded-xl font-semibold text-sm transition-all active:scale-95 flex items-center justify-center gap-1.5"
          :class="justAdded
            ? 'bg-brand-600 text-white'
            : outOfStock
              ? 'bg-ink-100 text-ink-400 cursor-not-allowed'
              : 'bg-brand-50 text-brand-700 hover:bg-brand-100'"
        >
          <svg v-if="justAdded" class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7" />
          </svg>
          <svg v-else class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
          </svg>
          {{ justAdded ? 'Added' : outOfStock ? 'Out of stock' : 'Add' }}
        </button>
        <Transition name="fade">
          <p v-if="errorMsg" class="absolute -bottom-5 left-0 right-0 text-center text-[10px] text-accent-600 font-medium">{{ errorMsg }}</p>
        </Transition>
      </div>
    </div>
  </div>
</template>

<style scoped>
.fade-enter-active, .fade-leave-active { transition: opacity 0.3s; }
.fade-enter-from, .fade-leave-to { opacity: 0; }
</style>
