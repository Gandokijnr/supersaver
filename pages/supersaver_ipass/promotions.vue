<script setup lang="ts">
definePageMeta({ layout: 'admin', middleware: 'admin' })

const supabase = useSupabase()
const promotions = ref<any[]>([])
const loading = ref(true)
const showForm = ref(false)
const saving = ref(false)
const form = ref({ name: '', type: 'percentage', value: 0, minimum_order: 0, start_at: '', end_at: '' })

onMounted(load)
async function load() {
  loading.value = true
  const { data } = await supabase.from('promotions').select('*').order('created_at', { ascending: false })
  promotions.value = data || []
  loading.value = false
}

function openCreate() { form.value = { name: '', type: 'percentage', value: 0, minimum_order: 0, start_at: '', end_at: '' }; showForm.value = true }

async function save() {
  saving.value = true
  try {
    const { error } = await supabase.from('promotions').insert({
      name: form.value.name,
      type: form.value.type,
      value: form.value.value,
      minimum_order: form.value.minimum_order,
      start_at: form.value.start_at ? new Date(form.value.start_at).toISOString() : null,
      end_at: form.value.end_at ? new Date(form.value.end_at).toISOString() : null,
      is_active: true,
    })
    if (error) throw error
    showForm.value = false; await load()
  } catch (e: any) { alert(e.message) } finally { saving.value = false }
}

async function toggleActive(p: any) {
  await supabase.from('promotions').update({ is_active: !p.is_active }).eq('id', p.id)
  await load()
}
</script>

<template>
  <div>
    <div class="flex items-center justify-between mb-6">
      <div><h1 class="text-2xl font-bold text-ink-800">Promotions</h1><p class="text-sm text-ink-400 mt-1">Manage discounts and deals</p></div>
      <button @click="openCreate" class="btn-primary text-sm">+ New Promotion</button>
    </div>
    <div v-if="loading" class="card p-5 space-y-3"><div v-for="n in 4" :key="n" class="h-10 skeleton rounded-xl" /></div>
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
        <button @click="toggleActive(p)" class="text-ink-400 text-xs font-semibold hover:text-ink-600 mt-3">{{ p.is_active ? 'Deactivate' : 'Activate' }}</button>
      </div>
    </div>

    <div v-if="showForm" class="fixed inset-0 z-50 flex items-center justify-center bg-ink-900/50 p-4" @click.self="showForm = false">
      <div class="card p-6 max-w-md w-full">
        <h2 class="text-lg font-bold text-ink-800 mb-4">New Promotion</h2>
        <div class="space-y-3">
          <div><label class="text-sm font-medium text-ink-600 mb-1 block">Name *</label><input v-model="form.name" class="input" placeholder="Flash Deals" /></div>
          <div class="grid grid-cols-2 gap-3">
            <div><label class="text-sm font-medium text-ink-600 mb-1 block">Type</label><select v-model="form.type" class="input"><option value="percentage">Percentage</option><option value="fixed">Fixed Amount</option></select></div>
            <div><label class="text-sm font-medium text-ink-600 mb-1 block">Value</label><input v-model.number="form.value" type="number" class="input" /></div>
          </div>
          <div><label class="text-sm font-medium text-ink-600 mb-1 block">Minimum Order (₦)</label><input v-model.number="form.minimum_order" type="number" class="input" /></div>
          <div class="grid grid-cols-2 gap-3">
            <div><label class="text-sm font-medium text-ink-600 mb-1 block">Start</label><input v-model="form.start_at" type="datetime-local" class="input" /></div>
            <div><label class="text-sm font-medium text-ink-600 mb-1 block">End</label><input v-model="form.end_at" type="datetime-local" class="input" /></div>
          </div>
        </div>
        <div class="flex gap-2 mt-5">
          <button @click="showForm = false" class="btn-outline flex-1">Cancel</button>
          <button @click="save" :disabled="saving || !form.name" class="btn-primary flex-1 disabled:opacity-50">{{ saving ? 'Saving...' : 'Create' }}</button>
        </div>
      </div>
    </div>
  </div>
</template>
