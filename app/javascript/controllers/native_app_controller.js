import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  openSettings() {
    this.#post({ type: "open-app-settings" });
  }

  #post(payload) {
    if (window.ReactNativeWebView?.postMessage) {
      window.ReactNativeWebView.postMessage(JSON.stringify(payload));
    }
  }
}
