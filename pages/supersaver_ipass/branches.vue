<script setup lang="ts">
definePageMeta({ layout: 'admin', middleware: 'admin' })

const supabase = useSupabase()
const branches = ref<any[]>([])
const loading = ref(true)
const errorMsg = ref('')
const showForm = ref(false)
const editBranch = ref<any>(null)
const saving = ref(false)
const form = ref({ name: '', slug: '', address: '', phone: '', opening_hours: '', delivery_fee: 2000, delivery_enabled: true })

onMounted(load)
async function load() {
  loading.value = true
  errorMsg.value = ''
  const { data, error } = await supabase.from('branches').select('*').order('sort_order')
  if (error) errorMsg.value = error.message
  branches.value = data || []
  loading.value = false
}

function openCreate() { editBranch.value = null; form.value = { name: '', slug: '', address: '', phone: '', opening_hours: '', delivery_fee: 2000, delivery_enabled: true }; showForm.value = true }
function openEdit(b: any) { editBranch.value = b; form.value = { name: b.name, slug: b.slug, address: b.address, phone: b.phone || '', opening_hours: b.opening_hours || '', delivery_fee: b.delivery_fee, delivery_enabled: b.delivery_enabled }; showForm.value = true }

async function save() {
  saving.value = true
  const slug = form.value.slug || form.value.name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '')
  try {
    if (editBranch.value) {
      const { error } = await supabase.from('branches').update({ ...form.value, slug }).eq('id', editBranch.value.id)
      if (error) throw error
    } else {
      const { error } = await supabase.from('branches').insert({ ...form.value, slug, is_active: true, sort_order: branches.value.length + 1 })
      if (error) throw error
    }
    showForm.value = false; await load()
  } catch (e: any) { alert(e.message) } finally { saving.value = false }
}

async function toggleActive(b: any) {
  await supabase.from('branches').update({ is_active: !b.is_active }).eq('id', b.id)
  await load()
}
</script>

<template>
  <div>
    <div class="flex items-center justify-between mb-6">
      <div><h1 class="text-2xl font-bold text-ink-800">Branches</h1><p class="text-sm text-ink-400 mt-1">Manage supermarket locations</p></div>
      <button @click="openCreate" class="btn-primary text-sm">+ New Branch</button>
    </div>
    <div v-if="loading" class="grid sm:grid-cols-2 lg:grid-cols-3 gap-4"><div v-for="n in 4" :key="n" class="card p-5 space-y-3"><div class="h-5 w-1/2 skeleton" /><div class="h-4 skeleton" /><div class="h-4 skeleton" /></div></div>
    <div v-else-if="errorMsg" class="card p-8 text-center"><p class="text-red-600 font-semibold">{{ errorMsg }}</p><button @click="load" class="btn-outline mt-3 text-sm">Retry</button></div>
    <div v-else-if="branches.length === 0" class="card p-8 text-center"><p class="text-ink-500">No branches found. Create one to get started.</p></div>
    <div v-else class="grid sm:grid-cols-2 lg:grid-cols-3 gap-4">
      <div v-for="b in branches" :key="b.id" class="card p-5">
        <div class="flex items-start justify-between mb-3">
          <div class="w-10 h-10 rounded-xl bg-brand-50 flex items-center justify-center"><span class="text-brand-600">🏪</span></div>
          <div class="flex items-center gap-1"><div class="w-2 h-2 rounded-full" :class="b.is_active ? 'bg-brand-500' : 'bg-ink-300'" /><span class="text-xs text-ink-400">{{ b.is_active ? 'Online' : 'Offline' }}</span></div>
        </div>
        <h2 class="font-bold text-ink-800">{{ b.name }}</h2>
        <p class="text-sm text-ink-500 mt-1">{{ b.address }}</p>
        <div class="grid grid-cols-2 gap-2 mt-3 text-xs text-ink-500">
          <div><span class="font-semibold text-ink-700">Delivery:</span> {{ b.delivery_enabled ? 'Yes' : 'No' }}</div>
          <div><span class="font-semibold text-ink-700">Fee:</span> ₦{{ Number(b.delivery_fee).toLocaleString() }}</div>
          <div v-if="b.phone"><span class="font-semibold text-ink-700">Phone:</span> {{ b.phone }}</div>
          <div v-if="b.opening_hours"><span class="font-semibold text-ink-700">Hours:</span> {{ b.opening_hours }}</div>
        </div>
        <div class="flex gap-3 mt-4">
          <button @click="openEdit(b)" class="text-brand-600 text-xs font-semibold hover:text-brand-700">Edit</button>
          <button @click="toggleActive(b)" class="text-ink-400 text-xs font-semibold hover:text-ink-600">{{ b.is_active ? 'Deactivate' : 'Activate' }}</button>
        </div>
      </div>
    </div>

    <div v-if="showForm" class="fixed inset-0 z-50 flex items-center justify-center bg-ink-900/50 p-4" @click.self="showForm = false">
      <div class="card p-6 max-w-md w-full max-h-[90vh] overflow-y-auto">
        <h2 class="text-lg font-bold text-ink-800 mb-4">{{ editBranch ? 'Edit' : 'New' }} Branch</h2>
        <div class="space-y-3">
          <div><label class="text-sm font-medium text-ink-600 mb-1 block">Name *</label><input v-model="form.name" class="input" placeholder="SuperSaver Gbagada" /></div>
          <div><label class="text-sm font-medium text-ink-600 mb-1 block">Address *</label><input v-model="form.address" class="input" /></div>
          <div class="grid grid-cols-2 gap-3">
            <div><label class="text-sm font-medium text-ink-600 mb-1 block">Phone</label><input v-model="form.phone" class="input" /></div>
            <div><label class="text-sm font-medium text-ink-600 mb-1 block">Opening Hours</label><input v-model="form.opening_hours" class="input" placeholder="8:00 AM - 9:00 PM" /></div>
          </div>
          <div class="grid grid-cols-2 gap-3">
            <div><label class="text-sm font-medium text-ink-600 mb-1 block">Delivery Fee (₦)</label><input v-model.number="form.delivery_fee" type="number" class="input" /></div>
            <div class="flex items-end"><label class="flex items-center gap-2 cursor-pointer"><input v-model="form.delivery_enabled" type="checkbox" class="accent-brand-600 w-5 h-5" /><span class="text-sm font-medium text-ink-600">Delivery enabled</span></label></div>
          </div>
        </div>
        <div class="flex gap-2 mt-5">
          <button @click="showForm = false" class="btn-outline flex-1">Cancel</button>
          <button @click="save" :disabled="saving || !form.name || !form.address" class="btn-primary flex-1 disabled:opacity-50">{{ saving ? 'Saving...' : 'Save' }}</button>
        </div>
      </div>
    </div>
  </div>
</template>
