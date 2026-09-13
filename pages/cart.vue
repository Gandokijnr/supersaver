<script setup lang="ts">
import { formatNaira } from '~/lib/format'

const cartStore = useCartStore()
const branchStore = useBranchStore()
const router = useRouter()

const deliveryFee = computed(() => branchStore.currentBranch?.delivery_fee ?? 0)
const total = computed(() => cartStore.subtotal + deliveryFee.value)
const freeDeliveryThreshold = computed(() => 30000)
const amountToFreeDelivery = computed(() => Math.max(0, freeDeliveryThreshold.value - cartStore.subtotal))

async function changeQty(itemId: string, delta: number, currentQty: number, stock: number) {
  const newQty = currentQty + delta
  if (newQty < 1) return
  try {
    await cartStore.updateQuantity(itemId, newQty, stock)
  } catch (e: any) {
    alert(e.message)
  }
}

async function remove(itemId: string) {
  try {
    await cartStore.removeItem(itemId)
  } catch (e: any) {
    alert(e.message)
  }
}

function checkout() {
  router.push('/checkout')
}
</script>

<template>
  <div class="max-w-5xl mx-auto px-4 py-6 md:py-10">
    <h1 class="text-2xl font-bold text-ink-800 mb-6">Your Cart</h1>

    <div v-if="cartStore.loading" class="space-y-3">
      <div v-for="n in 3" :key="n" class="card p-4 flex gap-4">
        <div class="w-20 h-20 skeleton rounded-xl" />
        <div class="flex-1 space-y-2"><div class="h-4 w-1/2 skeleton" /><div class="h-4 w-1/4 skeleton" /><div class="h-8 w-32 skeleton" /></div>
      </div>
    </div>

    <div v-else-if="cartStore.items.length === 0" class="card p-10 text-center">
      <div class="text-6xl mb-4">🛒</div>
      <h2 class="text-xl font-bold text-ink-800">Your cart is empty</h2>
      <p class="text-ink-500 mt-2">Let's get your groceries sorted.</p>
      <NuxtLink to="/" class="btn-primary inline-block mt-6">Start Shopping</NuxtLink>
    </div>

    <div v-else class="grid md:grid-cols-3 gap-6">
      <div class="md:col-span-2 space-y-3">
        <div v-for="item in cartStore.items" :key="item.id" class="card p-4 flex gap-4 items-center">
          <NuxtLink :to="`/product/${item.product.slug}`" class="shrink-0">
            <img :src="item.product.image_url || ''" :alt="item.product.name" class="w-20 h-20 rounded-xl object-cover bg-ink-50" />
          </NuxtLink>
          <div class="flex-1 min-w-0">
            <NuxtLink :to="`/product/${item.product.slug}`" class="font-semibold text-ink-800 text-sm line-clamp-2 hover:text-brand-600">{{ item.product.name }}</NuxtLink>
            <p class="text-sm font-bold text-ink-900 mt-1">{{ formatNaira(Number(item.unit_price)) }}</p>
            <p v-if="Number(item.branch_product.stock_quantity) <= 5" class="text-xs text-accent-600 mt-0.5">Only {{ item.branch_product.stock_quantity }} left</p>
          </div>
          <div class="flex flex-col items-end gap-2">
            <div class="flex items-center gap-2 bg-ink-50 rounded-xl p-1">
              <button @click="changeQty(item.id, -1, Number(item.quantity), Number(item.branch_product.stock_quantity))" class="w-7 h-7 rounded-lg bg-white text-ink-600 hover:bg-ink-100 flex items-center justify-center font-bold">−</button>
              <span class="w-8 text-center font-semibold text-sm">{{ item.quantity }}</span>
              <button @click="changeQty(item.id, 1, Number(item.quantity), Number(item.branch_product.stock_quantity))" class="w-7 h-7 rounded-lg bg-white text-ink-600 hover:bg-ink-100 flex items-center justify-center font-bold">+</button>
            </div>
            <button @click="remove(item.id)" class="text-xs text-ink-400 hover:text-accent-600">Remove</button>
          </div>
        </div>
      </div>

      <div class="md:col-span-1">
        <div class="card p-5 sticky top-24">
          <h3 class="font-bold text-ink-800 mb-4">Order Summary</h3>
          <div class="space-y-2 text-sm">
            <div class="flex justify-between"><span class="text-ink-500">Subtotal ({{ cartStore.itemCount }} items)</span><span class="font-semibold">{{ formatNaira(cartStore.subtotal) }}</span></div>
            <div class="flex justify-between"><span class="text-ink-500">Delivery</span><span class="font-semibold">{{ formatNaira(deliveryFee) }}</span></div>
            <div v-if="amountToFreeDelivery > 0" class="bg-brand-50 text-brand-700 rounded-xl p-3 text-xs font-medium mt-3">
              Add {{ formatNaira(amountToFreeDelivery) }} more to unlock free delivery
            </div>
            <div class="border-t border-ink-100 pt-3 mt-3 flex justify-between text-base"><span class="font-bold text-ink-800">Total</span><span class="font-bold text-brand-700">{{ formatNaira(total) }}</span></div>
          </div>
          <button @click="checkout" class="btn-primary w-full mt-5">Checkout</button>
          <NuxtLink to="/" class="btn-outline w-full text-center block mt-2">Continue Shopping</NuxtLink>
        </div>
      </div>
    </div>
  </div>
</template>
