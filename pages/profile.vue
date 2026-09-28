<script setup lang="ts">
const { profile, restore, save } = useCustomerProfile()
const { user, signOut } = useCustomerAuth()
const loading = ref(true)
const saving = ref(false)
const branchStore = useBranchStore()
const form = reactive({ name: '', phone: '', email: '', address: '' })
const saved = ref(false)
const error = ref('')

onMounted(async () => {
  try { await restore(); Object.assign(form, profile.value) }
  catch { error.value = 'Could not load your profile. Please reload and try again.' }
  finally { loading.value = false }
})
watch(() => user.value?.id, () => { Object.assign(form, { name: '', phone: '', email: '', address: '' }); saved.value = false })

async function logout() {
  try { await signOut(); await navigateTo('/account') }
  catch { error.value = 'Could not sign out. Please try again.' }
}

async function saveProfile() {
  if (saving.value) return
  saved.value = false
  error.value = ''
  if (!form.name.trim()) { error.value = 'Please enter your name.'; return }
  try {
    saving.value = true
    await save(form)
    saved.value = true
  } catch {
    error.value = 'Could not save your profile. Please try again.'
  } finally { saving.value = false }
}
</script>

<template>
  <div class="max-w-2xl mx-auto px-4 py-6 md:py-10">
    <h1 class="text-2xl font-bold text-ink-800 mb-2">My Profile</h1>
    <p class="text-sm text-ink-500 mb-6">Manage your account details and track your orders.</p>
    <p v-if="loading" role="status">Loading profile...</p>
    <div v-else-if="!user" class="card p-5">
      <p class="text-ink-600 mb-4">Sign in or create an account to save your profile and track orders across devices.</p>
      <NuxtLink to="/account" class="btn-primary inline-block">Sign In / Create Account</NuxtLink>
    </div>
    <form v-else class="card p-5 space-y-4" @submit.prevent="saveProfile" @input="saved = false">
      <div>
        <label for="profile-name" class="block text-sm font-medium text-ink-600 mb-1">Full name *</label>
        <input id="profile-name" v-model="form.name" autocomplete="name" required class="input" />
      </div>
      <div>
        <label for="profile-phone" class="block text-sm font-medium text-ink-600 mb-1">Phone number</label>
        <input id="profile-phone" v-model="form.phone" type="tel" autocomplete="tel" class="input" />
      </div>
      <div>
        <label for="profile-email" class="block text-sm font-medium text-ink-600 mb-1">Email</label>
        <input id="profile-email" :value="user.email" type="email" readonly class="input bg-ink-50" />
      </div>
      <div>
        <label for="profile-address" class="block text-sm font-medium text-ink-600 mb-1">Delivery address</label>
        <textarea id="profile-address" v-model="form.address" autocomplete="street-address" rows="3" class="input" />
      </div>
      <p v-if="error" role="alert" class="text-sm text-red-600">{{ error }}</p>
      <p v-if="saved" role="status" class="text-sm text-brand-700">Profile saved.</p>
      <button type="submit" :disabled="saving" class="btn-primary w-full">{{ saving ? 'Saving...' : 'Save Profile' }}</button>
      <button type="button" class="btn-outline w-full" @click="logout">Sign Out</button>
    </form>
    <div class="card p-5 mt-4 space-y-4">
      <div class="flex items-center justify-between gap-3">
        <div><p class="text-xs text-ink-400">Shopping branch</p><p class="font-semibold text-ink-800">{{ branchStore.currentBranch?.name || 'No branch selected' }}</p></div>
        <NuxtLink to="/select-branch" class="text-sm text-brand-600 font-semibold">Change</NuxtLink>
      </div>
      <NuxtLink to="/orders" class="block text-sm text-brand-600 font-semibold">View My Orders →</NuxtLink>
    </div>
  </div>
</template>
