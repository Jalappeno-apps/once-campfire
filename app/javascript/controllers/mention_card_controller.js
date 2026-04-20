import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "card" ]

  show() {
    if (!this.hasCardTarget) return
    this.cardTarget.hidden = false
    this.updatePlacement()
  }

  hide(event) {
    if (!this.hasCardTarget) return
    if (event?.type === "focusout" && this.element.contains(event.relatedTarget)) return
    this.cardTarget.hidden = true
  }

  updatePlacement() {
    const card = this.cardTarget
    card.classList.remove("mention-card--above")

    const rect = card.getBoundingClientRect()
    const viewportHeight = window.innerHeight || document.documentElement.clientHeight
    const bottomGap = viewportHeight - rect.bottom
    if (bottomGap < 12) card.classList.add("mention-card--above")
  }
}
