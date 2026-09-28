<script setup lang="ts">
const supabase = useSupabase()
const { user, restore } = useCustomerAuth()
const route = useRoute()
const mode = ref<'signin' | 'signup'>('signin')
const name = ref('')
const email = ref('')
const password = ref('')
const busy = ref(false)
const error = ref('')
const message = ref('')
const destination = computed(() => ['/profile', '/orders', '/checkout'].includes(String(route.query.next)) ? String(route.query.next) : '/profile')
onMounted(async () => {
  try { await restore(); if (user.value) await navigateTo(destination.value) } catch { error.value = 'Could not restore your session. Please sign in.' }
})
async function submit() {
  if (busy.value) return
  busy.value = true; error.value = ''; message.value = ''
  try {
    if (mode.value === 'signup') {
      if (!name.value.trim()) throw new Error('Please enter your name.')
      const { data, error: authError } = await supabase.auth.signUp({ email: email.value.trim(), password: password.value, options: { data: { name: name.value.trim() }, emailRedirectTo: `${window.location.origin}/profile` } })
      if (authError) throw authError
      if (!data.session) { message.value = 'Check your email to confirm your account, then sign in.'; password.value = ''; return }
    } else {
      const { error: authError } = await supabase.auth.signInWithPassword({ email: email.value.trim(), password: password.value })
      if (authError) throw authError
    }
    await restore()
    await navigateTo(destination.value)
  } catch (e: any) { error.value = e.message || 'Could not sign in. Please try again.' }
  finally { busy.value = false }
}
</script>

<template>
  <div class="max-w-md mx-auto px-4 py-8">
    <h1 class="text-2xl font-bold text-ink-800 mb-2">{{ mode === 'signup' ? 'Create an Account' : 'Sign In' }}</h1>
    <p class="text-sm text-ink-500 mb-6">Save your details and track your orders across devices.</p>
    <form class="card p-5 space-y-4" @submit.prevent="submit">
      <fieldset :disabled="busy" class="space-y-4">
        <label v-if="mode === 'signup'" class="block text-sm text-ink-600">Full name<input v-model="name" autocomplete="name" required class="input mt-1" /></label>
        <label class="block text-sm text-ink-600">Email<input v-model="email" type="email" autocomplete="email" required class="input mt-1" /></label>
        <label class="block text-sm text-ink-600">Password<input v-model="password" type="password" :autocomplete="mode === 'signup' ? 'new-password' : 'current-password'" :minlength="mode === 'signup' ? 8 : undefined" required class="input mt-1" /></label>
        <p v-if="mode === 'signup'" class="text-xs text-ink-400">Use at least 8 characters.</p>
        <p v-if="error" role="alert" class="text-sm text-red-600">{{ error }}</p>
        <p v-if="message" role="status" class="text-sm text-brand-700">{{ message }}</p>
        <button class="btn-primary w-full" type="submit">{{ busy ? 'Please wait...' : mode === 'signup' ? 'Create Account' : 'Sign In' }}</button>
        <button type="button" class="text-sm text-brand-600 w-full" @click="mode = mode === 'signup' ? 'signin' : 'signup'; error = ''; message = ''; password = ''">{{ mode === 'signup' ? 'Already have an account? Sign in' : 'New here? Create an account' }}</button>
      </fieldset>
    </form>
  </div>
</template>
