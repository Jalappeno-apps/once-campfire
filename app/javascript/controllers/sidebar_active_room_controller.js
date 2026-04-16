import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "row" ]

  connect() {
    this.refresh()
    document.addEventListener("turbo:load", this.refresh)
  }

  disconnect() {
    document.removeEventListener("turbo:load", this.refresh)
  }

  refresh = () => {
    const currentRoomId = document.head.querySelector('meta[name="current-room-id"]')?.getAttribute("content")

    this.rowTargets.forEach((row) => {
      row.classList.toggle("sidebar-row--active", Boolean(currentRoomId) && row.dataset.roomId == currentRoomId)
    })
  }
}
