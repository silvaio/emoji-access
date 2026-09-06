const test = require("node:test")
const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")

const model = require("../EmojiModel.js")

const FIXTURE = [
  { e: "😀", n: "Grinning face", k: "grinning face smile happy", c: "smileys" },
  { e: "😂", n: "Face with tears of joy", k: "face with tears of joy laugh cry lol happy", c: "smileys" },
  { e: "❤️", n: "Red heart", k: "red heart love", c: "symbols" },
  { e: "👍", n: "Thumbs up", k: "thumbs up yes ok like agree", c: "people" },
  { e: "🐻", n: "Bear", k: "bear animal nature", c: "nature" }
]

test("parseEmojis keeps name, keywords, and category", () => {
  const parsed = model.parseEmojis(JSON.stringify(FIXTURE))
  assert.equal(parsed.length, 5)
  assert.equal(parsed[1].n, "Face with tears of joy")
  assert.equal(parsed[1].c, "smileys")
})

test("search ranks name matches ahead of loose keyword hits", () => {
  const joy = model.filterEmojis(FIXTURE, "joy")
  assert.equal(joy[0].e, "😂")

  const grin = model.filterEmojis(FIXTURE, "grin")
  assert.equal(grin[0].e, "😀")
})

test("exact words beat longer names that only start with the query", () => {
  const items = FIXTURE.concat([
    { e: "🕹️", n: "Joystick", k: "joystick game", c: "objects" }
  ])
  assert.equal(model.filterEmojis(items, "joy")[0].e, "😂")
})

test("short queries do not match inside other words", () => {
  const items = FIXTURE.concat([
    { e: "😊", n: "Smiling face with smiling eyes", k: "smiling face with eyes", c: "smileys" }
  ])
  assert.equal(model.filterEmojis(items, "yes")[0].e, "👍")
  assert.equal(model.filterEmojis(items, "yes").some(item => item.e === "😊"), false)
})

test("multi-word queries require every token", () => {
  const hits = model.filterEmojis(FIXTURE, "grin face")
  assert.deepEqual(hits.map(item => item.e), ["😀"])
  assert.equal(model.filterEmojis(FIXTURE, "grin bear").length, 0)
})

test("search matches the emoji character itself", () => {
  const hits = model.filterEmojis(FIXTURE, "👍")
  assert.equal(hits[0].e, "👍")
  assert.ok(model.scoreItem(FIXTURE[3], "👍") > model.scoreItem(FIXTURE[3], "yes"))
})

test("empty query browses a category", () => {
  const smileys = model.filterEmojis(FIXTURE, "", "smileys")
  assert.deepEqual(smileys.map(item => item.e), ["😀", "😂"])
})

test("recent category preserves recency and skips unknown-only when mapped", () => {
  const map = model.indexByEmoji(FIXTURE)
  const recents = model.filterEmojis(FIXTURE, "", "recent", ["🐻", "😂", "missing"], map)
  assert.deepEqual(recents.map(item => item.e), ["🐻", "😂", "missing"])
  assert.equal(recents[0].n, "Bear")
  assert.equal(recents[2].n, "missing")
})

test("recordRecent moves an emoji to the front and caps the list", () => {
  const next = model.recordRecent(["😀", "😂", "❤️"], "😂", 2)
  assert.deepEqual(next, ["😂", "😀"])
})

test("visibleCategories hides Recent until something has been used", () => {
  assert.equal(model.visibleCategories([]).some(cat => cat.id === "recent"), false)
  assert.equal(model.visibleCategories(["😀"]).some(cat => cat.id === "recent"), true)
  assert.equal(model.defaultCategory([]), "smileys")
  assert.equal(model.defaultCategory(["😀"]), "recent")
})

test("cycleCategory wraps in both directions", () => {
  const cats = model.visibleCategories(["😀"])
  assert.equal(model.cycleCategory(cats, "recent", 1), "smileys")
  assert.equal(model.cycleCategory(cats, "flags", 1), "recent")
  assert.equal(model.cycleCategory(cats, "smileys", -1), "recent")
})

test("state round-trips recents and drops blanks", () => {
  const raw = model.serializeState({ recents: ["😂", "", "😂", "❤️"] })
  const parsed = model.parseState(raw)
  assert.deepEqual(parsed.recents, ["😂", "❤️"])
  assert.deepEqual(model.parseState("not-json").recents, [])
})

test("shipped dataset has names, categories, and finds common aliases", () => {
  const jsonPath = path.join(__dirname, "..", "emojis.json")
  const emojis = model.parseEmojis(fs.readFileSync(jsonPath, "utf8"))
  assert.ok(emojis.length > 1500)

  const categories = new Set(emojis.map(item => item.c))
  for (const id of ["smileys", "people", "nature", "food", "travel", "activities", "objects", "symbols", "flags"]) {
    assert.ok(categories.has(id), `missing category ${id}`)
  }

  const joy = model.filterEmojis(emojis, "joy")
  assert.equal(joy[0].e, "😂")

  const yes = model.filterEmojis(emojis, "yes")
  assert.equal(yes[0].e, "👍")

  const named = emojis.filter(item => item.n && item.n !== item.e)
  assert.ok(named.length > 1000)
})
