const BASE = import.meta.env.VITE_API_URL || ''

export async function fetchCities() {
  const url = BASE ? `${BASE}/api/cities` : '/cities.json'
  const res = await fetch(url)
  if (!res.ok) throw new Error(`cities: ${res.status}`)
  return res.json()
}

export async function fetchRoutes() {
  const url = BASE ? `${BASE}/api/routes` : '/routes.json'
  const res = await fetch(url)
  if (!res.ok) throw new Error(`routes: ${res.status}`)
  return res.json()
}
