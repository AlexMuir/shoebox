import { Controller } from "@hotwired/stimulus"

// Captures File.lastModified timestamps from selected files and injects them
// as hidden fields so the server can store the original file modification dates.
//
// Usage:
//   <div data-controller="file-timestamps" data-file-timestamps-field-name-value="upload[file_timestamps][]">
//     <input type="file" multiple data-file-timestamps-target="input" data-action="change->file-timestamps#capture">
//   </div>
export default class extends Controller {
  static targets = ["input"]
  static values = { fieldName: { type: String, default: "upload[file_timestamps][]" } }

  capture() {
    this.clearTimestampFields()

    const files = this.inputTarget.files
    for (const file of files) {
      if (file.lastModified) {
        const iso = new Date(file.lastModified).toISOString()
        const hidden = document.createElement("input")
        hidden.type = "hidden"
        hidden.name = this.fieldNameValue
        hidden.value = iso
        hidden.dataset.fileTimestamp = "true"
        this.element.appendChild(hidden)
      }
    }
  }

  clearTimestampFields() {
    this.element.querySelectorAll("input[data-file-timestamp]").forEach(el => el.remove())
  }
}
