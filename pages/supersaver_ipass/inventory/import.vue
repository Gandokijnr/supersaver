<script setup lang="ts">
definePageMeta({ layout: 'admin', middleware: 'admin' })

const { admin } = useAdminAuth()
const supabase = useSupabase()
const config = useRuntimeConfig()

const isSuperAdmin = computed(() => admin.value?.role === 'super_admin' || admin.value?.role === 'admin')
const branches = ref<any[]>([])
const selectedBranch = ref('')
const file = ref<File | null>(null)
const uploading = ref(false)
const processing = ref(false)
const errorMsg = ref('')
const successMsg = ref('')
const currentJobId = ref<string | null>(null)
const jobStatus = ref<any>(null)
const pollTimer = ref<any>(null)
const previewData = ref<any[]>([])

onMounted(async () => {
  if (isSuperAdmin.value) {
    const { data } = await supabase.from('branches').select('id, name, slug').order('sort_order')
    branches.value = data || []
    if (branches.value.length) selectedBranch.value = branches.value[0].id
  } else {
    selectedBranch.value = admin.value?.branch_id || ''
  }
})

function onFileChange(e: Event) {
  const target = e.target as HTMLInputElement
  const f = target.files?.[0]
  if (!f) return
  if (!f.name.endsWith('.csv')) { errorMsg.value = 'Please select a CSV file.'; return }
  if (f.size > 100 * 1024 * 1024) { errorMsg.value = 'File too large (max 100MB).'; return }
  file.value = f
  errorMsg.value = ''
  // Preview first 5 rows
  const reader = new FileReader()
  reader.onload = () => {
    const text = reader.result as string
    const lines = text.split('\n').filter(l => l.trim())
    if (lines.length < 2) { previewData.value = []; return }
    const headers = lines[0].split(',').map(h => h.trim())
    previewData.value = lines.slice(1, 6).map((line, idx) => {
      const cols = line.split(',')
      const obj: any = { _row: idx + 1 }
      headers.forEach((h, i) => obj[h] = cols[i]?.trim() || '')
      return obj
    })
  }
  reader.readAsText(f)
}

async function startImport() {
  if (!file.value || !selectedBranch.value) { errorMsg.value = 'Select a branch and file.'; return }
  uploading.value = true; errorMsg.value = ''; successMsg.value = ''

  try {
    // 1. Upload file to storage
    const filePath = `${selectedBranch.value}/${Date.now()}-${file.value.name}`
    const { error: upErr } = await supabase.storage.from('inventory-imports')
      .upload(filePath, file.value, { contentType: 'text/csv' })
    if (upErr) throw new Error('File upload failed: ' + upErr.message)

    // 2. Create import job
    const { data: job, error: jobErr } = await supabase.from('inventory_import_jobs')
      .insert({
        branch_id: selectedBranch.value,
        file_name: file.value.name,
        file_path: filePath,
        file_size: file.value.size,
        status: 'queued',
      })
      .select('id')
      .single()
    if (jobErr || !job) throw new Error('Could not create import job.')
    currentJobId.value = job.id

    // 3. Trigger edge function
    uploading.value = false
    processing.value = true
    const funcUrl = `${config.public.supabaseUrl}/functions/v1/process-inventory-import`
    const resp = await fetch(funcUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${config.public.supabaseAnonKey}`,
      },
      body: JSON.stringify({ jobId: job.id }),
    })
    if (!resp.ok) {
      const errBody = await resp.text()
      throw new Error('Processing failed: ' + errBody)
    }

    // 4. Poll for progress
    startPolling()
  } catch (e: any) {
    uploading.value = false; processing.value = false
    errorMsg.value = e.message
  }
}

function startPolling() {
  clearInterval(pollTimer.value)
  pollTimer.value = setInterval(async () => {
    if (!currentJobId.value) return
    const { data } = await supabase.from('inventory_import_jobs')
      .select('*').eq('id', currentJobId.value).single()
    if (data) {
      jobStatus.value = data
      if (data.status === 'completed' || data.status === 'completed_with_errors' || data.status === 'failed') {
        clearInterval(pollTimer.value)
        processing.value = false
        if (data.status === 'completed') successMsg.value = 'Import completed successfully!'
        else if (data.status === 'completed_with_errors') successMsg.value = `Import completed with ${data.failed_rows} errors.`
        else errorMsg.value = 'Import failed: ' + (data.error_message || 'Unknown error')
      }
    }
  }, 2000)
}

const progressPercent = computed(() => {
  if (!jobStatus.value || !jobStatus.value.total_rows) return 0
  return Math.round((jobStatus.value.processed_rows / jobStatus.value.total_rows) * 100)
})

onUnmounted(() => clearInterval(pollTimer.value))
</script>

<template>
  <div>
    <NuxtLink to="/supersaver_ipass/inventory" class="text-sm text-ink-400 hover:text-brand-600 mb-4 inline-flex items-center gap-1">← Back to inventory</NuxtLink>
    <h1 class="text-2xl font-bold text-ink-800 mb-2">Import Inventory</h1>
    <p class="text-sm text-ink-400 mb-6">Upload a CSV file to bulk-update stock and pricing for a branch.</p>

    <div class="card p-6 max-w-2xl">
      <div class="mb-4">
        <label class="text-sm font-medium text-ink-600 mb-1 block">Target Branch</label>
        <select v-model="selectedBranch" class="input" :disabled="!isSuperAdmin">
          <option v-for="b in branches" :key="b.id" :value="b.id">{{ b.name }}</option>
        </select>
      </div>

      <div class="mb-4">
        <label class="text-sm font-medium text-ink-600 mb-1 block">CSV File</label>
        <input type="file" accept=".csv" @change="onFileChange" class="input" />
        <p class="text-xs text-ink-400 mt-2">Expected columns: <code class="bg-ink-100 px-1 rounded">part_no, desc, groupname, qty, price1</code></p>
      </div>

      <!-- Preview -->
      <div v-if="previewData.length" class="mb-4">
        <h3 class="text-sm font-semibold text-ink-700 mb-2">Preview (first 5 rows)</h3>
        <div class="overflow-x-auto rounded-xl border border-ink-100">
          <table class="w-full text-xs">
            <thead class="bg-ink-50 text-ink-500">
              <tr><th class="px-2 py-1 text-left">#</th><th v-for="key in Object.keys(previewData[0]).filter(k => k !== '_row')" :key="key" class="px-2 py-1 text-left">{{ key }}</th></tr>
            </thead>
            <tbody class="divide-y divide-ink-50">
              <tr v-for="row in previewData" :key="row._row"><td class="px-2 py-1 text-ink-400">{{ row._row }}</td><td v-for="key in Object.keys(row).filter(k => k !== '_row')" :key="key" class="px-2 py-1 text-ink-700">{{ row[key] }}</td></tr>
            </tbody>
          </table>
        </div>
      </div>

      <p v-if="errorMsg" class="text-sm text-red-600 font-medium bg-red-50 rounded-xl p-3 mb-4">{{ errorMsg }}</p>
      <p v-if="successMsg" class="text-sm text-brand-600 font-medium bg-brand-50 rounded-xl p-3 mb-4">{{ successMsg }}</p>

      <!-- Progress -->
      <div v-if="processing && jobStatus" class="mb-4">
        <div class="flex justify-between text-sm mb-1"><span class="text-ink-600 font-medium">Processing...</span><span class="text-ink-400">{{ jobStatus.processed_rows }} / {{ jobStatus.total_rows }}</span></div>
        <div class="w-full h-3 bg-ink-100 rounded-full overflow-hidden">
          <div class="h-full bg-brand-600 rounded-full transition-all duration-500" :style="{ width: progressPercent + '%' }" />
        </div>
        <div class="grid grid-cols-3 gap-2 mt-3 text-center text-sm">
          <div class="bg-brand-50 rounded-xl p-2"><p class="text-brand-700 font-bold">{{ jobStatus.successful_rows }}</p><p class="text-xs text-ink-400">Successful</p></div>
          <div class="bg-red-50 rounded-xl p-2"><p class="text-red-600 font-bold">{{ jobStatus.failed_rows }}</p><p class="text-xs text-ink-400">Errors</p></div>
          <div class="bg-ink-50 rounded-xl p-2"><p class="text-ink-600 font-bold">{{ jobStatus.skipped_rows }}</p><p class="text-xs text-ink-400">Skipped</p></div>
        </div>
      </div>

      <button v-if="!processing" @click="startImport" :disabled="!file || !selectedBranch || uploading" class="btn-primary w-full disabled:opacity-50">
        {{ uploading ? 'Uploading...' : 'Start Import' }}
      </button>
    </div>

    <div class="mt-6">
      <NuxtLink to="/supersaver_ipass/inventory/imports" class="text-sm text-brand-600 font-semibold hover:text-brand-700">View Import History →</NuxtLink>
    </div>
  </div>
</template>
