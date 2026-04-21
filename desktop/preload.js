const { contextBridge, ipcRenderer } = require("electron")

// Patch Notification BEFORE any page script runs.
// Campfire's notifications_controller.js checks Notification.permission
// and calls new Notification() — we intercept both and route through
// Electron's native notification API in the main process.
function patchNotifications() {
  const _Notification = window.Notification

  function ElectronNotification(title, options) {
    ipcRenderer.send("show-notification", {
      title: title || "Campfire",
      body: (options && options.body) || "",
      path: (options && options.data && options.data.path) || null
    })
    return { addEventListener() {}, removeEventListener() {}, close() {} }
  }

  Object.defineProperty(ElectronNotification, "permission", {
    get: () => "granted"
  })
  ElectronNotification.requestPermission = () => Promise.resolve("granted")

  window.Notification = ElectronNotification

  // Patch service worker registration.showNotification once SW is ready
  if (navigator.serviceWorker) {
    navigator.serviceWorker.ready.then((reg) => {
      reg.showNotification = (title, options) => {
        ipcRenderer.send("show-notification", {
          title: title || "Campfire",
          body: (options && options.body) || "",
          path: (options && options.data && options.data.path) || null
        })
        return Promise.resolve()
      }
    }).catch(() => {})
  }
}

patchNotifications()

// Tell Campfire's notifications_controller.js this is a native wrapper.
// It will skip pushManager.subscribe(), remove the bell warning, and
// dispatch "ready" immediately. Our rooms-list:unread listener below
// handles the actual notifications instead.
window.__CAMPFIRE_NATIVE_APP__ = true

// Listen for unread room events dispatched by rooms_list_controller.js
// and show a native notification for rooms the user isn't currently viewing.
window.addEventListener("DOMContentLoaded", () => {
  document.addEventListener("rooms-list:unread", (e) => {
    console.log("[campfire:desktop] rooms-list:unread fired", e.detail)

    const targetId = e.detail?.targetId
    if (!targetId) {
      console.log("[campfire:desktop] no targetId in event detail")
      return
    }

    const roomEl = document.getElementById(targetId)
    if (!roomEl) {
      console.log("[campfire:desktop] room element not found for id:", targetId)
      return
    }

    const labelEl = roomEl.querySelector(".sidebar-row__label")
    const roomName = labelEl ? labelEl.textContent.trim() : "New message"
    const href = roomEl.getAttribute("href") || null

    console.log("[campfire:desktop] sending notification for room:", roomName, "href:", href)

    // Send immediately with fallback body, then upgrade with real message data
    ipcRenderer.send("show-notification", { title: roomName, body: "New message", path: href })

    // Fetch the last message from the room to get sender + body
    const roomIdMatch = targetId.match(/(\d+)/)
    if (roomIdMatch && href) {
      fetch(href, { headers: { "Accept": "text/html", "X-Requested-With": "XMLHttpRequest" }, credentials: "include" })
        .then(r => r.text())
        .then(html => {
          const parser = new DOMParser()
          const doc = parser.parseFromString(html, "text/html")
          const messages = doc.querySelectorAll("div.message[data-message-id]")
          const lastMsg = messages[messages.length - 1]
          if (!lastMsg) return

          const author = lastMsg.querySelector("[data-reply-target='author'], .message__author strong")?.textContent?.trim()
          const isCallInvite = !!lastMsg.querySelector(".message__call-invite")
          const text = lastMsg.querySelector(".trix-content")?.textContent?.replace(/\s+/g, " ").trim()

          if (!author) return

          let title = roomName
          let body
          if (isCallInvite) {
            title = author
            body = `📞 Started a call in ${roomName}`
          } else {
            body = text ? `${author}: ${text.slice(0, 100)}${text.length > 100 ? "…" : ""}` : author
          }

          console.log("[campfire:desktop] upgraded notification body:", body)
          ipcRenderer.send("show-notification", { title, body, path: href })
        })
        .catch(err => console.log("[campfire:desktop] fetch failed:", err.message))
    }
  })
})

contextBridge.exposeInMainWorld("campfireDesktop", {
  getDomain: () => ipcRenderer.invoke("get-domain"),
  saveDomain: (domain) => ipcRenderer.invoke("save-domain", domain),
  getLogoPath: () => ipcRenderer.invoke("get-logo-path"),
  showNotification: (data) => ipcRenderer.send("show-notification", data)
})
