<script setup lang="ts">
const branchStore = useBranchStore()
const cartStore = useCartStore()
const route = useRoute()

const showBranchGate = computed(() => !branchStore.currentBranch && !['/select-branch', '/account', '/profile', '/orders'].includes(route.path) && !route.path.startsWith('/order/'))

onMounted(async () => {
  branchStore.restoreBranch()
  if (branchStore.currentBranch) {
    cartStore.ensureSession()
    await cartStore.loadCart(branchStore.currentBranch.id)
  }
})

watch(() => branchStore.currentBranch?.id, async (newId, oldId) => {
  if (newId && newId !== oldId) {
    cartStore.reset()
    cartStore.ensureSession()
    await cartStore.loadCart(newId)
  }
})
</script>

<template>
  <div class="min-h-screen flex flex-col bg-ink-50">
    <AppHeader v-if="branchStore.currentBranch" />
    <main class="flex-1 pb-20 md:pb-0">
      <slot />
    </main>
    <AppFooter v-if="branchStore.currentBranch" />
    <BottomNav v-if="branchStore.currentBranch" />

    <!-- Branch gate modal -->
    <div
      v-if="showBranchGate"
      class="fixed inset-0 z-50 flex items-center justify-center bg-ink-900/60 backdrop-blur-sm p-4"
    >
      <div class="card max-w-md w-full p-6 animate-slide-up">
        <div class="text-center mb-6">
          <div class="w-16 h-16 bg-brand-600 rounded-2xl flex items-center justify-center mx-auto mb-4">
            <svg class="w-9 h-9 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
            </svg>
          </div>
          <h2 class="text-xl font-bold text-ink-800">Where would you like to shop from?</h2>
          <p class="text-ink-500 mt-2 text-sm">Select your nearest SuperSaver branch to see products and prices available there.</p>
        </div>
        <NuxtLink to="/select-branch" class="btn-primary w-full text-center block">Choose a Branch</NuxtLink>
      </div>
    </div>
  </div>
</template>
