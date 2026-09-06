var CATEGORY_META = [
  { id: "recent", name: "Recent", icon: "🕒" },
  { id: "smileys", name: "Smileys", icon: "😀" },
  { id: "people", name: "People", icon: "👋" },
  { id: "nature", name: "Nature", icon: "🐻" },
  { id: "food", name: "Food", icon: "🍔" },
  { id: "travel", name: "Travel", icon: "✈️" },
  { id: "activities", name: "Activities", icon: "⚽" },
  { id: "objects", name: "Objects", icon: "💡" },
  { id: "symbols", name: "Symbols", icon: "❤️" },
  { id: "flags", name: "Flags", icon: "🏳️" }
]

var DEFAULT_RECENT_LIMIT = 48
var DEFAULT_SEARCH_LIMIT = 120
var COMMON_BONUS = {
  "😂": 80, "❤️": 80, "❤": 80, "👍": 80, "👎": 40, "🔥": 60,
  "😭": 60, "😊": 50, "😍": 50, "🙏": 50, "🤣": 50, "🥰": 40,
  "✨": 40, "🤔": 40, "😅": 30, "🎉": 30, "💯": 30, "👋": 30,
  "💔": 20, "🥺": 40, "💀": 30, "😉": 20, "😘": 20, "😎": 30
}

function parseEmojis(raw) {
  try {
    var data = JSON.parse(String(raw || ""))
    if (!Array.isArray(data)) return []
    var out = []
    for (var i = 0; i < data.length; i++) {
      var item = normalizeItem(data[i])
      if (item) out.push(item)
    }
    return out
  } catch (e) {
    return []
  }
}

function normalizeItem(item) {
  if (!item || !item.e) return null
  var emoji = String(item.e)
  if (!emoji) return null
  return {
    e: emoji,
    n: String(item.n || item.k || emoji),
    k: String(item.k || item.n || ""),
    c: String(item.c || "symbols")
  }
}

function indexByEmoji(emojis) {
  var values = Array.isArray(emojis) ? emojis : []
  var map = {}
  for (var i = 0; i < values.length; i++) {
    var item = values[i]
    if (item && item.e && !map[item.e]) map[item.e] = item
  }
  return map
}

function parseState(raw) {
  try {
    var data = JSON.parse(String(raw || ""))
    if (!data || typeof data !== "object") return { recents: [] }
    return { recents: sanitizeRecents(data.recents) }
  } catch (e) {
    return { recents: [] }
  }
}

function serializeState(state) {
  var recents = sanitizeRecents(state && state.recents)
  return JSON.stringify({ recents: recents }, null, 2) + "\n"
}

function sanitizeRecents(values) {
  var list = Array.isArray(values) ? values : []
  var out = []
  var seen = {}
  for (var i = 0; i < list.length; i++) {
    var emoji = String(list[i] || "")
    if (!emoji || seen[emoji]) continue
    seen[emoji] = true
    out.push(emoji)
  }
  return out
}

function recordRecent(recents, emoji, limit) {
  var glyph = String(emoji || "")
  if (!glyph) return sanitizeRecents(recents)
  var max = limit === undefined || limit === null ? DEFAULT_RECENT_LIMIT : Number(limit)
  if (isNaN(max) || max < 1) max = DEFAULT_RECENT_LIMIT
  var next = [glyph]
  var list = sanitizeRecents(recents)
  for (var i = 0; i < list.length; i++) {
    if (list[i] !== glyph) next.push(list[i])
    if (next.length >= max) break
  }
  return next
}

function visibleCategories(recents) {
  var hasRecents = sanitizeRecents(recents).length > 0
  var out = []
  for (var i = 0; i < CATEGORY_META.length; i++) {
    var cat = CATEGORY_META[i]
    if (cat.id === "recent" && !hasRecents) continue
    out.push({ id: cat.id, name: cat.name, icon: cat.icon })
  }
  return out
}

function cycleCategory(categories, currentId, delta) {
  var list = Array.isArray(categories) ? categories : []
  if (list.length === 0) return currentId
  var step = Number(delta)
  if (isNaN(step) || step === 0) step = 1
  var idx = 0
  for (var i = 0; i < list.length; i++) {
    if (list[i] && list[i].id === currentId) {
      idx = i
      break
    }
  }
  var next = (idx + step) % list.length
  if (next < 0) next += list.length
  return list[next].id
}

function defaultCategory(recents) {
  return sanitizeRecents(recents).length > 0 ? "recent" : "smileys"
}

function normalizedQuery(query) {
  return normalizeText(query)
}

function normalizeText(value) {
  return String(value || "").toLowerCase().replace(/[-_]+/g, " ").replace(/\s+/g, " ").trim()
}

function matchedWord(hay, token) {
  var padded = " " + hay + " "
  var needle = " " + token
  var at = padded.indexOf(needle)
  if (at < 0) return ""
  var start = at + 1
  var end = padded.indexOf(" ", start)
  if (end < 0) end = padded.length
  return padded.substring(start, end)
}

function isStrongPrefix(token, word) {
  if (!token || !word || word.indexOf(token) !== 0) return false
  if (word === token) return true
  if (token.length >= 4) return true
  return token.length >= Math.ceil(word.length * 0.6)
}

function tokenScore(name, keys, token) {
  if (!token) return 1
  if (name === token) return 1000

  var nameWord = matchedWord(name, token)
  if (nameWord === token) {
    var words = name.split(" ")
    if (words[words.length - 1] === token) return 900
    return 850
  }
  if (isStrongPrefix(token, nameWord) || (name.indexOf(token) === 0 && isStrongPrefix(token, name.split(" ")[0]))) {
    return name.indexOf(token) === 0 ? 800 : 600
  }

  var keyWord = matchedWord(keys, token)
  if (keyWord === token) return 300
  if (isStrongPrefix(token, keyWord)) return 220
  return 0
}

function scoreItem(item, query) {
  if (!item || !item.e) return 0
  var raw = String(query || "").trim()
  if (!raw) return 1
  if (item.e === raw) return 10000
  var needle = normalizeText(raw)
  if (!needle) return 1
  var name = normalizeText(item.n)
  var keys = normalizeText(item.k)
  var hay = (name + " " + keys + " " + item.e).trim()
  var parts = needle.split(" ")
  var total = 0
  for (var i = 0; i < parts.length; i++) {
    var token = parts[i]
    var score = tokenScore(name, hay, token)
    if (score <= 0) return 0
    total += score
  }
  var bonus = COMMON_BONUS[item.e] || COMMON_BONUS[String(item.e).replace(/\uFE0F/g, "")] || 0
  return total + bonus
}

function lookupRecentItems(recents, emojiByChar) {
  var list = sanitizeRecents(recents)
  var map = emojiByChar && typeof emojiByChar === "object" ? emojiByChar : {}
  var out = []
  for (var i = 0; i < list.length; i++) {
    var glyph = list[i]
    var item = map[glyph]
    if (item) out.push(item)
    else out.push({ e: glyph, n: glyph, k: "", c: "recent" })
  }
  return out
}

function filterEmojis(emojis, query, category, recents, emojiByChar, limit) {
  var values = Array.isArray(emojis) ? emojis : []
  var needle = normalizedQuery(query)
  var max = limit === undefined || limit === null ? DEFAULT_SEARCH_LIMIT : Number(limit)
  if (isNaN(max)) max = DEFAULT_SEARCH_LIMIT
  max = Math.max(0, max)
  if (max === 0) return []

  if (needle) {
    var ranked = []
    for (var i = 0; i < values.length; i++) {
      var item = values[i]
      var score = scoreItem(item, query)
      if (score > 0) ranked.push({ item: item, score: score, order: i })
    }
    ranked.sort(function(a, b) {
      if (b.score !== a.score) return b.score - a.score
      return a.order - b.order
    })
    var hits = []
    for (var r = 0; r < ranked.length && hits.length < max; r++) hits.push(ranked[r].item)
    return hits
  }

  if (category === "recent") return lookupRecentItems(recents, emojiByChar)

  var out = []
  for (var j = 0; j < values.length; j++) {
    var row = values[j]
    if (!row || !row.e) continue
    if (row.c === category) out.push(row)
  }
  return out
}

if (typeof module !== "undefined") {
  module.exports = {
    CATEGORY_META: CATEGORY_META,
    parseEmojis: parseEmojis,
    indexByEmoji: indexByEmoji,
    parseState: parseState,
    serializeState: serializeState,
    sanitizeRecents: sanitizeRecents,
    recordRecent: recordRecent,
    visibleCategories: visibleCategories,
    cycleCategory: cycleCategory,
    defaultCategory: defaultCategory,
    normalizedQuery: normalizedQuery,
    scoreItem: scoreItem,
    filterEmojis: filterEmojis
  }
}
