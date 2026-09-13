<script setup lang="ts">
definePageMeta({ layout: 'admin', middleware: 'admin' })

const route = useRoute()
const { fetchImportJob } = useAdminData()
const data = ref<any>(null)
const loading = ref(true)

const statusColors: Record<string, string> = {
  completed: 'bg-brand-100 text-brand-700', completed_with_errors: 'bg-accent-100 text-accent-700',
  failed: 'bg-red-100 text-red-700', processing: 'bg-indigo-100 text-indigo-700', queued: 'bg-ink-100 text-ink-600',
}

onMounted(async () => {
  try { data.value = await fetchImportJob(route.params.id as string) }
  finally { loading.value = false }
})
</script>

<template>
  <div>
    <NuxtLink to="/supersaver_ipass/inventory/imports" class="text-sm text-ink-400 hover:text-brand-600 mb-4 inline-flex items-center gap-1">← Back to imports</NuxtLink>

    <div v-if="loading" class="card p-6 space-y-3"><div v-for="n in 5" :key="n" class="h-5 skeleton rounded" /></div>
    <div v-else-if="!data" class="card p-8 text-center text-ink-600">Import job not found.</div>
    <div v-else class="space-y-4">
      <div class="card p-5">
        <div class="flex items-center justify-between mb-4">
          <div><h1 class="text-xl font-bold text-ink-800">{{ data.job.file_name }}</h1>
            <p class="text-sm text-ink-400 mt-1">{{ new Date(data.job.created_at).toLocaleString('en-NG', { dateStyle: 'medium', timeStyle: 'short' }) }}</p>
          </div>
          <span :class="statusColors[data.job.status]" class="badge capitalize text-sm px-3 py-1">{{ data.job.status.replace(/_/g, ' ') }}</span>
        </div>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
          <div><p class="text-ink-400">Total Rows</p><p class="text-xl font-bold text-ink-800">{{ data.job.total_rows }}</p></div>
          <div><p class="text-ink-400">Successful</p><p class="text-xl font-bold text-brand-600">{{ data.job.successful_rows }}</p></div>
          <div><p class="text-ink-400">Failed</p><p class="text-xl font-bold text-red-600">{{ data.job.failed_rows }}</p></div>
          <div><p class="text-ink-400">Skipped</p><p class="text-xl font-bold text-ink-600">{{ data.job.skipped_rows }}</p></div>
        </div>
        <p v-if="data.job.error_message" class="text-sm text-red-600 mt-3 bg-red-50 rounded-xl p-3">{{ data.job.error_message }}</p>
      </div>

      <div v-if="data.errors.length" class="card p-5">
        <h3 class="font-bold text-ink-800 mb-3">Errors ({{ data.errors.length }}{{ data.errors.length >= 100 ? '+' : '' }})</h3>
        <div class="max-h-96 overflow-y-auto space-y-2">
          <div v-for="err in data.errors" :key="err.id" class="flex items-start gap-3 p-2 rounded-lg bg-red-50">
            <span class="text-xs font-bold text-red-600 mt-0.5">Row {{ err.row_number }}</span>
            <div><p v-if="err.sku" class="text-xs text-ink-500">SKU: {{ err.sku }}</p><p class="text-sm text-red-700">{{ err.error_message }}</p></div>
          </div>
        </div>
      </div>

      <div v-if="data.changes.length" class="card p-5">
        <h3 class="font-bold text-ink-800 mb-3">Changes ({{ data.changes.length }}{{ data.changes.length >= 100 ? '+' : '' }})</h3>
        <div class="max-h-96 overflow-y-auto">
          <table class="w-full text-sm">
            <thead class="text-ink-500 text-xs uppercase"><tr><th class="text-left py-2">Old Stock</th><th class="text-left py-2">New Stock</th><th class="text-left py-2">Old Price</th><th class="text-left py-2">New Price</th></tr></thead>
            <tbody class="divide-y divide-ink-50">
              <tr v-for="ch in data.changes" :key="ch.id">
                <td class="py-2 text-ink-600">{{ ch.old_stock ?? '—' }}</td>
                <td class="py-2 font-semibold text-ink-800">{{ ch.new_stock ?? '—' }}</td>
                <td class="py-2 text-ink-600">{{ ch.old_price ? '₦' + Number(ch.old_price).toLocaleString() : '—' }}</td>
                <td class="py-2 font-semibold text-ink-800">{{ ch.new_price ? '₦' + Number(ch.new_price).toLocaleString() : '—' }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </div>
</template>
