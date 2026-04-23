const { app, BrowserWindow, ipcMain, shell, Tray, Menu, nativeImage, session, Notification } = require("electron")
const path = require("path")
const Store = require("electron-store")

const store = new Store()

let mainWindow = null
let tray = null

function buildAppMenu() {
  const template = [
    {
      label: app.name,
      submenu: [
        { role: "about" },
        { type: "separator" },
        {
          label: "Change Server…",
          accelerator: "CmdOrCtrl+,",
          click: () => { mainWindow?.show(); mainWindow?.loadFile("index.html") }
        },
        { type: "separator" },
        { role: "services" },
        { type: "separator" },
        { role: "hide" },
        { role: "hideOthers" },
        { role: "unhide" },
        { type: "separator" },
        { role: "quit" }
      ]
    },
    {
      label: "Edit",
      submenu: [
        { role: "undo" }, { role: "redo" }, { type: "separator" },
        { role: "cut" }, { role: "copy" }, { role: "paste" },
        { role: "selectAll" }
      ]
    },
    {
      label: "View",
      submenu: [
        { role: "reload" },
        { role: "toggleDevTools" },
        { type: "separator" },
        { role: "resetZoom" }, { role: "zoomIn" }, { role: "zoomOut" },
        { type: "separator" },
        { role: "togglefullscreen" }
      ]
    },
    {
      label: "Window",
      submenu: [
        { role: "minimize" },
        { role: "zoom" },
        { type: "separator" },
        { role: "front" }
      ]
    }
  ]

  Menu.setApplicationMenu(Menu.buildFromTemplate(template))
}

function normalizeDomain(raw) {
  const trimmed = raw.trim()
  if (!trimmed) return null
  const withProtocol = /^https?:\/\//i.test(trimmed) ? trimmed : `https://${trimmed}`
  try {
    const url = new URL(withProtocol)
    if (!url.hostname) return null
    return url.origin
  } catch {
    return null
  }
}

function openCallWindow(url) {
  const callWin = new BrowserWindow({
    width: 1200,
    height: 800,
    title: "Call – Campfire",
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
      partition: "persist:campfire-call"
    }
  })
  callWin.loadURL(url)
  callWin.on("closed", () => callWin.destroy())
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1280,
    height: 800,
    minWidth: 800,
    minHeight: 600,
    title: "Campfire",
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
      partition: "persist:campfire"
    }
  })

  const domain = store.get("domain")

  if (domain) {
    mainWindow.loadURL(domain)
  } else {
    mainWindow.loadFile("index.html")
  }

  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    try {
      const parsed = new URL(url)
      const domain = store.get("domain")
      const trustedCallHosts = ["meet.jit.si", "meet.daiwick.com"]

      const isDirectCallUrl = trustedCallHosts.some(h => parsed.hostname === h || parsed.hostname.endsWith(`.${h}`))
      const isCallInvitePath = domain && parsed.origin === new URL(domain).origin &&
        (parsed.pathname.startsWith("/c/") || parsed.pathname.startsWith("/calls/"))

      if (isDirectCallUrl || isCallInvitePath) {
        openCallWindow(url)
        return { action: "deny" }
      }
    } catch {}

    shell.openExternal(url)
    return { action: "deny" }
  })

  mainWindow.webContents.on("console-message", (e) => {
    const labels = ["LOG", "WARN", "ERROR", "DEBUG"]
    const label = labels[e.level] ?? "LOG"
    const source = e.sourceId ?? ""
    const line = e.lineNumber ?? 0
    if (label === "ERROR" || label === "WARN" || e.message?.includes("[campfire:")) {
      console.log(`[renderer:${label}] ${e.message} (${source}:${line})`)
    }
  })

  mainWindow.webContents.session.on("will-download", (_e, item) => {
    item.setSavePath(path.join(app.getPath("downloads"), item.getFilename()))
  })

  mainWindow.on("close", (e) => {
    e.preventDefault()
    mainWindow.hide()
  })
}

function createTray() {
  const iconPath = path.join(__dirname, "logo.png")
  const icon = nativeImage.createFromPath(iconPath).resize({ width: 16, height: 16 })
  tray = new Tray(icon)
  tray.setToolTip("Campfire")

  const menu = Menu.buildFromTemplate([
    { label: "Open Campfire", click: () => { mainWindow?.show(); mainWindow?.focus() } },
    { type: "separator" },
    { label: "Change server", click: () => { mainWindow?.show(); mainWindow?.loadFile("index.html") } },
    { type: "separator" },
    { label: "Quit", click: () => app.quit() }
  ])

  tray.setContextMenu(menu)
  tray.on("click", () => { mainWindow?.show(); mainWindow?.focus() })
  tray.on("double-click", () => { mainWindow?.show(); mainWindow?.focus() })
}

app.whenReady().then(() => {
  buildAppMenu()
  createWindow()
  createTray()

  const campfireSession = session.fromPartition("persist:campfire")

  campfireSession.webRequest.onHeadersReceived((details, callback) => {
    const existing = details.responseHeaders["content-security-policy"] ||
                     details.responseHeaders["Content-Security-Policy"] || []
    callback({
      responseHeaders: {
        ...details.responseHeaders,
        "Content-Security-Policy": existing.length ? existing : ["default-src * 'unsafe-inline' 'unsafe-eval' data: blob:"]
      }
    })
  })

  const mediaPermissions = ["notifications", "media", "mediaKeySystem", "geolocation", "camera", "microphone", "display-capture"]

  campfireSession.setPermissionRequestHandler((_webContents, permission, callback) => {
    callback(mediaPermissions.includes(permission))
  })

  campfireSession.setPermissionCheckHandler((_webContents, permission) => {
    return mediaPermissions.includes(permission)
  })

  const callSession = session.fromPartition("persist:campfire-call")
  callSession.setPermissionRequestHandler((_webContents, permission, callback) => {
    callback(mediaPermissions.includes(permission))
  })
  callSession.setPermissionCheckHandler((_webContents, permission) => {
    return mediaPermissions.includes(permission)
  })

  app.on("activate", () => {
    mainWindow?.show()
    mainWindow?.focus()
  })
})

app.on("window-all-closed", () => {
  // Don't quit — keep running in tray for background notifications
})

ipcMain.handle("get-domain", () => store.get("domain") ?? null)


ipcMain.on("show-notification", (_event, { title, body, path: notifPath }) => {
  console.log("[main] show-notification received:", title, body)
  if (!Notification.isSupported()) {
    console.log("[main] Notification.isSupported() = false")
    return
  }
  const n = new Notification({
    title: title ?? "Campfire",
    body: body ?? "",
    icon: path.join(__dirname, "logo.png"),
    silent: false
  })
  n.on("click", () => {
    mainWindow?.show()
    mainWindow?.focus()
    if (notifPath && store.get("domain")) {
      const url = new URL(notifPath, store.get("domain")).href
      mainWindow?.loadURL(url)
    }
  })
  n.show()
  shell.beep()
})


ipcMain.handle("get-logo-path", () => {
  return `file://${path.join(__dirname, "logo.png")}`
})

ipcMain.handle("save-domain", (_event, raw) => {
  const normalized = normalizeDomain(raw)
  if (!normalized) return { error: "Invalid domain. Enter a valid host, e.g. chat.example.com" }
  store.set("domain", normalized)
  mainWindow.loadURL(normalized)
  return { ok: true }
})
