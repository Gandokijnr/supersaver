<script setup lang="ts">
import type { Branch } from '~/lib/types'
import { formatNaira } from '~/lib/format'

definePageMeta({ layout: false })

const supabase = useSupabase()
const branchStore = useBranchStore()
const router = useRouter()
const loading = ref(true)
const error = ref('')
const selecting = ref<string | null>(null)
const branches = ref<Branch[]>([])

onMounted(async () => {
  loading.value = true
  error.value = ''
  try {
    const { data, error: queryError } = await supabase
      .from('branches')
      .select('*')
      .eq('is_active', true)
      .order('sort_order')
    if (queryError) throw queryError
    branches.value = (data || []) as Branch[]
  } catch (e: any) {
    error.value = e?.message || 'We could not load the branch list. Please try again.'
  } finally {
    loading.value = false
  }
})

async function chooseBranch(branch: Branch) {
  selecting.value = branch.id
  branchStore.setBranch(branch)
  await router.push('/')
  selecting.value = null
}

async function retry() {
  loading.value = true
  error.value = ''
  try {
    const { data, error: queryError } = await supabase
      .from('branches')
      .select('*')
      .eq('is_active', true)
      .order('sort_order')
    if (queryError) throw queryError
    branches.value = (data || []) as Branch[]
  } catch (e: any) {
    error.value = e?.message || 'We could not load the branch list. Please try again.'
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="min-h-screen bg-ink-50 flex flex-col">
    <!-- Hero header -->
    <div class="bg-brand-700 text-white">
      <div class="max-w-5xl mx-auto px-4 py-5">
        <NuxtLink to="/" class="inline-flex items-center gap-2 mb-6 text-brand-100 hover:text-white transition-colors">
          <div class="w-9 h-9 bg-white/15 rounded-xl flex items-center justify-center">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z" />
            </svg>
          </div>
          <span class="font-extrabold text-lg">Supersaver</span>
        </NuxtLink>
        <div class="pb-8 max-w-2xl">
          <p class="text-brand-200 text-sm font-semibold uppercase tracking-wider mb-2">Your shopping starts here</p>
          <h1 class="text-2xl sm:text-3xl md:text-4xl font-extrabold leading-tight">Where would you like to shop from?</h1>
          <p class="text-brand-100 mt-3 text-sm md:text-base">Select your nearest branch to see products, prices, and delivery options available in your area.</p>
        </div>
      </div>
    </div>

    <!-- Branch list -->
    <div class="max-w-5xl mx-auto px-4 -mt-6 pb-24 flex-1 w-full">
      <!-- Loading -->
      <div v-if="loading" class="grid sm:grid-cols-2 lg:grid-cols-3 gap-4">
        <div v-for="n in 5" :key="n" class="card p-5 space-y-3">
          <div class="h-6 w-3/4 skeleton" /><div class="h-4 w-full skeleton" /><div class="h-4 w-1/2 skeleton" />
        </div>
      </div>

      <!-- Error -->
      <div v-else-if="error" class="card p-8 text-center">
        <div class="w-14 h-14 bg-red-50 rounded-2xl flex items-center justify-center mx-auto mb-4">
          <svg class="w-7 h-7 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
          </svg>
        </div>
        <p class="text-ink-700 font-semibold mb-1">Couldn't load branches</p>
        <p class="text-ink-400 text-sm mb-4">{{ error }}</p>
        <button @click="retry" class="btn-primary text-sm">Try Again</button>
      </div>

      <!-- Empty -->
      <div v-else-if="branches.length === 0" class="card p-8 text-center">
        <div class="w-14 h-14 bg-ink-100 rounded-2xl flex items-center justify-center mx-auto mb-4">
          <svg class="w-7 h-7 text-ink-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 21h18M5 21V5l7-3 7 3v16M9 9h1m4 0h1M9 13h1m4 0h1M9 17h1m4 0h1" />
          </svg>
        </div>
        <p class="text-ink-700 font-semibold">No branches available yet</p>
        <p class="text-ink-400 text-sm mt-1">Please check back soon.</p>
      </div>

      <!-- Branch cards -->
      <div v-else class="grid sm:grid-cols-2 lg:grid-cols-3 gap-4">
        <button
          v-for="branch in branches"
          :key="branch.id"
          @click="chooseBranch(branch)"
          :disabled="selecting === branch.id"
          class="card p-5 text-left hover:border-brand-400 hover:shadow-md transition-all duration-200 group disabled:opacity-70 active:scale-[0.98]"
        >
          <div class="flex items-start justify-between gap-3">
            <div class="w-11 h-11 rounded-xl bg-brand-50 flex items-center justify-center shrink-0 group-hover:bg-brand-100 transition-colors">
              <svg class="w-6 h-6 text-brand-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.8" d="M3 21h18M5 21V5l7-3 7 3v16M9 9h1m4 0h1M9 13h1m4 0h1M9 17h1m4 0h1" />
              </svg>
            </div>
            <svg class="w-5 h-5 text-ink-300 group-hover:text-brand-600 group-hover:translate-x-1 transition-all" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
            </svg>
          </div>
          <h2 class="font-bold text-lg text-ink-800 mt-4">{{ branch.name }}</h2>
          <p class="text-sm text-ink-500 mt-1">{{ branch.address }}</p>
          <div class="flex flex-wrap items-center gap-2 mt-4">
            <span v-if="branch.delivery_enabled" class="badge bg-brand-50 text-brand-700">
              <span class="w-1.5 h-1.5 bg-brand-500 rounded-full mr-1.5" />
              Delivery available
            </span>
            <span v-else class="badge bg-ink-100 text-ink-500">Pickup only</span>
            <span v-if="branch.opening_hours" class="text-xs text-ink-400">{{ branch.opening_hours }}</span>
          </div>
          <p v-if="branch.delivery_enabled" class="text-xs text-ink-500 mt-3">Delivery from <strong class="text-ink-700">{{ formatNaira(branch.delivery_fee) }}</strong></p>
        </button>
      </div>
    </div>

    <!-- Mobile bottom nav -->
    <nav class="md:hidden fixed bottom-0 left-0 right-0 z-40 bg-white border-t border-ink-200 shadow-lg">
      <div class="flex items-center justify-around h-16 px-2">
        <NuxtLink to="/" class="flex flex-col items-center justify-center gap-0.5 px-3 py-1 rounded-lg transition-colors text-brand-600">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
          </svg>
          <span class="text-[10px] font-medium">Home</span>
        </NuxtLink>
        <NuxtLink to="/categories" class="flex flex-col items-center justify-center gap-0.5 px-3 py-1 rounded-lg transition-colors text-ink-400">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z" />
          </svg>
          <span class="text-[10px] font-medium">Categories</span>
        </NuxtLink>
        <NuxtLink to="/search" class="flex flex-col items-center justify-center gap-0.5 px-3 py-1 rounded-lg transition-colors text-ink-400">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
          </svg>
          <span class="text-[10px] font-medium">Search</span>
        </NuxtLink>
        <NuxtLink to="/orders" class="flex flex-col items-center justify-center gap-0.5 px-3 py-1 rounded-lg transition-colors text-ink-400">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 11V7a4 4 0 00-8 0v4M5 9h14l1 12H4L5 9z" />
          </svg>
          <span class="text-[10px] font-medium">Orders</span>
        </NuxtLink>
      </div>
    </nav>
  </div>
</template>
