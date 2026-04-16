import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "section", "trigger" ]

  connect() {
    this.sectionTargets.forEach((section) => {
      const key = section.dataset.sidebarSectionsSectionId
      if (!key) return

      const collapsed = this.collapsed(key)
      this.renderSection(key, collapsed)
    })
  }

  toggle(event) {
    const key = event.params.section
    if (!key) return

    const collapsed = !this.collapsed(key)
    localStorage.setItem(this.storageKey(key), collapsed.toString())
    this.renderSection(key, collapsed)
  }

  renderSection(key, collapsed) {
    const section = this.sectionTargets.find((target) => target.dataset.sidebarSectionsSectionId == key)
    if (!section) return

    section.hidden = collapsed

    const trigger = this.triggerTargets.find((target) => target.dataset.sidebarSectionsSectionParam == key)
    if (trigger) trigger.setAttribute("aria-expanded", (!collapsed).toString())
  }

  collapsed(key) {
    return localStorage.getItem(this.storageKey(key)) == "true"
  }

  storageKey(key) {
    return `sidebar-section:${key}`
  }
}
