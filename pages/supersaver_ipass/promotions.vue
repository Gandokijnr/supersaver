<script setup lang="ts">
definePageMeta({ layout: 'admin', middleware: 'admin' })

const supabase = useSupabase()
const promotions = ref<any[]>([])
const loading = ref(true)
const showForm = ref(false)
const saving = ref(false)
const editingId = ref<string | null>(null)
const formError = ref('')
const selectedPromotion = ref<any>(null)
const errorMsg = ref('')
const form = ref({ name: '', type: 'percentage', value: 0, minimum_order: 0, start_at: '', end_at: '' })

onMounted(load)
async function load() {
  loading.value = true
  const { data, error } = await supabase.from('promotions').select('*').order('created_at', { ascending: false })
  errorMsg.value = error ? 'Could not load promotions. Please try again.' : ''
  promotions.value = data || []
  loading.value = false
}

function openCreate() {
  editingId.value = null
  formError.value = ''
  form.value = { name: '', type: 'percentage', value: 0, minimum_order: 0, start_at: '', end_at: '' }
  showForm.value = true
}

function localDateTime(value: string | null) {
  if (!value) return ''
  const date = new Date(value)
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`
}

function openEdit(p: any) {
  editingId.value = p.id
  formError.value = ''
  form.value = {
    name: p.name, type: p.type, value: Number(p.value), minimum_order: Number(p.minimum_order),
    start_at: localDateTime(p.start_at), end_at: localDateTime(p.end_at),
  }
  showForm.value = true
}

function closeForm() {
  if (!saving.value) showForm.value = false
}

async function save() {
  if (saving.value) return
  formError.value = ''
  if (!form.value.name.trim()) { formError.value = 'Enter a promotion name.'; return }
  if (!Number.isFinite(form.value.value) || form.value.value < 0 || (form.value.type === 'percentage' && form.value.value > 100)) {
    formError.value = 'Enter a valid discount. Percentage discounts must be between 0 and 100.'; return
  }
  if (!Number.isFinite(form.value.minimum_order) || form.value.minimum_order < 0) {
    formError.value = 'Minimum order must be zero or greater.'; return
  }
  if (form.value.start_at && form.value.end_at && new Date(form.value.end_at) <= new Date(form.value.start_at)) {
    formError.value = 'End date must be after the start date.'; return
  }
  saving.value = true
  try {
    const payload = {
      name: form.value.name.trim(),
      type: form.value.type,
      value: form.value.value,
      minimum_order: form.value.minimum_order,
      start_at: form.value.start_at ? new Date(form.value.start_at).toISOString() : null,
      end_at: form.value.end_at ? new Date(form.value.end_at).toISOString() : null,
    }
    const query = editingId.value
      ? supabase.from('promotions').update(payload).eq('id', editingId.value)
      : supabase.from('promotions').insert({ ...payload, is_active: true })
    const { data, error } = await query.select('*').single()
    if (error) throw error
    showForm.value = false
    if (!editingId.value) selectedPromotion.value = data
    await load()
  } catch (e: any) { formError.value = e.message || 'Could not save promotion. Please try again.' } finally { saving.value = false }
}

async function toggleActive(p: any) {
  const { error } = await supabase.from('promotions').update({ is_active: !p.is_active }).eq('id', p.id)
  if (error) { errorMsg.value = error.message; return }
  await load()
}
</script>

<template>
  <div>
    <div class="flex items-center justify-between mb-6">
      <div><h1 class="text-2xl font-bold text-ink-800">Promotions</h1><p class="text-sm text-ink-400 mt-1">Manage discounts and deals</p></div>
      <button v-if="!selectedPromotion" @click="openCreate" class="btn-primary text-sm">+ New Promotion</button>
    </div>
    <p v-if="errorMsg" role="alert" class="text-sm text-red-600 mb-4">{{ errorMsg }} <button class="underline" @click="load">Retry</button></p>
    <PromotionItemsManager v-if="selectedPromotion" :key="selectedPromotion.id" :promotion="selectedPromotion" @close="selectedPromotion = null" />
    <div v-else-if="loading" class="card p-5 space-y-3"><div v-for="n in 4" :key="n" class="h-10 skeleton rounded-xl" /></div>
    <div v-else-if="promotions.length === 0" class="card p-10 text-center"><div class="text-5xl mb-3">★</div><h2 class="text-lg font-bold text-ink-800">No promotions</h2><p class="text-ink-500 mt-1">Create promotions to boost sales.</p></div>
    <div v-else class="grid sm:grid-cols-2 lg:grid-cols-3 gap-4">
      <div v-for="p in promotions" :key="p.id" class="card p-5">
        <div class="flex items-start justify-between mb-2">
          <h2 class="font-bold text-ink-800">{{ p.name }}</h2>
          <span :class="p.is_active ? 'bg-brand-100 text-brand-700' : 'bg-ink-100 text-ink-500'" class="badge">{{ p.is_active ? 'Active' : 'Inactive' }}</span>
        </div>
        <p class="text-sm text-ink-500">{{ p.type === 'percentage' ? p.value + '% off' : '₦' + Number(p.value).toLocaleString() + ' off' }}</p>
        <div class="text-xs text-ink-400 mt-2">
          <p v-if="p.start_at">Start: {{ new Date(p.start_at).toLocaleDateString('en-NG') }}</p>
          <p v-if="p.end_at">End: {{ new Date(p.end_at).toLocaleDateString('en-NG') }}</p>
          <p v-if="p.minimum_order > 0">Min order: ₦{{ Number(p.minimum_order).toLocaleString() }}</p>
        </div>
        <div class="flex flex-wrap items-center justify-between gap-3 mt-4">
          <button @click="openEdit(p)" class="btn-outline text-sm">Edit</button>
          <button @click="selectedPromotion = p" class="btn-primary text-sm">Manage Items</button>
          <button @click="toggleActive(p)" class="text-ink-400 text-xs font-semibold hover:text-ink-600">{{ p.is_active ? 'Deactivate' : 'Activate' }}</button>
        </div>
      </div>
    </div>

    <div v-if="showForm" class="fixed inset-0 z-50 flex items-center justify-center bg-ink-900/50 p-4" @click.self="closeForm">
      <form class="card p-6 max-w-md w-full max-h-[90vh] overflow-y-auto" role="dialog" aria-modal="true" aria-labelledby="promotion-form-title" @submit.prevent="save">
        <h2 id="promotion-form-title" class="text-lg font-bold text-ink-800 mb-4">{{ editingId ? 'Edit Promotion' : 'New Promotion' }}</h2>
        <p v-if="formError" role="alert" class="text-sm text-red-600 mb-4">{{ formError }}</p>
        <fieldset :disabled="saving" class="space-y-3">
          <div><label class="text-sm font-medium text-ink-600 mb-1 block">Name *</label><input v-model="form.name" class="input" placeholder="Flash Deals" /></div>
          <div class="grid grid-cols-2 gap-3">
            <div><label class="text-sm font-medium text-ink-600 mb-1 block">Type</label><select v-model="form.type" class="input"><option value="percentage">Percentage</option><option value="fixed">Fixed Amount</option></select></div>
            <div><label class="text-sm font-medium text-ink-600 mb-1 block">Value</label><input v-model.number="form.value" type="number" min="0" step="0.01" class="input" /></div>
          </div>
          <div><label class="text-sm font-medium text-ink-600 mb-1 block">Minimum Order (₦)</label><input v-model.number="form.minimum_order" type="number" min="0" step="0.01" class="input" /></div>
          <div class="grid grid-cols-2 gap-3">
            <div><label class="text-sm font-medium text-ink-600 mb-1 block">Start</label><input v-model="form.start_at" type="datetime-local" step="1" class="input" /></div>
            <div><label class="text-sm font-medium text-ink-600 mb-1 block">End</label><input v-model="form.end_at" type="datetime-local" step="1" class="input" /></div>
          </div>
        </fieldset>
        <div class="flex gap-2 mt-5">
          <button type="button" @click="closeForm" :disabled="saving" class="btn-outline flex-1 disabled:opacity-50">Cancel</button>
          <button type="submit" :disabled="saving || !form.name.trim()" class="btn-primary flex-1 disabled:opacity-50">{{ saving ? 'Saving...' : editingId ? 'Save Changes' : 'Create' }}</button>
        </div>
      </form>
    </div>
  </div>
</template>
