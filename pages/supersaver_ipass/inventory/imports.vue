<script setup lang="ts">
definePageMeta({ layout: 'admin', middleware: 'admin' })

const { fetchImportJobs } = useAdminData()
const jobs = ref<any[]>([])
const loading = ref(true)

const statusColors: Record<string, string> = {
  queued: 'bg-ink-100 text-ink-600', uploading: 'bg-sky-100 text-sky-700',
  processing: 'bg-indigo-100 text-indigo-700', completed: 'bg-brand-100 text-brand-700',
  completed_with_errors: 'bg-accent-100 text-accent-700', failed: 'bg-red-100 text-red-700',
  cancelled: 'bg-ink-100 text-ink-500',
}

onMounted(async () => { try { jobs.value = await fetchImportJobs() } finally { loading.value = false } })
</script>

<template>
  <div>
    <div class="flex items-center justify-between mb-6">
      <div><h1 class="text-2xl font-bold text-ink-800">Import History</h1><p class="text-sm text-ink-400 mt-1">All inventory import jobs</p></div>
      <NuxtLink to="/supersaver_ipass/inventory/import" class="btn-primary text-sm">↑ New Import</NuxtLink>
    </div>

    <div v-if="loading" class="card p-5 space-y-3"><div v-for="n in 5" :key="n" class="h-12 skeleton rounded-xl" /></div>
    <div v-else-if="jobs.length === 0" class="card p-10 text-center">
      <div class="text-5xl mb-3">📋</div><h2 class="text-lg font-bold text-ink-800">No imports yet</h2>
      <p class="text-ink-500 mt-1">Import history will appear here.</p>
    </div>
    <div v-else class="card overflow-hidden">
      <div class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead class="bg-ink-50 text-ink-500 uppercase text-xs">
            <tr>
              <th class="text-left px-4 py-3 font-semibold">File</th>
              <th class="text-left px-4 py-3 font-semibold hidden md:table-cell">Branch</th>
              <th class="text-right px-4 py-3 font-semibold">Rows</th>
              <th class="text-right px-4 py-3 font-semibold hidden md:table-cell">Successful</th>
              <th class="text-right px-4 py-3 font-semibold hidden md:table-cell">Failed</th>
              <th class="text-left px-4 py-3 font-semibold">Status</th>
              <th class="text-left px-4 py-3 font-semibold hidden lg:table-cell">Date</th>
              <th class="px-4 py-3"></th>
            </tr>
          </thead>
          <tbody class="divide-y divide-ink-100">
            <tr v-for="job in jobs" :key="job.id" class="hover:bg-ink-50">
              <td class="px-4 py-3 font-semibold text-ink-800">{{ job.file_name }}</td>
              <td class="px-4 py-3 hidden md:table-cell text-ink-600">{{ job.branch?.name?.replace('Supersaver ', '') || '—' }}</td>
              <td class="px-4 py-3 text-right text-ink-700">{{ job.total_rows || 0 }}</td>
              <td class="px-4 py-3 text-right text-brand-600 font-semibold hidden md:table-cell">{{ job.successful_rows || 0 }}</td>
              <td class="px-4 py-3 text-right text-red-600 font-semibold hidden md:table-cell">{{ job.failed_rows || 0 }}</td>
              <td class="px-4 py-3"><span :class="statusColors[job.status] || 'bg-ink-100'" class="badge capitalize">{{ job.status.replace(/_/g, ' ') }}</span></td>
              <td class="px-4 py-3 hidden lg:table-cell text-ink-400 text-xs">{{ new Date(job.created_at).toLocaleDateString('en-NG', { day: 'numeric', month: 'short', year: 'numeric' }) }}</td>
              <td class="px-4 py-3"><NuxtLink :to="`/supersaver_ipass/inventory/imports/${job.id}`" class="text-brand-600 text-xs font-semibold hover:text-brand-700">View →</NuxtLink></td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>
