import { useEffect, useRef, useState, useMemo } from 'react'
import { fetchCities, fetchRoutes } from './api.js'
import BrazilMap from './components/BrazilMap.jsx'

export default function App() {
  const [cities, setCities]               = useState([])
  const [routes, setRoutes]               = useState([])
  const [loading, setLoading]             = useState(true)
  const [error, setError]                 = useState(null)
  // ordered array of keys — newest first
  const [selectedOrder, setSelectedOrder] = useState([])
  const [activeLayer, setActiveLayer]     = useState('seller_order_count')
  const [showAllRoutes, setShowAllRoutes]  = useState(false)
  const showAllRoutesRef = useRef(false)
  const [topRoutes, setTopRoutes]         = useState(50)
  const [routesPerCity, setRoutesPerCity]  = useState(50)
  const [routesShown, setRoutesShown]     = useState(0)
  const [visibleRouteData, setVisibleRouteData] = useState([])
  const [viewMode, setViewMode]           = useState('seller')
  const [searchTerm, setSearchTerm]       = useState('')
  const [searchFocused, setSearchFocused] = useState(false)
  const [panelWidth, setPanelWidth]       = useState(280)
  const draggingRef                       = useRef(false)
  const searchRef                         = useRef(null)

  useEffect(() => {
    Promise.all([fetchCities(), fetchRoutes()])
      .then(([c, r]) => {
        const enriched = c.map(city => ({
          ...city,
          both_order_count: (city.seller_order_count || 0) + (city.buyer_order_count || 0),
          both_gmv:         (city.seller_revenue     || 0) + (city.buyer_spend        || 0),
        }))
        setCities(enriched)
        setRoutes(r)
      })
      .catch(e => setError(e.message))
      .finally(() => setLoading(false))
  }, [])

  const cityKey = (c) => c.city_key || `${c.city}|${c.state}`
  const selectedKeys = useMemo(() => new Set(selectedOrder), [selectedOrder])

  const addCity = (city) => {
    const k = cityKey(city)
    setSelectedOrder(prev => {
      if (prev.includes(k)) return prev          // already selected, no change
      return [k, ...prev]                        // newest first
    })
  }

  const removeCity = (city) => {
    const k = cityKey(city)
    setSelectedOrder(prev => prev.filter(x => x !== k))
  }

  const exitShowAll = () => {
    showAllRoutesRef.current = false
    setShowAllRoutes(false)
    setVisibleRouteData([])
    setSelectedOrder([])
  }

  const toggleCity = (city) => {
    const k = cityKey(city)
    if (showAllRoutesRef.current) {
      // exit show-all and select only this city in one step
      showAllRoutesRef.current = false
      setShowAllRoutes(false)
      setVisibleRouteData([])
      setSelectedOrder([k])
      return
    }
    setSelectedOrder(prev =>
      prev.includes(k) ? prev.filter(x => x !== k) : [k, ...prev]
    )
  }

  // Search dropdown matches
  const searchMatches = useMemo(() => {
    const q = searchTerm.trim().toLowerCase()
    if (!q || q.length < 1) return []
    return cities
      .filter(c => c.city?.toLowerCase().includes(q))
      .slice(0, 8)
  }, [searchTerm, cities])

  const handleSearchSelect = (city) => {
    const k = cityKey(city)
    setSearchTerm('')
    setSearchFocused(false)
    if (showAllRoutesRef.current) {
      showAllRoutesRef.current = false
      setShowAllRoutes(false)
      setVisibleRouteData([])
      setSelectedOrder([k])
    } else {
      setSelectedOrder(prev => prev.includes(k) ? prev : [k, ...prev])
    }
  }

  const handleShowAll = () => {
    showAllRoutesRef.current = true
    setShowAllRoutes(true)
    setSelectedOrder([])
  }

  // When show-all fires and we get visible routes back, populate panel with those cities
  useEffect(() => {
    if (!showAllRoutesRef.current || visibleRouteData.length === 0) return
    const keys = new Set()
    for (const r of visibleRouteData) {
      const sk = r.seller_key   || `${r.seller_city}|${r.seller_state}`.toLowerCase()
      const ck = r.customer_key || `${r.customer_city}|${r.customer_state}`.toLowerCase()
      keys.add(sk); keys.add(ck)
    }
    const involved = cities.filter(c => keys.has(cityKey(c)))
    // sort by activeLayer descending, newest-first semantics: highest value = top
    const sorted = [...involved].sort((a, b) => (b[activeLayer] ?? 0) - (a[activeLayer] ?? 0))
    setSelectedOrder(sorted.map(cityKey))
  }, [showAllRoutes, visibleRouteData])

  const handleClear = () => {
    showAllRoutesRef.current = false
    setShowAllRoutes(false)
    setSelectedOrder([])
    setVisibleRouteData([])
  }

  const layerDefs = {
    seller: [
      { key: 'seller_order_count',  label: 'Order count',  color: 'var(--color-blue)' },
      { key: 'seller_revenue',      label: 'Order value',  color: 'var(--color-green)' },
      { key: 'seller_avg_distance', label: 'Avg distance', color: 'var(--color-orange)' },
      { key: 'seller_avg_freight',  label: 'Avg freight',  color: 'var(--color-purple)' },
    ],
    buyer: [
      { key: 'buyer_order_count',   label: 'Order count',  color: 'var(--color-blue)' },
      { key: 'buyer_spend',         label: 'Order value',  color: 'var(--color-green)' },
      { key: 'buyer_avg_distance',  label: 'Avg distance', color: 'var(--color-orange)' },
      { key: 'buyer_avg_freight',   label: 'Avg freight',  color: 'var(--color-purple)' },
    ],
    both: [
      { key: 'both_order_count',    label: 'Order count',  color: 'var(--color-blue)' },
      { key: 'both_gmv',            label: 'Order value',  color: 'var(--color-green)' },
    ],
  }

  const handleViewMode = (mode) => {
    const oldSlot = layerDefs[viewMode].findIndex(l => l.key === activeLayer)
    const newLayers = layerDefs[mode]
    setViewMode(mode)
    setActiveLayer(newLayers[Math.min(oldSlot < 0 ? 0 : oldSlot, newLayers.length - 1)].key)
  }

  const layers = layerDefs[viewMode]
  const selCount = selectedOrder.length

  // Ordered selected cities (newest first = selectedOrder order)
  const cityMap = useMemo(() => {
    const m = {}
    for (const c of cities) m[cityKey(c)] = c
    return m
  }, [cities])
  const selectedCities = selectedOrder.map(k => cityMap[k]).filter(Boolean)

  // Divider drag
  const onDividerMouseDown = (e) => {
    e.preventDefault()
    draggingRef.current = true
    const onMove = (ev) => {
      if (!draggingRef.current) return
      setPanelWidth(Math.max(180, Math.min(ev.clientX, window.innerWidth - 300)))
    }
    const onUp = () => {
      draggingRef.current = false
      window.removeEventListener('mousemove', onMove)
      window.removeEventListener('mouseup', onUp)
    }
    window.addEventListener('mousemove', onMove)
    window.addEventListener('mouseup', onUp)
  }

  const fmt  = (n) => n != null ? Number(n).toLocaleString() : '—'
  const fmtR = (n) => n != null ? `R$ ${Number(n).toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}` : '—'

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100vh' }}>

      {/* Header */}
      <div style={{
        padding: '6px 16px', background: 'var(--color-surface)',
        borderBottom: '1px solid var(--color-border)',
        display: 'flex', alignItems: 'center', gap: '12px', flexShrink: 0, flexWrap: 'wrap',
      }}>
        <span style={{ fontWeight: 700, fontSize: '15px' }}>🇧🇷 Olist Trade Routes</span>
        <span style={{ color: 'var(--color-muted)', fontSize: '12px' }}>
          {loading ? 'Loading…' : error ? `Error: ${error}` : `${cities.length} cities · ${routes.length} routes`}
        </span>

        {/* View mode */}
        <div style={{ display: 'flex', gap: '4px', background: 'var(--color-border)', borderRadius: '6px', padding: '2px' }}>
          {[['seller', 'Seller'], ['buyer', 'Buyer'], ['both', 'Both']].map(([mode, label]) => (
            <button key={mode} className={viewMode === mode ? 'active' : ''}
              onClick={() => handleViewMode(mode)} style={{ fontSize: '11px', padding: '2px 10px' }}>
              {label}
            </button>
          ))}
        </div>

        {/* Layer toggle */}
        <div style={{ display: 'flex', gap: '6px' }}>
          {layers.map(l => (
            <button key={l.key} className={activeLayer === l.key ? 'active' : ''}
              onClick={() => setActiveLayer(l.key)}
              style={{ borderColor: activeLayer === l.key ? l.color : undefined, color: activeLayer === l.key ? l.color : undefined }}>
              {l.label}
            </button>
          ))}
        </div>

        {/* Route controls (per-city slider only) */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginLeft: 'auto' }}>
          {selCount > 0 && !showAllRoutes && (
            <span style={{ display: 'flex', alignItems: 'center', gap: '5px', fontSize: '12px' }}>
              <span style={{ color: 'var(--color-muted)' }}>Routes per city:</span>
              <input type="range" min={5} max={500} step={5} value={routesPerCity}
                onChange={e => setRoutesPerCity(Number(e.target.value))}
                style={{ width: '70px', accentColor: 'var(--color-blue)' }} />
              <span style={{ color: 'var(--color-text)', minWidth: '24px' }}>{routesPerCity}</span>
            </span>
          )}
          {routesShown > 0 && <span style={{ color: 'var(--color-muted)', fontSize: '12px' }}>{routesShown} routes shown</span>}
        </div>
      </div>

      {/* Body: panel + divider + map */}
      <div style={{ flex: 1, display: 'flex', overflow: 'hidden' }}>

        {/* Left panel */}
        <div style={{
          width: panelWidth, flexShrink: 0, display: 'flex', flexDirection: 'column',
          background: 'var(--color-surface)', borderRight: '1px solid var(--color-border)',
          overflow: 'hidden',
        }}>
          {/* Panel controls — fixed, not scrollable */}
          <div style={{ padding: '8px', borderBottom: '1px solid var(--color-border)', flexShrink: 0 }}>

            {/* Show top routes + Clear */}
            <div style={{ display: 'flex', gap: '6px', marginBottom: '8px' }}>
              <button
                onClick={handleShowAll}
                className={showAllRoutes ? 'active' : ''}
                style={{ flex: 1, fontSize: '11px' }}
              >
                Show top routes
              </button>
              {showAllRoutes && (
                <>
                  <input type="range" min={10} max={100} step={10} value={topRoutes}
                    onChange={e => setTopRoutes(Number(e.target.value))}
                    style={{ width: '60px', accentColor: 'var(--color-blue)' }} />
                  <span style={{ color: 'var(--color-text)', fontSize: '11px', minWidth: '24px', alignSelf: 'center' }}>{topRoutes}</span>
                </>
              )}
              <button
                onClick={handleClear}
                disabled={selCount === 0 && !showAllRoutes}
                style={{ fontSize: '11px' }}
              >
                Clear
              </button>
            </div>

            {/* Search with dropdown */}
            <div style={{ position: 'relative' }} ref={searchRef}>
              <input
                type="text"
                value={searchTerm}
                onChange={e => { setSearchTerm(e.target.value); setSearchFocused(true) }}
                onFocus={() => setSearchFocused(true)}
                onBlur={() => setTimeout(() => setSearchFocused(false), 150)}
                placeholder="Search and add city…"
                style={{
                  width: '100%', boxSizing: 'border-box',
                  background: 'var(--color-bg)', border: '1px solid var(--color-border)',
                  borderRadius: '4px', color: 'var(--color-text)', padding: '5px 8px',
                  fontSize: '12px',
                }}
              />
              {searchFocused && searchMatches.length > 0 && (
                <div style={{
                  position: 'absolute', top: '100%', left: 0, right: 0, zIndex: 1000,
                  background: 'var(--color-surface)', border: '1px solid var(--color-border)',
                  borderTop: 'none', borderRadius: '0 0 4px 4px',
                  maxHeight: '200px', overflowY: 'auto',
                }}>
                  {searchMatches.map(c => (
                    <div
                      key={cityKey(c)}
                      onMouseDown={() => handleSearchSelect(c)}
                      style={{
                        padding: '6px 10px', cursor: 'pointer', fontSize: '12px',
                        borderBottom: '1px solid var(--color-border)',
                        display: 'flex', justifyContent: 'space-between', alignItems: 'center',
                      }}
                      onMouseEnter={e => e.currentTarget.style.background = 'var(--color-border)'}
                      onMouseLeave={e => e.currentTarget.style.background = 'transparent'}
                    >
                      <span>{c.city}</span>
                      <span style={{ color: 'var(--color-muted)', fontSize: '11px' }}>{c.state}</span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>

          {/* Scrollable tiles */}
          <div style={{ flex: 1, overflowY: 'auto', padding: '8px', fontSize: '12px' }}>
            {selectedCities.length === 0 ? (
              <span style={{ color: 'var(--color-muted)' }}>Select cities on the map or search above.</span>
            ) : (
              selectedCities.map(c => {
                const hasSeller = c.seller_order_count > 0
                const hasBuyer  = c.buyer_order_count  > 0
                const k = cityKey(c)
                return (
                  <div key={k} style={{
                    background: 'var(--color-bg)', borderRadius: '8px', marginBottom: '8px',
                    border: '1px solid var(--color-border)', overflow: 'hidden',
                  }}>
                    <div style={{
                      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                      padding: '7px 10px', borderBottom: '1px solid var(--color-border)',
                      background: 'var(--color-surface)',
                    }}>
                      <span style={{ fontWeight: 700, fontSize: 13 }}>
                        {c.city} <span style={{ color: 'var(--color-muted)', fontWeight: 400, fontSize: 11 }}>{c.state}</span>
                      </span>
                      <button
                        onClick={() => removeCity(c)}
                        title="Deselect"
                        style={{
                          border: 'none', background: 'transparent', cursor: 'pointer',
                          color: 'var(--color-muted)', padding: '2px 4px', fontSize: 14, lineHeight: 1, borderRadius: 4,
                        }}
                        onMouseEnter={e => e.currentTarget.style.color = '#fc8181'}
                        onMouseLeave={e => e.currentTarget.style.color = 'var(--color-muted)'}
                      >🗑</button>
                    </div>
                    <div style={{ padding: '8px 10px' }}>
                      {(viewMode === 'seller' || viewMode === 'both') && hasSeller && <>
                        {viewMode === 'both' && <div style={{ color: '#68d391', fontSize: 10, marginBottom: 4, textTransform: 'uppercase', letterSpacing: '0.5px' }}>As seller</div>}
                        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 2 }}><span style={{ color: 'var(--color-muted)' }}>Order count</span><strong>{fmt(c.seller_order_count)}</strong></div>
                        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 2 }}><span style={{ color: 'var(--color-muted)' }}>Order value</span><span>{fmtR(c.seller_revenue)}</span></div>
                        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 2 }}><span style={{ color: 'var(--color-muted)' }}>Avg freight</span><span>{fmtR(c.seller_avg_freight)}</span></div>
                        <div style={{ display: 'flex', justifyContent: 'space-between' }}><span style={{ color: 'var(--color-muted)' }}>Avg distance</span><span>{fmt(c.seller_avg_distance)} km</span></div>
                      </>}
                      {(viewMode === 'buyer' || viewMode === 'both') && hasBuyer && <>
                        {viewMode === 'both' && <div style={{ color: '#63b3ed', fontSize: 10, marginTop: 8, marginBottom: 4, textTransform: 'uppercase', letterSpacing: '0.5px' }}>As buyer</div>}
                        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 2 }}><span style={{ color: 'var(--color-muted)' }}>Order count</span><strong>{fmt(c.buyer_order_count)}</strong></div>
                        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 2 }}><span style={{ color: 'var(--color-muted)' }}>Order value</span><span>{fmtR(c.buyer_spend)}</span></div>
                        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 2 }}><span style={{ color: 'var(--color-muted)' }}>Avg freight</span><span>{fmtR(c.buyer_avg_freight)}</span></div>
                        <div style={{ display: 'flex', justifyContent: 'space-between' }}><span style={{ color: 'var(--color-muted)' }}>Avg distance</span><span>{fmt(c.buyer_avg_distance)} km</span></div>
                      </>}
                    </div>
                  </div>
                )
              })
            )}
          </div>
        </div>

        {/* Divider */}
        <div
          onMouseDown={onDividerMouseDown}
          style={{ width: '5px', flexShrink: 0, cursor: 'col-resize', background: 'var(--color-border)', transition: 'background 0.15s' }}
          onMouseEnter={e => e.currentTarget.style.background = 'var(--color-blue)'}
          onMouseLeave={e => { if (!draggingRef.current) e.currentTarget.style.background = 'var(--color-border)' }}
        />

        {/* Map */}
        <div style={{ flex: 1, overflow: 'hidden' }}>
          {!loading && !error && (
            <BrazilMap
              cities={cities}
              routes={routes}
              selectedKeys={selectedKeys}
              selectedOrder={selectedOrder}
              onCityClick={toggleCity}
              activeLayer={activeLayer}
              showAllRoutes={showAllRoutes}
              topRoutes={topRoutes}
              routesPerCity={routesPerCity}
              onRoutesShown={setRoutesShown}
              onVisibleRoutes={setVisibleRouteData}
              viewMode={viewMode}
              isShowAllActive={showAllRoutes}
            />
          )}
          {loading && (
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: '100%', color: 'var(--color-muted)' }}>
              Loading data…
            </div>
          )}
          {error && (
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: '100%', color: '#fc8181' }}>
              {error}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
