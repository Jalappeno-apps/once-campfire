import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "modal", "frame" ]
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
    this.open(url.toString())
  }

  close(event) {
    if (event) event.preventDefault()
    this.modalTarget.hidden = true
    this.frameTarget.src = "about:blank"
  }

  closeWithEscape(event) {
    if (!this.modalTarget.hidden && event.key === "Escape") this.close()
  }

  open(url) {
    this.frameTarget.src = url
    this.modalTarget.hidden = false
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
