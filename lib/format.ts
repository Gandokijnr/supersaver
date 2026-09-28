export function formatNaira(amount: number): string {
  return '\u20A6' + Math.round(amount).toLocaleString('en-NG')
}

export function discountPercent(price: number, compareAt: number | null): number | null {
  if (!compareAt || compareAt <= price) return null
  return Math.round(((compareAt - price) / compareAt) * 100)
}

export function generateSessionId(): string {
  if (import.meta.client) {
    let id = localStorage.getItem('ss_session_id')
    if (!id) {
      id = 'sess_' + crypto.randomUUID()
      localStorage.setItem('ss_session_id', id)
    }
    return id
  }
  return ''
}
