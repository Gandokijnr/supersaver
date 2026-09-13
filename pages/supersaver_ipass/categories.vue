<script setup lang="ts">
definePageMeta({ layout: 'admin', middleware: 'admin' })

const supabase = useSupabase()
const categories = ref<any[]>([])
const loading = ref(true)
const showForm = ref(false)
const editCat = ref<any>(null)
const form = ref({ name: '', slug: '', sort_order: 0 })
const saving = ref(false)

onMounted(load)

async function load() {
  loading.value = true
  const { data } = await supabase.from('categories').select('*').order('sort_order')
  categories.value = data || []
  loading.value = false
}

function openCreate() { editCat.value = null; form.value = { name: '', slug: '', sort_order: 0 }; showForm.value = true }
function openEdit(c: any) { editCat.value = c; form.value = { name: c.name, slug: c.slug, sort_order: c.sort_order }; showForm.value = true }

async function save() {
  saving.value = true
  const slug = form.value.slug || form.value.name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '')
  try {
    if (editCat.value) {
      const { error } = await supabase.from('categories').update({ ...form.value, slug }).eq('id', editCat.value.id)
      if (error) throw error
    } else {
      const { error } = await supabase.from('categories').insert({ ...form.value, slug, is_active: true })
      if (error) throw error
    }
    showForm.value = false; await load()
  } catch (e: any) { alert(e.message) } finally { saving.value = false }
}

async function toggleActive(c: any) {
  await supabase.from('categories').update({ is_active: !c.is_active }).eq('id', c.id)
  await load()
}
</script>

<template>
  <div>
    <div class="flex items-center justify-between mb-6">
      <div><h1 class="text-2xl font-bold text-ink-800">Categories</h1><p class="text-sm text-ink-400 mt-1">Manage product categories</p></div>
      <button @click="openCreate" class="btn-primary text-sm">+ New Category</button>
    </div>
    <div v-if="loading" class="card p-5 space-y-3"><div v-for="n in 5" :key="n" class="h-10 skeleton rounded-xl" /></div>
    <div v-else class="grid sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-3">
      <div v-for="c in categories" :key="c.id" class="card p-4">
        <div class="flex items-start justify-between">
          <div><p class="font-bold text-ink-800">{{ c.name }}</p><p class="text-xs text-ink-400">{{ c.slug }}</p></div>
          <span :class="c.is_active ? 'bg-brand-100 text-brand-700' : 'bg-ink-100 text-ink-500'" class="badge">{{ c.is_active ? 'Active' : 'Inactive' }}</span>
        </div>
        <div class="flex gap-2 mt-3">
          <button @click="openEdit(c)" class="text-brand-600 text-xs font-semibold hover:text-brand-700">Edit</button>
          <button @click="toggleActive(c)" class="text-ink-400 text-xs font-semibold hover:text-ink-600 ml-3">{{ c.is_active ? 'Deactivate' : 'Activate' }}</button>
        </div>
      </div>
    </div>

    <div v-if="showForm" class="fixed inset-0 z-50 flex items-center justify-center bg-ink-900/50 p-4" @click.self="showForm = false">
      <div class="card p-6 max-w-sm w-full">
        <h2 class="text-lg font-bold text-ink-800 mb-4">{{ editCat ? 'Edit' : 'New' }} Category</h2>
        <div class="space-y-3">
          <div><label class="text-sm font-medium text-ink-600 mb-1 block">Name *</label><input v-model="form.name" class="input" /></div>
          <div><label class="text-sm font-medium text-ink-600 mb-1 block">Slug (optional)</label><input v-model="form.slug" class="input" placeholder="auto-generated" /></div>
          <div><label class="text-sm font-medium text-ink-600 mb-1 block">Sort Order</label><input v-model.number="form.sort_order" type="number" class="input" /></div>
        </div>
        <div class="flex gap-2 mt-5">
          <button @click="showForm = false" class="btn-outline flex-1">Cancel</button>
          <button @click="save" :disabled="saving || !form.name" class="btn-primary flex-1 disabled:opacity-50">{{ saving ? 'Saving...' : 'Save' }}</button>
        </div>
      </div>
    </div>
  </div>
</template>
