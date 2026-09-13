<script setup lang="ts">
const { login, isLoggedIn } = useAdminAuth()
const router = useRouter()

definePageMeta({ layout: false })

const email = ref('')
const password = ref('')
const error = ref('')
const loading = ref(false)

onMounted(() => {
  if (import.meta.client) {
    const { restore } = useAdminAuth()
    restore()
    if (isLoggedIn.value) router.push('/supersaver_ipass')
  }
})

async function doLogin() {
  error.value = ''
  loading.value = true
  const result = await login(email.value, password.value)
  loading.value = false
  if (result.success) {
    router.push('/supersaver_ipass')
  } else {
    error.value = result.error || 'Login failed'
  }
}
</script>

<template>
  <div class="min-h-screen bg-ink-900 flex items-center justify-center p-4">
    <div class="w-full max-w-md">
      <div class="text-center mb-8">
        <div class="w-14 h-14 bg-brand-600 rounded-2xl flex items-center justify-center mx-auto mb-4">
          <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z" /></svg>
        </div>
        <h1 class="text-2xl font-extrabold text-white">SuperSaver Admin</h1>
        <p class="text-ink-400 text-sm mt-1">Operations Console</p>
      </div>

      <div class="bg-white rounded-2xl p-6 shadow-xl">
        <h2 class="text-lg font-bold text-ink-800 mb-4">Sign in</h2>
        <form @submit.prevent="doLogin" class="space-y-4">
          <div>
            <label class="text-sm font-medium text-ink-600 mb-1 block">Email</label>
            <input v-model="email" type="email" class="input" placeholder="admin@supersaver.ng" required />
          </div>
          <div>
            <label class="text-sm font-medium text-ink-600 mb-1 block">Password</label>
            <input v-model="password" type="password" class="input" placeholder="••••••••" required />
          </div>
          <p v-if="error" class="text-sm text-accent-600 font-medium bg-accent-50 rounded-xl p-3">{{ error }}</p>
          <button type="submit" :disabled="loading" class="btn-primary w-full disabled:opacity-60">
            {{ loading ? 'Signing in...' : 'Sign In' }}
          </button>
        </form>
        <div class="mt-4 p-3 bg-ink-50 rounded-xl text-xs text-ink-500">
          <p class="font-semibold text-ink-600 mb-1">Demo credentials:</p>
          <p>Email: admin@supersaver.ng</p>
          <p>Password: admin123</p>
        </div>
      </div>
      <p class="text-center text-ink-500 text-xs mt-6"><NuxtLink to="/" class="hover:text-white">← Back to store</NuxtLink></p>
    </div>
  </div>
</template>
