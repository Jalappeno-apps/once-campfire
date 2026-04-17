import { Controller } from "@hotwired/stimulus"
import { isTouchDevice } from "helpers/navigator_helpers"

export default class extends Controller {
  static MIN_KEYBOARD_INSET_PX = 80
  static MAX_KEYBOARD_INSET_PX = 420

  static get shouldLoad() {
    return isTouchDevice() && "visualViewport" in window
  }

  connect() {
    if (window.__CAMPFIRE_NATIVE_APP__) return

    this.footer = document.querySelector("#footer")
    this.layoutViewportHeight = window.innerHeight
    this.raf = null
    this.scheduleSync = this.scheduleSync.bind(this)
    this.onFocusIn = this.onFocusIn.bind(this)
    this.onFocusOut = this.onFocusOut.bind(this)

    window.visualViewport.addEventListener("resize", this.scheduleSync)
    window.visualViewport.addEventListener("scroll", this.scheduleSync)
    window.addEventListener("resize", this.scheduleSync)
    window.addEventListener("orientationchange", this.scheduleSync)
    document.addEventListener("focusin", this.onFocusIn)
    document.addEventListener("focusout", this.onFocusOut)

    this.scheduleSync()
  }

  disconnect() {
    if (!window.visualViewport || window.__CAMPFIRE_NATIVE_APP__) return

    window.visualViewport.removeEventListener("resize", this.scheduleSync)
    window.visualViewport.removeEventListener("scroll", this.scheduleSync)
    window.removeEventListener("resize", this.scheduleSync)
    window.removeEventListener("orientationchange", this.scheduleSync)
    document.removeEventListener("focusin", this.onFocusIn)
    document.removeEventListener("focusout", this.onFocusOut)
    this.#setInset(0)
    this.#setViewportHeight(window.innerHeight)
    this.#setFooterOffset(0)
    document.documentElement.classList.remove("keyboard-overlay-active")
  }

  onFocusIn(event) {
    this.scheduleSync()

    const field = event.target
    if (!(field instanceof HTMLElement)) return
    if (!field.matches("input, textarea, trix-editor, [contenteditable='true']")) return

    setTimeout(() => {
      field.scrollIntoView({ block: "center", inline: "nearest", behavior: "auto" })
    }, 120)
  }

  onFocusOut() {
    // Sending a message can briefly blur/re-render the editor while keyboard stays open.
    // Re-sync from viewport metrics instead of force-resetting to zero.
    requestAnimationFrame(() => this.scheduleSync())
    setTimeout(() => this.scheduleSync(), 120)
    setTimeout(() => this.scheduleSync(), 300)
  }

  scheduleSync() {
    if (this.raf) return
    this.raf = requestAnimationFrame(() => {
      this.raf = null
      this.syncInset()
    })
  }

  syncInset() {
    const viewport = window.visualViewport
    if (!viewport) return

    // Keep a stable "no-keyboard" baseline; some browsers mutate `innerHeight`
    // while the keyboard is open, which would make inset look like 0.
    this.layoutViewportHeight = Math.max(this.layoutViewportHeight, window.innerHeight)

    const rawInset = Math.max(0, this.layoutViewportHeight - viewport.height - viewport.offsetTop)
    const clampedInset = Math.min(rawInset, this.constructor.MAX_KEYBOARD_INSET_PX)
    let inset = clampedInset >= this.constructor.MIN_KEYBOARD_INSET_PX ? clampedInset : 0
    if (!this.#hasEditableFocus()) inset = 0
    this.#setInset(inset)
    this.#setViewportHeight(viewport.height)
    this.#setFooterOffset(inset)
  }

  #hasEditableFocus() {
    const active = document.activeElement
    if (!(active instanceof HTMLElement)) return false
    if (active.matches("input, textarea, [contenteditable='true']")) return true

    // Rich text editor keeps focus on nested editable nodes in some browsers.
    return Boolean(active.closest("trix-editor"))
  }

  #setInset(value) {
    const root = document.documentElement
    const rounded = Math.round(value)
    root.style.setProperty("--campfire-keyboard-overlay", `${rounded}px`)
    root.classList.toggle("keyboard-overlay-active", rounded > 0)
  }

  #setViewportHeight(value) {
    document.documentElement.style.setProperty("--campfire-visual-viewport-height", `${Math.round(value)}px`)
  }

  #setFooterOffset(value) {
    if (!this.footer) return
    if (!window.matchMedia("(max-width: 100ch)").matches) return
    if (!this.footer.querySelector(".composer")) return

    const viewport = window.visualViewport
    if (!viewport) return

    // Move only by the amount the footer is actually hidden by keyboard.
    const rect = this.footer.getBoundingClientRect()
    const visibleBottom = viewport.offsetTop + viewport.height
    const overlap = rect.bottom - visibleBottom
    const needed = overlap > 0 ? overlap + 1 : 0

    const offset = Math.max(0, Math.round(Math.min(value, needed)))
    this.footer.style.transform = offset > 0 ? `translateY(-${offset}px)` : ""
    this.footer.style.willChange = offset > 0 ? "transform" : ""
  }

}
