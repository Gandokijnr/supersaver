import { createClient } from '@supabase/supabase-js'

let client: ReturnType<typeof createClient> | null = null

export function useSupabase() {
  const config = useRuntimeConfig()
  if (!client) {
    client = createClient(
      config.public.supabaseUrl,
      config.public.supabaseAnonKey,
      {
        auth: { persistSession: import.meta.client, autoRefreshToken: import.meta.client, detectSessionInUrl: import.meta.client },
        global: {
          fetch: (input, init) => {
            const headers = new Headers(init?.headers)
            if (import.meta.client) {
              const session = localStorage.getItem('ss_session_id')
              const adminSession = localStorage.getItem('ss_admin_token')
              if (session) headers.set('x-cart-session', session)
              if (adminSession && window.location.pathname.startsWith('/supersaver_ipass')) headers.set('x-admin-session', adminSession)
            }
            return fetch(input, { ...init, headers })
          },
        },
      }
    )
  }
  return client
}
