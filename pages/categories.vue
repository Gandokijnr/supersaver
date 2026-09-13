<script setup lang="ts">
import type { Category } from '~/lib/types'

const { fetchCategories } = useCatalog()
const categories = ref<Category[]>([])
const loading = ref(true)

const categoryStyles: Record<string, { bg: string; icon: string }> = {
  groceries: { bg: 'bg-amber-50', icon: '🧺' }, beverages: { bg: 'bg-sky-50', icon: '🥤' }, dairy: { bg: 'bg-blue-50', icon: '🥛' },
  snacks: { bg: 'bg-orange-50', icon: '🍿' }, 'personal-care': { bg: 'bg-rose-50', icon: '🧴' }, household: { bg: 'bg-teal-50', icon: '🧹' },
  bakery: { bg: 'bg-yellow-50', icon: '🍞' }, 'fresh-produce': { bg: 'bg-lime-50', icon: '🥬' },
}

onMounted(async () => { try { categories.value = await fetchCategories() } finally { loading.value = false } })
</script>

<template>
  <div class="max-w-5xl mx-auto px-4 py-6 md:py-10">
    <h1 class="text-2xl font-bold text-ink-800 mb-6">All Categories</h1>
    <div v-if="loading" class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-4">
      <div v-for="n in 8" :key="n" class="card p-6"><div class="aspect-square skeleton rounded-2xl mb-3" /><div class="h-5 w-1/2 skeleton mx-auto" /></div>
    </div>
    <div v-else class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-4">
      <NuxtLink v-for="cat in categories" :key="cat.id" :to="`/category/${cat.slug}`" class="card p-6 text-center group hover:shadow-md transition-shadow">
        <div :class="categoryStyles[cat.slug]?.bg || 'bg-ink-100'" class="aspect-square rounded-2xl flex items-center justify-center text-5xl group-hover:scale-105 transition-transform">
          {{ categoryStyles[cat.slug]?.icon || '🛍️' }}
        </div>
        <p class="font-semibold text-ink-700 mt-3">{{ cat.name }}</p>
      </NuxtLink>
    </div>
  </div>
</template>
