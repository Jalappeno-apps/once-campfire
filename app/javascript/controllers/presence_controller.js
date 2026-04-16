import { Controller } from "@hotwired/stimulus"
import { cable } from "@hotwired/turbo-rails"
import { delay, nextFrame } from "helpers/timing_helpers"

const REFRESH_INTERVAL = 50 * 1000 // 50 seconds

// We delay transmitting visibility changes to ignore brief periods of invisibility,
// like switching to another tab and back
const VISIBILITY_CHANGE_DELAY = 5000 // 5 seconds

export default class extends Controller {
  async connect() {
    this.disconnected = false

    this.channel = await cable.subscribeTo({ channel: "PresenceChannel", room_id: Current.room.id }, {
      connected: this.#websocketConnected,
      disconnected: this.#websocketDisconnected
    })

    if (this.disconnected) {
      this.channel?.unsubscribe()
      return
    }

    this.wasVisible = true

    await nextFrame()
    if (this.disconnected) {
      this.channel?.unsubscribe()
      return
    }

    this.dispatch("present", { detail: { roomId: Current.room.id } })
  }

  disconnect() {
    this.disconnected = true
    this.connected = false
    this.#stopRefreshTimer()
    this.channel?.unsubscribe()
  }

  visibilityChanged = () => {
    if (this.#isVisible) {
      this.#visible()
    } else {
      this.#hidden()
    }
  }

  #websocketConnected = () => {
    if (this.disconnected) return
    this.connected = true
    this.#startRefreshTimer()
  }

  #websocketDisconnected = () => {
    this.connected = false
    this.#stopRefreshTimer()
  }

  #visible = async () => {
    await delay(VISIBILITY_CHANGE_DELAY)

    if (this.disconnected || !this.connected || !this.channel) return

    if (this.#isVisible && !this.wasVisible) {
      this.#sendAction("present")
      this.#startRefreshTimer()
      this.wasVisible = true
    }
  }

  #hidden = async () => {
    await delay(VISIBILITY_CHANGE_DELAY)

    if (this.disconnected || !this.connected || !this.channel) return

    if (this.wasVisible && !this.#isVisible) {
      this.#stopRefreshTimer()
      this.#sendAction("absent")
      this.wasVisible = false
    }
  }

  #startRefreshTimer = () => {
    this.refreshTimer ??= setInterval(this.#refresh, REFRESH_INTERVAL)
  }

  #stopRefreshTimer = () => {
    clearInterval(this.refreshTimer)
    this.refreshTimer = null
  }

  #refresh = () => {
    if (this.disconnected || !this.connected || !this.channel) return
    this.#sendAction("refresh")
  }

  #sendAction(action) {
    if (this.disconnected || !this.channel) return
    this.channel.send({ action })
  }

  get #isVisible() {
    return document.visibilityState === "visible"
  }
}
