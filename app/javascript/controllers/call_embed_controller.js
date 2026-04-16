import { Controller } from "@hotwired/stimulus"

// Opens trusted call URLs in a new browser tab (web + PWA). Native app uses default link handling.
export default class extends Controller {
  static values = { hostAllowlist: Array }

  connect() {
    this.hostAllowlistValue = this.hostAllowlistValue?.length ? this.hostAllowlistValue : [ "meet.jit.si" ]
  }

  handleLink(event) {
    if (window.__CAMPFIRE_NATIVE_APP__) return

    const link = event.target.closest("a[href]")
    if (!link) return

    const url = this.#toURL(link.href)
    if (!url || !this.#trustedCallHost(url.hostname)) return

    event.preventDefault()
    const targetUrl = url.toString()
    const opened = window.open(targetUrl, "_blank", "noopener,noreferrer")
    if (!opened) {
      window.location.assign(targetUrl)
    }
  }

  #toURL(value) {
    try {
      return new URL(value, window.location.origin)
    } catch {
      return null
    }
  }

  #trustedCallHost(hostname) {
    return this.hostAllowlistValue.includes(hostname)
  }
}
