<script setup lang="ts">
const branchStore = useBranchStore()
const cartStore = useCartStore()
</script>

<template>
  <footer class="hidden md:block bg-ink-900 text-ink-300 mt-12">
    <div class="max-w-7xl mx-auto px-4 py-10">
      <div class="grid grid-cols-2 md:grid-cols-4 gap-8">
        <div>
          <div class="flex items-center gap-2 mb-4">
            <div class="w-8 h-8 bg-brand-600 rounded-lg flex items-center justify-center">
              <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z" />
              </svg>
            </div>
            <span class="font-extrabold text-lg text-white">SuperSaver</span>
          </div>
          <p class="text-sm text-ink-400">Your trusted supermarket for fresh groceries and everyday essentials across Lagos.</p>
        </div>
        <div>
          <h3 class="text-white font-semibold mb-3 text-sm">Shop</h3>
          <ul class="space-y-2 text-sm">
            <li><NuxtLink to="/" class="hover:text-brand-400 transition-colors">Home</NuxtLink></li>
            <li><NuxtLink to="/category/groceries" class="hover:text-brand-400 transition-colors">Groceries</NuxtLink></li>
            <li><NuxtLink to="/category/beverages" class="hover:text-brand-400 transition-colors">Beverages</NuxtLink></li>
            <li><NuxtLink to="/category/fresh-produce" class="hover:text-brand-400 transition-colors">Fresh Produce</NuxtLink></li>
          </ul>
        </div>
        <div>
          <h3 class="text-white font-semibold mb-3 text-sm">Account</h3>
          <ul class="space-y-2 text-sm">
            <li><NuxtLink to="/cart" class="hover:text-brand-400 transition-colors">Cart ({{ cartStore.itemCount }})</NuxtLink></li>
            <li><NuxtLink to="/orders" class="hover:text-brand-400 transition-colors">My Orders</NuxtLink></li>
            <li><NuxtLink to="/select-branch" class="hover:text-brand-400 transition-colors">Change Branch</NuxtLink></li>
          </ul>
        </div>
        <div>
          <h3 class="text-white font-semibold mb-3 text-sm">Why SuperSaver?</h3>
          <ul class="space-y-2 text-sm text-ink-400">
            <li>Authentic products</li>
            <li>Convenient delivery</li>
            <li>Secure payments</li>
            <li>Multiple branches</li>
          </ul>
        </div>
      </div>
      <div class="border-t border-ink-800 mt-8 pt-6 text-center text-sm text-ink-500">
        &copy; {{ new Date().getFullYear() }} SuperSaver Supermarket. All rights reserved.
      </div>
    </div>
  </footer>
</template>
