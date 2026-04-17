self.addEventListener("push", async (event) => {
  const data = await event.data.json()
  event.waitUntil(Promise.all([ showNotification(data), updateBadgeCount(data.options) ]))
})

async function showNotification({ title, options }) {
  return self.registration.showNotification(title, options)
}

async function updateBadgeCount({ data: { badge } }) {
  return self.navigator.setAppBadge?.(badge || 0)
}

self.addEventListener("notificationclick", (event) => {
  event.notification.close()

  const url = new URL(event.notification.data.path, self.location.origin).href
  event.waitUntil(openURL(url))
})

async function openURL(url) {
  const windows = await self.clients.matchAll({ type: "window", includeUncontrolled: true })
  const normalizedTarget = new URL(url, self.location.origin).href
  const matchingClient = windows.find((client) => {
    try {
      return new URL(client.url, self.location.origin).href === normalizedTarget
    } catch {
      return false
    }
  })
  const focusedClient = windows.find((client) => client.focused)
  const targetClient = matchingClient || focusedClient

  if (targetClient) {
    if (!matchingClient) {
      await targetClient.navigate(normalizedTarget)
    }
    await targetClient.focus()
    return
  }

  await self.clients.openWindow(normalizedTarget)
}
