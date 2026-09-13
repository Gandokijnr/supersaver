import { defineStore } from 'pinia'
import type { Branch } from '~/lib/types'

export const useBranchStore = defineStore('branch', () => {
  const supabase = useSupabase()
  const branches = ref<Branch[]>([])
  const currentBranch = ref<Branch | null>(null)
  const loading = ref(false)

  const branchId = computed(() => currentBranch.value?.id ?? null)

  async function loadBranches() {
    loading.value = true
    const { data, error } = await supabase
      .from('branches')
      .select('*')
      .order('sort_order')
    if (error) {
      loading.value = false
      throw error
    }
    branches.value = data as Branch[]
    loading.value = false
  }

  function setBranch(branch: Branch) {
    currentBranch.value = branch
    if (import.meta.client) {
      localStorage.setItem('ss_branch', JSON.stringify(branch))
    }
  }

  function restoreBranch() {
    if (!import.meta.client) return
    const saved = localStorage.getItem('ss_branch')
    if (saved) {
      try {
        currentBranch.value = JSON.parse(saved)
      } catch {
        localStorage.removeItem('ss_branch')
      }
    }
  }

  function clearBranch() {
    currentBranch.value = null
    if (import.meta.client) {
      localStorage.removeItem('ss_branch')
    }
  }

  return { branches, currentBranch, branchId, loading, loadBranches, setBranch, restoreBranch, clearBranch }
})
