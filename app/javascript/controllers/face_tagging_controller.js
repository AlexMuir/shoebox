import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tagForm", "personSelect", "statusText", "submitButton", "faceBox"]
  static values = { updateUrlTemplate: String }

  connect() {
    this.selectedFaceId = null
    this.updateFormState()
  }

  selectFace(event) {
    const selectedBox = event.currentTarget
    const faceId = selectedBox.dataset.faceId
    const personId = selectedBox.dataset.personId || ""

    this.selectedFaceId = faceId
    this.faceBoxTargets.forEach((faceBox) => faceBox.classList.remove("is-selected"))
    selectedBox.classList.add("is-selected")

    this.tagFormTarget.action = this.updateUrlTemplateValue.replace("__FACE_ID__", faceId)
    this.personSelectTarget.value = personId

    const label = selectedBox.dataset.faceLabel || "Selected face"
    this.statusTextTarget.textContent = `${label} selected. Choose a person and save.`
    this.updateFormState()
  }

  updateFormState() {
    const enabled = Boolean(this.selectedFaceId)
    this.personSelectTarget.disabled = !enabled
    this.submitButtonTarget.disabled = !enabled
  }
}
