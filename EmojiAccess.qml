import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui
import "EmojiModel.js" as EmojiModel
import "EmojiAnchor.js" as EmojiAnchor

Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "").replace(/\/$/, "")
  readonly property string statePath: Quickshell.env("HOME") + "/.local/state/omarchy/silvaio-emoji-access.json"

  property bool opened: false
  property bool opening: false
  property bool grabKeyboard: false
  property string filterText: ""
  property string selectedCategory: "smileys"
  property int selectedIndex: 0
  property bool cursorActive: false
  property var emojis: []
  property var emojiByChar: ({})
  property var recents: []
  property var filteredEmojis: []
  property var anchorScreen: null
  property int cardX: 0
  property int cardY: 0
  property string targetWindowAddress: ""

  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int contentMargin: Style.spacing.popupPadding
  property int headerHeight: Math.max(Style.space(30), Style.font.title + Style.spacing.controlPaddingY * 2)
  property int footerHeight: Math.max(Style.space(52), Style.font.title + Style.font.caption + Style.spacing.sm * 2)
  property int contentSpacing: Style.spacing.sm
  property int cardWidth: {
    var screenW = anchorScreen ? anchorScreen.width : Style.space(420)
    return Math.min(Style.space(420), Math.max(Style.space(280), screenW - Style.space(24)))
  }
  property int cardHeight: {
    var screenH = anchorScreen ? anchorScreen.height : Style.space(400)
    return Math.min(Style.space(400), Math.max(Style.space(260), screenH - Style.space(24)))
  }
  property int sidebarWidth: Math.max(Style.space(108), Style.space(96))
  property int cellWidth: Math.max(Style.space(48), Style.font.display + Style.spacing.lg)
  property int cellHeight: Math.max(Style.space(48), Style.font.display + Style.spacing.lg)
  property int rowHeight: Math.max(Style.space(48), Style.font.title + Style.font.caption + Style.spacing.rowPaddingX)
  property int columns: Math.max(1, Math.floor(gridWidth / cellWidth))
  readonly property bool listMode: root.filterText.length > 0
  readonly property int gridWidth: Math.max(cellWidth, cardWidth - contentMargin * 2 - sidebarWidth - contentSpacing)
  property var activeRow: displayModel.count > 0 && selectedIndex >= 0 && selectedIndex < displayModel.count
    ? displayModel.get(selectedIndex)
    : null

  function open(payloadJson) {
    if (root.opened || root.opening) return
    root.opening = true
    root.grabKeyboard = false
    root.filterText = ""
    root.selectedCategory = EmojiModel.defaultCategory(root.recents)
    root.selectedIndex = 0
    root.cursorActive = true
    root.rebuildCategories()
    root.rebuildDisplay()
    root.refreshAnchor()
  }

  function close() {
    root.opening = false
    root.grabKeyboard = false
    root.opened = false
  }

  function dismiss() {
    root.opening = false
    root.grabKeyboard = false
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "silvaio.emoji-access")
  }

  function grabForSearch() {
    if (!root.opened) return
    root.grabKeyboard = true
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function toggle() {
    if (root.opened || root.opening) root.dismiss()
    else root.open("{}")
  }

  function findScreen(name) {
    var screens = Quickshell.screens
    var i
    if (name) {
      for (i = 0; i < screens.length; i++) {
        if (String(screens[i].name) === String(name)) return screens[i]
      }
    }
    return screens.length > 0 ? screens[0] : null
  }

  function refreshAnchor() {
    if (anchorProc.running) anchorProc.running = false
    anchorProc.running = true
  }

  function applyAnchorContext(raw) {
    if (!root.opening) return
    var ctx = EmojiAnchor.parseContext(raw)
    var monitor = EmojiAnchor.monitorForCursor(ctx.monitors, ctx.cursor)
    var screen = root.findScreen(monitor && monitor.name)
    root.anchorScreen = screen
    var panelW = screen ? screen.width : 0
    var panelH = screen ? screen.height : 0
    var gap = Style.space(12)
    var pos = monitor
      ? EmojiAnchor.placeCard(ctx.cursor.x, ctx.cursor.y, monitor, panelW, panelH, root.cardWidth, root.cardHeight, gap)
      : EmojiAnchor.centerCard(panelW, panelH, root.cardWidth, root.cardHeight)
    root.cardX = pos.x
    root.cardY = pos.y
    root.targetWindowAddress = EmojiAnchor.windowAddress(ctx.window)
    root.opening = false
    root.opened = true
  }

  function disarmPointer() {
    pointerGate.reset()
  }

  function loadEmojis(raw) {
    root.emojis = EmojiModel.parseEmojis(raw)
    root.emojiByChar = EmojiModel.indexByEmoji(root.emojis)
    if (root.opened) root.rebuildDisplay()
  }

  function loadState(raw) {
    var state = EmojiModel.parseState(raw)
    root.recents = state.recents
    if (root.opened) {
      root.rebuildCategories()
      root.rebuildDisplay()
    }
  }

  function saveState() {
    stateFile.setText(EmojiModel.serializeState({ recents: root.recents }))
  }

  function rebuildCategories() {
    var cats = EmojiModel.visibleCategories(root.recents)
    categoryModel.clear()
    for (var i = 0; i < cats.length; i++) {
      categoryModel.append({ catId: cats[i].id, name: cats[i].name, icon: cats[i].icon })
    }
    if (root.selectedCategory === "recent" && root.recents.length === 0)
      root.selectedCategory = "smileys"
  }

  function rebuildDisplay() {
    var out = EmojiModel.filterEmojis(
      root.emojis,
      root.filterText,
      root.selectedCategory,
      root.recents,
      root.emojiByChar,
      root.listMode ? 120 : 1000
    )
    root.filteredEmojis = out

    displayModel.clear()
    for (var j = 0; j < out.length; j++) {
      displayModel.append({
        emoji: out[j].e,
        name: out[j].n,
        keywords: out[j].k,
        category: out[j].c
      })
    }

    if (displayModel.count === 0) selectedIndex = 0
    else if (selectedIndex >= displayModel.count) selectedIndex = displayModel.count - 1
    else if (selectedIndex < 0) selectedIndex = 0
    cursorActive = displayModel.count > 0
    root.disarmPointer()

    Qt.callLater(function() {
      if (displayModel.count === 0) return
      if (root.listMode) resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
      else resultGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
    })
  }

  function setFilter(nextFilter) {
    root.filterText = nextFilter
    root.selectedIndex = 0
    root.cursorActive = true
    root.rebuildDisplay()
  }

  function setCategory(id) {
    if (!id) return
    root.filterText = ""
    root.selectedCategory = id
    root.selectedIndex = 0
    root.cursorActive = true
    root.rebuildDisplay()
  }

  function selectCategory(delta) {
    var cats = EmojiModel.visibleCategories(root.recents)
    root.setCategory(EmojiModel.cycleCategory(cats, root.selectedCategory, delta))
  }

  function select(delta) {
    if (displayModel.count === 0) return
    if (!cursorActive) {
      cursorActive = true
      selectedIndex = delta < 0 ? displayModel.count - 1 : 0
    } else {
      selectedIndex = (selectedIndex + delta + displayModel.count) % displayModel.count
    }
    root.revealSelection()
  }

  function selectRow(delta) {
    if (displayModel.count === 0) return
    if (root.listMode) {
      root.select(delta)
      return
    }
    if (!cursorActive) {
      cursorActive = true
      selectedIndex = delta < 0 ? displayModel.count - 1 : 0
      root.revealSelection()
      return
    }
    var newIndex = selectedIndex + delta * columns
    if (newIndex < 0) newIndex = 0
    if (newIndex >= displayModel.count) newIndex = displayModel.count - 1
    selectedIndex = newIndex
    root.revealSelection()
  }

  function selectPage(delta) {
    if (displayModel.count === 0) return
    if (!cursorActive) {
      cursorActive = true
      selectedIndex = delta < 0 ? displayModel.count - 1 : 0
      root.revealSelection()
      return
    }
    var stride = root.listMode
      ? Math.max(1, Math.floor(resultList.height / rowHeight))
      : Math.max(1, Math.floor(resultGrid.height / cellHeight)) * columns
    var newIndex = selectedIndex + delta * stride
    if (newIndex < 0) newIndex = 0
    if (newIndex >= displayModel.count) newIndex = displayModel.count - 1
    selectedIndex = newIndex
    root.revealSelection()
  }

  function selectAbsolute(index) {
    if (displayModel.count === 0) return
    cursorActive = true
    selectedIndex = Math.max(0, Math.min(index, displayModel.count - 1))
    root.revealSelection()
  }

  function revealSelection() {
    if (root.listMode) resultList.positionViewAtIndex(selectedIndex, ListView.Contain)
    else resultGrid.positionViewAtIndex(selectedIndex, GridView.Contain)
  }

  function selectFromPointer(index, item, mouse) {
    if (!pointerGate.moved(item, mouse)) return
    root.cursorActive = true
    root.selectedIndex = index
  }

  function recordRecent(emoji) {
    root.recents = EmojiModel.recordRecent(root.recents, emoji)
    root.saveState()
    root.rebuildCategories()
    if (root.opened && root.selectedCategory === "recent" && !root.filterText)
      root.rebuildDisplay()
  }

  function activateIndex(index) {
    if (index < 0 || index >= displayModel.count) return
    var row = displayModel.get(index)
    root.applySelected(row.emoji)
  }

  function copyIndex(index, dismissAfter) {
    if (index < 0 || index >= displayModel.count) return
    var row = displayModel.get(index)
    if (!row || !row.emoji) return
    root.recordRecent(row.emoji)
    Quickshell.execDetached(["wl-copy", "--type", "text/plain", "--sensitive", row.emoji])
    if (dismissAfter) root.dismiss()
  }

  function applySelected(emoji) {
    if (!emoji) return
    var address = root.targetWindowAddress
    root.recordRecent(emoji)
    Quickshell.execDetached([
      root.pluginDir + "/scripts/insert-emoji",
      address,
      emoji
    ])
    root.dismiss()
  }

  ListModel { id: displayModel }
  ListModel { id: categoryModel }

  PointerMoveGate {
    id: pointerGate
    referenceItem: card
  }

  FileView {
    path: root.pluginDir + "/emojis.json"
    onLoaded: root.loadEmojis(text())
  }

  FileView {
    id: stateFile
    path: root.statePath
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadState(text())
    onLoadFailed: root.loadState("{}")
  }

  Process {
    id: anchorProc
    command: [root.pluginDir + "/scripts/anchor-context"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyAnchorContext(text)
    }
    onExited: function(exitCode) {
      if (exitCode !== 0 && root.opening && !root.opened)
        root.applyAnchorContext("{}")
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    screen: root.anchorScreen
    implicitWidth: root.cardWidth
    implicitHeight: root.cardHeight
    anchors { left: true; top: true }
    margins.left: root.cardX
    margins.top: root.cardY
    color: "transparent"
    focusable: root.grabKeyboard
    WlrLayershell.namespace: "omarchy-emojis"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened && root.grabKeyboard
      ? WlrKeyboardFocus.Exclusive
      : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    BorderSurface {
      id: card
      anchors.fill: parent
      radius: root.cornerRadius
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            if (root.filterText) root.setFilter("")
            else root.dismiss()
            event.accepted = true
          } else if (Util.editsFilter(event, root.filterText)) {
            root.setFilter(Util.editedFilter(event, root.filterText))
            event.accepted = true
          } else if (event.key === Qt.Key_Tab) {
            root.selectCategory(event.modifiers & Qt.ShiftModifier ? -1 : 1)
            event.accepted = true
          } else if (event.key === Qt.Key_Backtab) {
            root.selectCategory(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_BracketLeft) {
            root.selectCategory(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_BracketRight) {
            root.selectCategory(1)
            event.accepted = true
          } else if (event.key === Qt.Key_C && (event.modifiers & Qt.ControlModifier)) {
            if (root.cursorActive) root.copyIndex(root.selectedIndex, false)
            event.accepted = true
          } else if (event.key === Qt.Key_Left) {
            if (root.listMode) root.selectCategory(-1)
            else root.select(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_Right) {
            if (root.listMode) root.selectCategory(1)
            else root.select(1)
            event.accepted = true
          } else if (event.key === Qt.Key_Up) {
            root.selectRow(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_Down) {
            root.selectRow(1)
            event.accepted = true
          } else if (event.key === Qt.Key_PageUp) {
            root.selectPage(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_PageDown) {
            root.selectPage(1)
            event.accepted = true
          } else if (event.key === Qt.Key_Home) {
            root.selectAbsolute(0)
            event.accepted = true
          } else if (event.key === Qt.Key_End) {
            root.selectAbsolute(displayModel.count - 1)
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.cursorActive && (event.modifiers & Qt.ShiftModifier))
              root.copyIndex(root.selectedIndex, true)
            else if (root.cursorActive)
              root.activateIndex(root.selectedIndex)
            else if (displayModel.count > 0)
              root.cursorActive = true
            event.accepted = true
          } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127) {
            root.setFilter(root.filterText + event.text)
            event.accepted = true
          }
        }
      }

      Column {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: root.contentSpacing

        Rectangle {
          width: parent.width
          height: root.headerHeight
          radius: root.cornerRadius
          color: "transparent"

          Text {
            textFormat: Text.PlainText
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.filterText || (root.grabKeyboard ? "Search by name or keyword…" : "Click to search · click an emoji to insert")
            color: root.foreground
            opacity: root.filterText ? 1 : 0.58
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            elide: Text.ElideRight
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onClicked: root.grabForSearch()
          }
        }

        Item {
          width: parent.width
          height: parent.height - root.headerHeight - root.footerHeight - root.contentSpacing * 2

          Row {
            anchors.fill: parent
            spacing: root.contentSpacing

            ListView {
              id: categoryList
              width: root.sidebarWidth
              height: parent.height
              model: categoryModel
              clip: true
              spacing: Style.space(2)
              boundsBehavior: Flickable.StopAtBounds
              currentIndex: {
                for (var i = 0; i < categoryModel.count; i++) {
                  if (categoryModel.get(i).catId === root.selectedCategory) return i
                }
                return 0
              }

              delegate: Rectangle {
                required property int index
                required property string catId
                required property string name
                required property string icon

                readonly property bool chosen: catId === root.selectedCategory && !root.listMode

                width: ListView.view.width
                height: Math.max(Style.space(32), Style.font.body + Style.spacing.controlPaddingY * 2)
                radius: root.cornerRadius
                color: chosen ? root.selectedBackground : "transparent"
                opacity: root.listMode && !chosen ? 0.55 : 1

                Row {
                  anchors.fill: parent
                  anchors.leftMargin: Style.spacing.sm
                  anchors.rightMargin: Style.spacing.sm
                  spacing: Style.spacing.sm

                  Text {
                    textFormat: Text.PlainText
                    text: icon
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.title
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(22)
                    horizontalAlignment: Text.AlignHCenter
                  }

                  Text {
                    textFormat: Text.PlainText
                    text: name
                    color: chosen ? root.selectedText : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    elide: Text.ElideRight
                    width: parent.width - Style.space(22) - parent.spacing
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.setCategory(catId)
                }
              }
            }

            Item {
              width: parent.width - root.sidebarWidth - parent.spacing
              height: parent.height
              clip: true

              GridView {
                id: resultGrid
                visible: !root.listMode
                anchors.fill: parent
                model: displayModel
                clip: true
                cellWidth: root.cellWidth
                cellHeight: root.cellHeight
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                  id: gridCell
                  required property int index
                  required property string emoji
                  required property string name

                  readonly property bool hasCursor: root.cursorActive && index === root.selectedIndex

                  width: root.cellWidth
                  height: root.cellHeight
                  radius: root.cornerRadius
                  color: hasCursor ? root.selectedBackground : "transparent"

                  Text {
                    textFormat: Text.PlainText
                    text: parent.emoji
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.display
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                  }

                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: function(mouse) {
                      root.selectFromPointer(gridCell.index, gridCell, mouse)
                    }
                    onClicked: {
                      root.cursorActive = true
                      root.selectedIndex = gridCell.index
                      root.activateIndex(gridCell.index)
                    }
                  }
                }
              }

              ListView {
                id: resultList
                visible: root.listMode
                anchors.fill: parent
                model: displayModel
                clip: true
                spacing: Style.space(2)
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                  id: listRow
                  required property int index
                  required property string emoji
                  required property string name
                  required property string keywords

                  readonly property bool hasCursor: root.cursorActive && index === root.selectedIndex

                  width: ListView.view.width
                  height: root.rowHeight
                  radius: root.cornerRadius
                  color: hasCursor ? root.selectedBackground : "transparent"

                  Row {
                    anchors.fill: parent
                    anchors.leftMargin: Style.spacing.sm
                    anchors.rightMargin: Style.spacing.sm
                    spacing: Style.spacing.md

                    Text {
                      textFormat: Text.PlainText
                      text: listRow.emoji
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.display
                      width: Style.space(36)
                      height: parent.height
                      horizontalAlignment: Text.AlignHCenter
                      verticalAlignment: Text.AlignVCenter
                    }

                    Column {
                      width: parent.width - Style.space(36) - parent.spacing
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: 0

                      Text {
                        textFormat: Text.PlainText
                        text: listRow.name
                        color: listRow.hasCursor ? root.selectedText : root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.title
                        elide: Text.ElideRight
                        width: parent.width
                      }

                      Text {
                        textFormat: Text.PlainText
                        text: listRow.keywords
                        color: root.foreground
                        opacity: 0.55
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                        width: parent.width
                        visible: listRow.keywords.length > 0 && listRow.keywords !== listRow.name
                      }
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: function(mouse) {
                      root.selectFromPointer(listRow.index, listRow, mouse)
                    }
                    onClicked: {
                      root.cursorActive = true
                      root.selectedIndex = listRow.index
                      root.activateIndex(listRow.index)
                    }
                  }
                }
              }

              Column {
                anchors.centerIn: parent
                spacing: Style.space(8)
                visible: displayModel.count === 0
                width: parent.width - Style.space(24)

                Text {
                  text: root.selectedCategory === "recent" && !root.filterText ? "🕒" : "󰈉"
                  color: root.selectedText
                  opacity: 0.8
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.displayLarge
                  horizontalAlignment: Text.AlignHCenter
                  width: parent.width
                }

                Text {
                  textFormat: Text.PlainText
                  text: root.filterText
                    ? "No matches for “" + root.filterText + "”"
                    : (root.selectedCategory === "recent" ? "No recent emojis yet" : "No emojis in this category")
                  color: root.foreground
                  opacity: 0.7
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  horizontalAlignment: Text.AlignHCenter
                  wrapMode: Text.WordWrap
                  width: parent.width
                }
              }
            }
          }
        }

        Rectangle {
          width: parent.width
          height: root.footerHeight
          radius: root.cornerRadius
          color: "transparent"

          Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: Style.normalBorderWidth
            color: Util.alpha(root.border, 0.28)
          }

          Row {
            anchors.fill: parent
            anchors.topMargin: Style.spacing.md
            spacing: Style.spacing.lg

            Text {
              textFormat: Text.PlainText
              text: root.activeRow ? root.activeRow.emoji : ""
              visible: !!root.activeRow
              font.family: root.fontFamily
              font.pixelSize: Style.font.displayLarge
              width: Style.space(40)
              height: parent.height
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }

            Column {
              width: parent.width - Style.space(40) - parent.spacing
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                textFormat: Text.PlainText
                text: root.activeRow ? root.activeRow.name : (root.filterText ? "Keep typing to search by name" : "Pick an emoji")
                color: root.activeRow ? root.foreground : Util.alpha(root.foreground, 0.58)
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                elide: Text.ElideRight
                width: parent.width
              }

              Text {
                textFormat: Text.PlainText
                text: root.grabKeyboard
                  ? (root.activeRow
                    ? "Enter insert  ·  Shift+Enter copy  ·  Ctrl+C copy  ·  Tab category"
                    : "Tab cycles categories  ·  Type to search")
                  : "Click an emoji to insert here  ·  Super+. to close"
                color: root.foreground
                opacity: 0.55
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
                width: parent.width
              }
            }
          }
        }
      }
    }
  }
}
