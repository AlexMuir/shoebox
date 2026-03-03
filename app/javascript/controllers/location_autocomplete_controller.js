import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "hidden", "results", "createForm"]
  static values = {
    searchUrl: String,
    createUrl: String,
    localOnly: Boolean
  }

  connect() {
    this.timeout = null
    this.sessionToken = crypto.randomUUID()
    document.addEventListener("click", this.handleOutsideClick)
  }

  disconnect() {
    document.removeEventListener("click", this.handleOutsideClick)
  }

  onKeydown(event) {
    if (event.key === "Escape") {
      this.hideResults()
    }
  }

  onInput() {
    clearTimeout(this.timeout)
    const query = this.inputTarget.value.trim()

    if (query.length < 2) {
      this.hideResults()
      return
    }

    this.timeout = setTimeout(() => this.search(query), 250)
  }

  async search(query) {
    try {
      const response = await fetch(`${this.searchUrlValue}?q=${encodeURIComponent(query)}&session_token=${this.sessionToken}`, {
        headers: { "Accept": "application/json" }
      })
      const data = await response.json()
      this.showResults(data)
    } catch (e) {
      this.hideResults()
    }
  }

  showResults(data) {
    const local = data.local || []
    const google = data.google || []
    let html = ""

    // Local section
    html += `<div class="dropdown-header">Existing Locations</div>`
    if (local.length > 0) {
      local.forEach(loc => {
        const display = loc.parent_name ? `${this.escapeHtml(loc.name)} — ${this.escapeHtml(loc.parent_name)}` : this.escapeHtml(loc.name)
        html += `<button type="button" class="dropdown-item" data-action="click->location-autocomplete#selectLocal" data-location-id="${loc.id}" data-location-name="${this.escapeHtml(loc.name)}">${display}</button>`
      })
    } else {
      html += `<div class="dropdown-item text-secondary disabled">No matching locations</div>`
    }

    // Google section (skip if localOnly)
    if (!this.localOnlyValue) {
      html += `<div class="dropdown-divider"></div>`
      html += `<div class="dropdown-header">Google Places</div>`
      if (google.length > 0) {
        google.forEach(place => {
          html += `<button type="button" class="dropdown-item" data-action="click->location-autocomplete#selectGoogle" data-place-id="${place.place_id}" data-place-description="${this.escapeHtml(place.description)}">${this.escapeHtml(place.description)}</button>`
        })
      } else {
        html += `<div class="dropdown-item text-secondary disabled">No Google results</div>`
      }
    }

    this.resultsTarget.innerHTML = html
    this.resultsTarget.classList.add("show")
  }

  hideResults() {
    this.resultsTarget.classList.remove("show")
    this.resultsTarget.innerHTML = ""
  }

  selectLocal(event) {
    const locationId = event.currentTarget.dataset.locationId
    const locationName = event.currentTarget.dataset.locationName
    this.inputTarget.value = locationName
    this.hiddenTarget.value = locationId
    this.hideResults()
  }

  async selectGoogle(event) {
    const placeId = event.currentTarget.dataset.placeId
    const placeDescription = event.currentTarget.dataset.placeDescription
    this.inputTarget.value = placeDescription
    this.inputTarget.disabled = true
    this.hideResults()

    try {
      const token = document.querySelector("meta[name='csrf-token']")?.content
      const response = await fetch(this.createUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": token
        },
        body: JSON.stringify({ place_id: placeId, session_token: this.sessionToken })
      })

      if (response.ok) {
        const location = await response.json()
        this.hiddenTarget.value = location.id
        this.inputTarget.value = location.name
        this.sessionToken = crypto.randomUUID()
      } else {
        this.inputTarget.value = ""
        if (this.hasCreateFormTarget) {
          this.createFormTarget.innerHTML = `<div class="text-danger small mt-1">Failed to create location from Google Places</div>`
        }
      }
    } catch (e) {
      this.inputTarget.value = ""
      if (this.hasCreateFormTarget) {
        this.createFormTarget.innerHTML = `<div class="text-danger small mt-1">Network error, please try again</div>`
      }
    } finally {
      this.inputTarget.disabled = false
    }
  }

  clear() {
    this.inputTarget.value = ""
    this.hiddenTarget.value = ""
    this.hideResults()
  }

  handleOutsideClick = (event) => {
    if (!this.element.contains(event.target)) {
      this.hideResults()
    }
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
