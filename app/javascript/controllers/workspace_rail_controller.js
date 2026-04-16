import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "campfire-workspace-rail-collapsed"

export default class extends Controller {
  static targets = [ "toggle" ]

  connect() {
    if (localStorage.getItem(STORAGE_KEY) === "1") {
      this.element.classList.add("workspace-rail--collapsed")
    }
    this.#applyRailWidth()
    this.#syncToggle()
    this.#syncTitle()
  }

  disconnect() {
    document.body.style.removeProperty("--workspace-rail-width")
  }

  toggle() {
    this.element.classList.toggle("workspace-rail--collapsed")
    localStorage.setItem(STORAGE_KEY, this.element.classList.contains("workspace-rail--collapsed") ? "1" : "0")
    this.#applyRailWidth()
    this.#syncToggle()
    this.#syncTitle()
  }

  /* Collapsed only: inline 0 width. Expanded: remove inline so `layout.css` `--workspace-rail-width` applies. */
  #applyRailWidth() {
    const collapsed = this.element.classList.contains("workspace-rail--collapsed")
    if (collapsed) {
      document.body.style.setProperty("--workspace-rail-width", "0px")
    } else {
      document.body.style.removeProperty("--workspace-rail-width")
    }
  }

  #syncToggle() {
    if (!this.hasToggleTarget) return
    const collapsed = this.element.classList.contains("workspace-rail--collapsed")
    this.toggleTarget.setAttribute("aria-expanded", String(!collapsed))
  }

  #syncTitle() {
    if (!this.hasToggleTarget) return
    const collapsed = this.element.classList.contains("workspace-rail--collapsed")
    this.toggleTarget.title = collapsed ? "Expand workspaces" : "Collapse workspaces"
  }
}
