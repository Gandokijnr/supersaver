<script setup lang="ts">
import { formatNaira } from '~/lib/format'
import type { OrderResult } from '~/lib/types'

const cartStore = useCartStore()
const branchStore = useBranchStore()
const router = useRouter()

const name = ref('')
const phone = ref('')
const email = ref('')
const address = ref('')
const instructions = ref('')
const placing = ref(false)
const errorMsg = ref('')
const { profile, restore: restoreProfile } = useCustomerProfile()
const { user } = useCustomerAuth()
watch(() => user.value?.id, () => {
  name.value = ''; phone.value = ''; email.value = ''; address.value = ''
})

onMounted(async () => {
  try { await restoreProfile() } catch { errorMsg.value = 'Saved profile could not be loaded. Enter your delivery details below.' }
  name.value = profile.value.name
  phone.value = profile.value.phone
  email.value = profile.value.email
  address.value = profile.value.address
})

const deliveryFee = computed(() => branchStore.currentBranch?.delivery_fee ?? 0)
const total = computed(() => cartStore.subtotal + deliveryFee.value)

async function placeOrder() {
  errorMsg.value = ''
  if (!name.value || !phone.value || !address.value) {
    errorMsg.value = 'Please fill in your name, phone number, and delivery address.'
    return
  }
  if (!branchStore.currentBranch) {
    errorMsg.value = 'Please select a branch first.'
    return
  }
  placing.value = true
  try {
    const { data, error } = await useSupabase().rpc('create_order', {
      p_session_id: cartStore.sessionId,
      p_branch_id: branchStore.currentBranch.id,
      p_delivery_address: address.value,
      p_customer_name: name.value,
      p_customer_phone: phone.value,
      p_customer_email: email.value || null,
      p_delivery_instructions: instructions.value || null,
    })
    if (error) throw error
    const result = data as OrderResult
    await cartStore.loadItems()
    router.push(`/order/${result.order_number}`)
  } catch (e: any) {
    errorMsg.value = e.message || 'Could not place your order. Please try again.'
  } finally {
    placing.value = false
  }
}
</script>

<template>
  <div class="max-w-5xl mx-auto px-4 py-6 md:py-10">
    <h1 class="text-2xl font-bold text-ink-800 mb-6">Checkout</h1>
    <p v-if="!user" class="card p-4 mb-4 text-sm text-ink-600"><NuxtLink to="/account?next=/checkout" class="text-brand-600 font-semibold">Sign in or create an account</NuxtLink> before ordering to track this order across devices.</p>

    <div v-if="cartStore.items.length === 0 && !placing" class="card p-10 text-center">
      <p class="text-ink-500">Your cart is empty.</p>
      <NuxtLink to="/" class="btn-primary inline-block mt-4">Start Shopping</NuxtLink>
    </div>

    <div v-else class="grid md:grid-cols-3 gap-6">
      <div class="md:col-span-2 space-y-4">
        <div class="card p-5">
          <h3 class="font-bold text-ink-800 mb-4">Delivery Details</h3>
          <div class="grid sm:grid-cols-2 gap-3">
            <div><label class="text-sm font-medium text-ink-600 mb-1 block">Full name *</label><input v-model="name" class="input" placeholder="John Doe" /></div>
            <div><label class="text-sm font-medium text-ink-600 mb-1 block">Phone number *</label><input v-model="phone" class="input" placeholder="0801 234 5678" /></div>
          </div>
          <div class="mt-3"><label class="text-sm font-medium text-ink-600 mb-1 block">Email (optional)</label><input v-model="email" class="input" placeholder="you@email.com" /></div>
          <div class="mt-3"><label class="text-sm font-medium text-ink-600 mb-1 block">Delivery address *</label><textarea v-model="address" class="input" rows="3" placeholder="House number, street name, area, landmark" /></div>
          <div class="mt-3"><label class="text-sm font-medium text-ink-600 mb-1 block">Delivery instructions (optional)</label><textarea v-model="instructions" class="input" rows="2" placeholder="e.g. Call on arrival" /></div>
        </div>

        <div class="card p-5">
          <h3 class="font-bold text-ink-800 mb-3">Payment Method</h3>
          <div class="space-y-2">
            <label class="flex items-center gap-3 p-3 rounded-xl border border-brand-500 bg-brand-50 cursor-pointer">
              <input type="radio" checked class="accent-brand-600" />
              <div><p class="font-semibold text-sm text-ink-800">Pay on Delivery</p><p class="text-xs text-ink-500">Pay with cash or card when your order arrives</p></div>
            </label>
            <label class="flex items-center gap-3 p-3 rounded-xl border border-ink-200 cursor-pointer opacity-60">
              <input type="radio" disabled class="accent-brand-600" />
              <div><p class="font-semibold text-sm text-ink-600">Paystack (coming soon)</p><p class="text-xs text-ink-400">Online payment</p></div>
            </label>
          </div>
        </div>

        <p v-if="errorMsg" class="text-sm text-accent-600 font-medium bg-accent-50 rounded-xl p-3">{{ errorMsg }}</p>
      </div>

      <div class="md:col-span-1">
        <div class="card p-5 sticky top-24">
          <h3 class="font-bold text-ink-800 mb-4">Order Summary</h3>
          <div class="space-y-2 max-h-48 overflow-y-auto text-sm mb-4">
            <div v-for="item in cartStore.items" :key="item.id" class="flex justify-between gap-2">
              <span class="text-ink-500 truncate">{{ item.product.name }} ×{{ item.quantity }}</span>
              <span class="font-semibold whitespace-nowrap">{{ formatNaira(Number(item.unit_price) * Number(item.quantity)) }}</span>
            </div>
          </div>
          <div class="space-y-2 text-sm border-t border-ink-100 pt-3">
            <div class="flex justify-between"><span class="text-ink-500">Subtotal</span><span class="font-semibold">{{ formatNaira(cartStore.subtotal) }}</span></div>
            <div class="flex justify-between"><span class="text-ink-500">Delivery</span><span class="font-semibold">{{ formatNaira(deliveryFee) }}</span></div>
            <div class="border-t border-ink-100 pt-3 flex justify-between text-base"><span class="font-bold text-ink-800">Total</span><span class="font-bold text-brand-700">{{ formatNaira(total) }}</span></div>
          </div>
          <button @click="placeOrder" :disabled="placing" class="btn-primary w-full mt-5 disabled:opacity-60">
            {{ placing ? 'Placing order...' : 'Place Order' }}
          </button>
          <p class="text-xs text-ink-400 text-center mt-3">Shopping from {{ branchStore.currentBranch?.name }}</p>
        </div>
      </div>
    </div>
  </div>
</template>
