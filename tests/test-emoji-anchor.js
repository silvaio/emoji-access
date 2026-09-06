const test = require("node:test")
const assert = require("node:assert/strict")

const anchor = require("../EmojiAnchor.js")

const monitor = { name: "HDMI-A-1", x: 0, y: 0, width: 3440, height: 1440, focused: true }

test("parseContext reads cursor, window, and monitors", () => {
  const ctx = anchor.parseContext(JSON.stringify({
    cursor: { x: 100, y: 200 },
    window: { address: "0xabc" },
    monitors: [monitor]
  }))
  assert.equal(ctx.cursor.x, 100)
  assert.equal(ctx.cursor.y, 200)
  assert.equal(anchor.windowAddress(ctx.window), "0xabc")
  assert.equal(ctx.monitors[0].name, "HDMI-A-1")
})

test("windowAddress ignores empty and null addresses", () => {
  assert.equal(anchor.windowAddress({}), "")
  assert.equal(anchor.windowAddress({ address: "0x0" }), "")
  assert.equal(anchor.windowAddress(null), "")
})

test("monitorForCursor picks the output under the pointer", () => {
  const left = { name: "left", x: 0, y: 0, width: 1920, height: 1080, focused: false }
  const right = { name: "right", x: 1920, y: 0, width: 1920, height: 1080, focused: true }
  const found = anchor.monitorForCursor([left, right], { x: 2000, y: 10 })
  assert.equal(found.name, "right")
})

test("placeCard sits below-right of the pointer when there is room", () => {
  const pos = anchor.placeCard(100, 80, monitor, 3440, 1440, 420, 400, 12)
  assert.equal(pos.x, 112)
  assert.equal(pos.y, 92)
})

test("placeCard flips above and left when the pointer is in the corner", () => {
  const pos = anchor.placeCard(3400, 1400, monitor, 3440, 1440, 420, 400, 12)
  assert.equal(pos.x, 3400 - 420 - 12)
  assert.equal(pos.y, 1400 - 400 - 12)
  assert.ok(pos.x + 420 <= 3440)
  assert.ok(pos.y + 400 <= 1440)
})

test("placeCard scales Hyprland coords into the panel's pixel space", () => {
  const pos = anchor.placeCard(1720, 720, monitor, 2752, 1152, 400, 400, 12)
  assert.equal(pos.x, Math.round(1720 * (2752 / 3440) + 12))
  assert.equal(pos.y, Math.round(720 * (1152 / 1440) + 12))
})
