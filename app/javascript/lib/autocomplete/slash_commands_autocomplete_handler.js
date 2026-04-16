import BaseAutocompleteHandler from "lib/autocomplete/base_autocomplete_handler"
import { Renderer } from "lib/autocomplete/renderer"

const SLASH_COMMANDS = [
  {
    value: "/meet",
    name: "Start call (/meet)",
    icon: "📹"
  }
]

export default class extends BaseAutocompleteHandler {
  get pattern() {
    return /^\/([a-z]*)$/
  }

  fetchResultsForQuery(query, callback) {
    const normalized = (query || "").toLowerCase()
    const commands = SLASH_COMMANDS.filter((command) => {
      return command.value.slice(1).startsWith(normalized)
    })

    this.setAutocompletables(commands)
    const html = this.autocompletablesMatchingQuery("").length
      ? new Renderer().renderAutocompletableSuggestions(commands)
      : ""
    callback(html)
  }

  insertAutocompletable(autocompletable, range, terminator) {
    if (!autocompletable) return

    const editor = this.element.editor
    if (range) editor.setSelectedRange(range)
    editor.deleteInDirection("forward")
    editor.insertString(autocompletable.value)
    editor.insertString(terminator || " ")
  }
}
