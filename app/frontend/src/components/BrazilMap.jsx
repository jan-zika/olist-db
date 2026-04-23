import { useEffect, useMemo, useRef, useState } from 'react'
import {
  MapContainer, TileLayer, CircleMarker, Polyline,
  Tooltip, LayerGroup, useMap, useMapEvents,
} from 'react-leaflet'
import 'leaflet/dist/leaflet.css'

const TILE_DARK  = 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
const TILE_LIGHT = 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png'
const ATTR = '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> &copy; <a href="https://carto.com/">CARTO</a>'

const BRAZIL_CENTER = [-14.2, -51.9]
const BRAZIL_ZOOM   = 4

// Normalised 0→1 → HSL gradient blue→red
function intensityColor(norm) {
  const hue = Math.round(220 - norm * 220)
  const sat = 80 + norm * 20
  const lit  = 45 + norm * 15
  return `hsl(${hue},${sat}%,${lit}%)`
}

function cityKey(c) {
  return c.city_key || `${c.city}|${c.state}`
}

// Log-scale radius: 4–28px
function cityRadius(value, min, max) {
  if (max <= min) return 8
  const norm = (Math.log1p(value) - Math.log1p(min)) / (Math.log1p(max) - Math.log1p(min))
  return 4 + norm * 24
}

// Route line weight: 1–7px, relative to max in shown set
function routeWeight(val, max) {
  if (max <= 0) return 1
  return 1 + Math.min((val / max) * 6, 6)
}

// Invalidate map size when the container resizes (handles divider drag)
function MapResizer({ containerRef }) {
  const map = useMap()
  useEffect(() => {
    if (!containerRef?.current) return
    const obs = new ResizeObserver(() => { map.invalidateSize() })
    obs.observe(containerRef.current)
    return () => obs.disconnect()
  }, [map, containerRef])
  return null
}

// Fly to last-added selected city
function FlyToSelected({ cities, selectedKeys }) {
  const map = useMap()
  const prevSize = useRef(0)
  useEffect(() => {
    if (selectedKeys.size !== prevSize.current + 1) { prevSize.current = selectedKeys.size; return }
    prevSize.current = selectedKeys.size
    const lastKey = [...selectedKeys].at(-1)
    const city = cities.find(c => cityKey(c) === lastKey)
    if (!city?.lat || !city?.lng) return
    map.flyTo([city.lat, city.lng], Math.max(map.getZoom(), 6), { duration: 0.6 })
  }, [selectedKeys.size])
  return null
}

// Close all open tooltips when the map is dragged
function DragTooltipClearer() {
  const map = useMapEvents({
    dragstart: () => { map.closePopup(); map.eachLayer(l => { if (l.closeTooltip) l.closeTooltip() }) },
  })
  return null
}

const fmt  = (n) => n != null ? Number(n).toLocaleString() : '—'
const fmtR = (n) => n != null
  ? `R$ ${Number(n).toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
  : '—'

export default function BrazilMap({
  cities, routes, selectedKeys, onCityClick,
  activeLayer, showAllRoutes, topRoutes, routesPerCity, onRoutesShown, onVisibleRoutes, viewMode, isShowAllActive,
}) {
  const [darkMode, setDarkMode] = useState(true)
  const mapRef = useRef(null)

  const anySelected = selectedKeys.size > 0

  // Circle size & color scale — only include cities that will actually be rendered
  const renderedCities = cities.filter(c => {
    if (!c.lat || !c.lng) return false
    if (viewMode === 'seller' && c.seller_order_count === 0) return false
    if (viewMode === 'buyer'  && c.buyer_order_count  === 0) return false
    return true
  })
  const sizeValues = renderedCities.map(c => c[activeLayer] ?? 0).filter(v => v > 0)
  const sizeMin = sizeValues.length ? Math.min(...sizeValues) : 0
  const sizeMax = sizeValues.length ? Math.max(...sizeValues) : 1

  function cityColor(c) {
    const val  = c[activeLayer] ?? 0
    const norm = sizeMax > sizeMin ? (val - sizeMin) / (sizeMax - sizeMin) : 0
    return intensityColor(norm)
  }

  // Map active layer → route sort field
  const routeSortKey = (() => {
    if (activeLayer.includes('order_count'))                                     return 'order_count'
    if (activeLayer.includes('revenue') || activeLayer.includes('spend') || activeLayer.includes('gmv')) return 'total_revenue'
    if (activeLayer.includes('distance'))                                        return 'avg_distance_km'
    if (activeLayer.includes('freight'))                                         return 'avg_freight'
    return 'order_count'
  })()

  const visibleRoutes = useMemo(() => {
    const sortDesc = (arr) => [...arr].sort((a, b) => (b[routeSortKey] ?? 0) - (a[routeSortKey] ?? 0))

    if (showAllRoutes) return sortDesc(routes).slice(0, topRoutes)
    if (!anySelected)  return []

    const lowerKeys = new Set([...selectedKeys].map(k => k.toLowerCase()))
    const byCity = {}
    for (const r of routes) {
      const sk = r.seller_key   || `${r.seller_city}|${r.seller_state}`.toLowerCase()
      const ck = r.customer_key || `${r.customer_city}|${r.customer_state}`.toLowerCase()
      let matchKey = null
      if      (viewMode === 'buyer' && lowerKeys.has(ck))                       matchKey = ck
      else if (viewMode === 'both'  && (lowerKeys.has(sk) || lowerKeys.has(ck))) matchKey = sk
      else if (lowerKeys.has(sk))                                                matchKey = sk
      if (!matchKey) continue
      if (!byCity[matchKey]) byCity[matchKey] = []
      byCity[matchKey].push(r)
    }
    const result = []
    for (const cr of Object.values(byCity)) result.push(...sortDesc(cr).slice(0, routesPerCity))
    return result
  }, [routes, selectedKeys, showAllRoutes, viewMode, topRoutes, routesPerCity, routeSortKey])

  useEffect(() => { onRoutesShown(visibleRoutes.length) }, [visibleRoutes.length])
  useEffect(() => { onVisibleRoutes(visibleRoutes) }, [visibleRoutes])

  // Route color & thickness: normalised 0→max so the full gradient is always used
  const routeMax = visibleRoutes.length
    ? Math.max(...visibleRoutes.map(r => r[routeSortKey] ?? 0))
    : 1

  function routeColor(r) {
    const norm = routeMax > 0 ? (r[routeSortKey] ?? 0) / routeMax : 0
    return intensityColor(norm)
  }

  const maxRouteSortVal = routeMax || 1

  // Cities to show in show-all mode: only those in visible routes
  const activeRouteKeys = useMemo(() => {
    if (!showAllRoutes || visibleRoutes.length === 0) return null
    const keys = new Set()
    for (const r of visibleRoutes) {
      keys.add(r.seller_key   || `${r.seller_city}|${r.seller_state}`.toLowerCase())
      keys.add(r.customer_key || `${r.customer_city}|${r.customer_state}`.toLowerCase())
    }
    return keys
  }, [showAllRoutes, visibleRoutes])

  // Destination endpoint circles
  const visibleDestinations = useMemo(() => {
    if (visibleRoutes.length === 0) return []
    const seen = new Set()
    const result = []
    for (const r of visibleRoutes) {
      if (!r.customer_lat || !r.customer_lng) continue
      const k = r.customer_key || `${r.customer_city}|${r.customer_state}`.toLowerCase()
      if (!seen.has(k)) {
        seen.add(k)
        result.push({ lat: r.customer_lat, lng: r.customer_lng, city: r.customer_city, state: r.customer_state, key: k })
      }
    }
    return result
  }, [visibleRoutes])

  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      <div ref={mapRef} style={{ flex: 1, position: 'relative' }}>
        <MapContainer
          center={BRAZIL_CENTER}
          zoom={BRAZIL_ZOOM}
          style={{ height: '100%', width: '100%' }}
          boxZoom={false}
        >
          <TileLayer attribution={ATTR} url={darkMode ? TILE_DARK : TILE_LIGHT} key={darkMode ? 'dark' : 'light'} />
          <MapResizer containerRef={mapRef} />
          <FlyToSelected cities={cities} selectedKeys={selectedKeys} />
          <DragTooltipClearer />

          {/* ── Route lines ── */}
          {visibleRoutes.length > 0 && (
            <LayerGroup>
              {visibleRoutes.map((r, i) => {
                if (!r.seller_lat || !r.seller_lng || !r.customer_lat || !r.customer_lng) return null
                const w = routeWeight(r[routeSortKey] ?? 0, maxRouteSortVal)
                const color = routeColor(r)
                return (
                  <Polyline
                    key={i}
                    positions={[[r.seller_lat, r.seller_lng], [r.customer_lat, r.customer_lng]]}
                    pathOptions={{ color, weight: w, opacity: 0.6, interactive: false }}
                  >
                    <Tooltip sticky>
                      <div style={{ fontWeight: 700 }}>{r.seller_city} → {r.customer_city}</div>
                      <div>{fmt(r.order_count)} orders · {fmt(r.avg_distance_km)} km</div>
                      <div>Avg freight: {fmtR(r.avg_freight)}</div>
                      <div>Revenue: {fmtR(r.total_revenue)}</div>
                    </Tooltip>
                  </Polyline>
                )
              })}
            </LayerGroup>
          )}

          {/* ── Destination endpoint circles ── */}
          {visibleDestinations.length > 0 && (
            <LayerGroup>
              {visibleDestinations.map(d => (
                <CircleMarker key={d.key} center={[d.lat, d.lng]} radius={5}
                  pathOptions={{ color: '#fff', weight: 1.5, fillColor: '#a0aec0', fillOpacity: 0.7, interactive: false }}
                />
              ))}
            </LayerGroup>
          )}

          {/* ── City circles ── */}
          <LayerGroup>
            {cities.map((c) => {
              if (!c.lat || !c.lng) return null
              if (viewMode === 'seller' && c.seller_order_count === 0) return null
              if (viewMode === 'buyer'  && c.buyer_order_count  === 0) return null
              if (activeRouteKeys && !activeRouteKeys.has(cityKey(c))) return null

              const key        = cityKey(c)
              const isSelected = selectedKeys.has(key)
              const isDimmed   = anySelected && !isSelected
              const val        = c[activeLayer] ?? 0
              const r          = cityRadius(val, sizeMin, sizeMax)
              const fill       = cityColor(c)
              const hasSeller  = c.seller_order_count > 0
              const hasBuyer   = c.buyer_order_count  > 0

              return (
                <CircleMarker
                  key={key}
                  center={[c.lat, c.lng]}
                  radius={isSelected ? r + 4 : r}
                  pathOptions={{
                    color:       isSelected ? '#fff' : fill,
                    weight:      isSelected ? 2.5 : 1,
                    fillColor:   fill,
                    fillOpacity: isDimmed ? 0.15 : isSelected ? 0.95 : 0.75,
                    opacity:     isDimmed ? 0.3 : 1,
                  }}
                  eventHandlers={{ click: (e) => { e.originalEvent.stopPropagation(); onCityClick(c) } }}
                >
                  <Tooltip direction="top" permanent={false}>
                    <div style={{ fontWeight: 700 }}>{c.city} ({c.state})</div>
                    {(viewMode === 'seller' || viewMode === 'both') && hasSeller && <>
                      {viewMode === 'both' && <div style={{ color: '#68d391', fontSize: 11, marginTop: 4 }}>As seller</div>}
                      <div>Order count: <strong>{fmt(c.seller_order_count)}</strong></div>
                      <div>Order value: {fmtR(c.seller_revenue)}</div>
                      <div>Avg freight: {fmtR(c.seller_avg_freight)}</div>
                      <div>Avg distance: {fmt(c.seller_avg_distance)} km</div>
                    </>}
                    {(viewMode === 'buyer' || viewMode === 'both') && hasBuyer && <>
                      {viewMode === 'both' && <div style={{ color: '#63b3ed', fontSize: 11, marginTop: 4 }}>As buyer</div>}
                      <div>Order count: <strong>{fmt(c.buyer_order_count)}</strong></div>
                      <div>Order value: {fmtR(c.buyer_spend)}</div>
                      <div>Avg freight: {fmtR(c.buyer_avg_freight)}</div>
                      <div>Avg distance: {fmt(c.buyer_avg_distance)} km</div>
                    </>}
                    <div style={{ color: '#a0aec0', fontSize: 11, marginTop: 3 }}>
                      {isShowAllActive ? 'Click to select this city' : isSelected ? 'Click to deselect' : 'Click to select'}
                    </div>
                  </Tooltip>
                </CircleMarker>
              )
            })}
          </LayerGroup>

        </MapContainer>
      </div>

      {/* Legend bar */}
      <div style={{
        display: 'flex', gap: '16px', padding: '5px 12px',
        background: 'var(--color-surface)', borderTop: '1px solid var(--color-border)',
        fontSize: '11px', alignItems: 'center', flexShrink: 0, flexWrap: 'wrap',
      }}>
        <span style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
          <span style={{ color: 'var(--color-muted)' }}>Color (circles &amp; routes):</span>
          <span style={{
            display: 'inline-block', width: '60px', height: '10px', borderRadius: '3px',
            background: 'linear-gradient(to right, hsl(220,80%,45%), hsl(110,90%,50%), hsl(0,100%,50%))',
          }} />
          <span style={{ color: 'var(--color-muted)' }}>{activeLayer.replace(/_/g, ' ')} low→high</span>
        </span>
        <span style={{ marginLeft: 'auto' }}>
          <button onClick={() => setDarkMode(d => !d)} style={{ fontSize: '11px', padding: '2px 8px' }}>
            {darkMode ? '☀ Light' : '🌙 Dark'}
          </button>
        </span>
      </div>
    </div>
  )
}
