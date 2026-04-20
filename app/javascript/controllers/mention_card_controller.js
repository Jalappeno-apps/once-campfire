import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "card" ]

  show() {
    if (!this.hasCardTarget) return
    this.cardTarget.hidden = false
  }

  hide(event) {
    if (!this.hasCardTarget) return
    if (event?.type === "focusout" && this.element.contains(event.relatedTarget)) return
    this.cardTarget.hidden = true
  }
}
