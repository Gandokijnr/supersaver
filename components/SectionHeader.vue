<script setup lang="ts">
defineProps<{ title: string; link?: string; linkText?: string }>()
</script>

<template>
  <div class="flex items-center justify-between mb-4">
    <h2 class="text-lg md:text-xl font-bold text-ink-800">{{ title }}</h2>
    <NuxtLink
      v-if="link"
      :to="link"
      class="text-sm font-semibold text-brand-600 hover:text-brand-700 flex items-center gap-1"
    >
      {{ linkText || 'See all' }}
      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
      </svg>
    </NuxtLink>
  </div>
</template>
