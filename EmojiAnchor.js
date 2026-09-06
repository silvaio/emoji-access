function parseJson(raw, fallback) {
  try {
    var data = JSON.parse(String(raw || ""))
    return data === undefined || data === null ? fallback : data
  } catch (e) {
    return fallback
  }
}

function parseContext(raw) {
  var data = parseJson(raw, {})
  if (!data || typeof data !== "object") data = {}
  var cursor = data.cursor && typeof data.cursor === "object" ? data.cursor : {}
  return {
    cursor: {
      x: Number(cursor.x) || 0,
      y: Number(cursor.y) || 0
    },
    window: data.window && typeof data.window === "object" ? data.window : {},
    monitors: Array.isArray(data.monitors) ? data.monitors : []
  }
}

function windowAddress(window) {
  if (!window || typeof window !== "object") return ""
  var addr = String(window.address || "")
  if (!addr || addr === "0x0" || addr === "0") return ""
  return addr
}

function windowClass(window) {
  if (!window || typeof window !== "object") return ""
  return String(window.class || window.initialClass || "")
}

function isBrowserClass(value) {
  var cls = String(value || "").toLowerCase()
  if (!cls) return false
  var names = [
    "chromium", "chrome", "brave", "firefox", "librewolf",
    "vivaldi", "microsoft-edge", "zen", "thorium", "opera", "ungoogled"
  ]
  for (var i = 0; i < names.length; i++) {
    if (cls.indexOf(names[i]) >= 0) return true
  }
  return false
}

function monitorForCursor(monitors, cursor) {
  var list = Array.isArray(monitors) ? monitors : []
  var x = Number(cursor && cursor.x)
  var y = Number(cursor && cursor.y)
  if (isNaN(x)) x = 0
  if (isNaN(y)) y = 0
  var i
  for (i = 0; i < list.length; i++) {
    var m = list[i]
    if (!m) continue
    var mx = Number(m.x) || 0
    var my = Number(m.y) || 0
    var mw = Number(m.width) || 0
    var mh = Number(m.height) || 0
    if (mw <= 0 || mh <= 0) continue
    if (x >= mx && y >= my && x < mx + mw && y < my + mh) return m
  }
  for (i = 0; i < list.length; i++) {
    if (list[i] && list[i].focused) return list[i]
  }
  return list[0] || null
}

function centerCard(panelW, panelH, cardW, cardH) {
  var pw = Number(panelW) || 0
  var ph = Number(panelH) || 0
  var cw = Number(cardW) || 0
  var ch = Number(cardH) || 0
  return {
    x: Math.round(Math.max(0, (pw - cw) / 2)),
    y: Math.round(Math.max(0, (ph - ch) / 2))
  }
}

function placeCard(cursorX, cursorY, monitor, panelW, panelH, cardW, cardH, gap) {
  var pad = Number(gap)
  if (isNaN(pad) || pad < 0) pad = 12
  var mx = Number(monitor && monitor.x) || 0
  var my = Number(monitor && monitor.y) || 0
  var mw = Number(monitor && monitor.width) || 0
  var mh = Number(monitor && monitor.height) || 0
  var pw = Number(panelW) || mw
  var ph = Number(panelH) || mh
  var cw = Number(cardW) || 0
  var ch = Number(cardH) || 0
  if (pw <= 0 || ph <= 0 || cw <= 0 || ch <= 0) return { x: 0, y: 0 }

  var scaleX = mw > 0 ? pw / mw : 1
  var scaleY = mh > 0 ? ph / mh : 1
  var x = (Number(cursorX) - mx) * scaleX
  var y = (Number(cursorY) - my) * scaleY
  if (isNaN(x)) x = 0
  if (isNaN(y)) y = 0

  var posX = x + pad
  var posY = y + pad
  if (posY + ch + pad > ph) posY = y - ch - pad
  if (posX + cw + pad > pw) posX = x - cw - pad
  if (posX < pad) posX = pad
  if (posY < pad) posY = pad
  if (posX + cw + pad > pw) posX = Math.max(pad, pw - cw - pad)
  if (posY + ch + pad > ph) posY = Math.max(pad, ph - ch - pad)
  return { x: Math.round(posX), y: Math.round(posY) }
}

if (typeof module !== "undefined") {
  module.exports = {
    parseContext: parseContext,
    windowAddress: windowAddress,
    windowClass: windowClass,
    isBrowserClass: isBrowserClass,
    monitorForCursor: monitorForCursor,
    centerCard: centerCard,
    placeCard: placeCard
  }
}
