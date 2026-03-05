import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results", "chips", "createForm"]
  static values = {
    searchUrl: String,
    createUrl: String,
    inputName: { type: String, default: "storytelling_session[person_ids][]" }
  }

  connect() {
    this.timeout = null
    this.selectedPeople = []
    document.addEventListener("click", this.handleOutsideClick)
    this.syncFromHiddenInputs()
  }

  disconnect() {
    document.removeEventListener("click", this.handleOutsideClick)
  }

  syncFromHiddenInputs() {
    const existing = this.element.querySelectorAll(`input[type="hidden"][name="${this.inputNameValue}"]`)
    existing.forEach(input => {
      const id = parseInt(input.value, 10)
      const name = input.dataset.personName
      if (id && name && !this.selectedPeople.find(p => p.id === id)) {
        this.selectedPeople.push({ id, name })
      }
    })
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
      const response = await fetch(`${this.searchUrlValue}?q=${encodeURIComponent(query)}`, {
        headers: { "Accept": "application/json" }
      })
      const people = await response.json()
      this.showResults(people, query)
    } catch (e) {
      this.hideResults()
    }
  }

  showResults(people, query) {
    const selectedIds = this.selectedPeople.map(p => p.id)
    const available = people.filter(p => !selectedIds.includes(p.id))
    let html = ""

    if (available.length > 0) {
      available.forEach(person => {
        html += `<button type="button" class="dropdown-item" data-action="click->person-multi-select#select" data-person-id="${person.id}" data-person-name="${this.escapeHtml(person.name)}">${this.escapeHtml(person.name)}</button>`
      })
    } else if (people.length > 0) {
      html += `<div class="dropdown-item text-secondary disabled">All matches already selected</div>`
    } else {
      html += `<div class="dropdown-item text-secondary disabled">No matches found</div>`
    }

    html += `<div class="dropdown-divider"></div>`
    html += `<button type="button" class="dropdown-item text-primary" data-action="click->person-multi-select#showCreateForm"><i class="ti ti-plus me-1"></i>Create new person...</button>`

    this.resultsTarget.innerHTML = html
    this.resultsTarget.classList.add("show")
    this.hideCreateForm()
  }

  hideResults() {
    this.resultsTarget.classList.remove("show")
    this.resultsTarget.innerHTML = ""
  }

  select(event) {
    const id = parseInt(event.currentTarget.dataset.personId, 10)
    const name = event.currentTarget.dataset.personName

    if (this.selectedPeople.find(p => p.id === id)) return

    this.selectedPeople.push({ id, name })
    this.renderChips()
    this.inputTarget.value = ""
    this.hideResults()
    this.inputTarget.focus()
  }

  removePerson(event) {
    const id = parseInt(event.currentTarget.dataset.personId, 10)
    this.selectedPeople = this.selectedPeople.filter(p => p.id !== id)
    this.renderChips()
  }

  renderChips() {
    let chipsHtml = ""
    let hiddenHtml = ""

    this.selectedPeople.forEach(person => {
      chipsHtml += `
        <span class="badge bg-primary-lt me-1 mb-1 d-inline-flex align-items-center gap-1" style="font-size: 0.85rem; padding: 0.35em 0.65em;">
          ${this.escapeHtml(person.name)}
          <button type="button" class="btn-close btn-close-sm ms-1" style="font-size: 0.5rem;" data-action="click->person-multi-select#removePerson" data-person-id="${person.id}" aria-label="Remove"></button>
        </span>
      `
      hiddenHtml += `<input type="hidden" name="${this.inputNameValue}" value="${person.id}" data-person-name="${this.escapeHtml(person.name)}">`
    })

    this.chipsTarget.innerHTML = chipsHtml + hiddenHtml
  }

  showCreateForm(event) {
    event.preventDefault()
    this.hideResults()

    const query = this.inputTarget.value.trim()
    const parts = query.split(/\s+/)
    const firstName = parts[0] || ""
    const lastName = parts.slice(1).join(" ") || ""

    this.createFormTarget.innerHTML = `
      <div class="card card-sm border-primary mt-2">
        <div class="card-body p-3">
          <div class="d-flex align-items-center mb-2">
            <i class="ti ti-user-plus me-2 text-primary"></i>
            <strong class="text-primary">Create New Person</strong>
          </div>
          <div class="row g-2 mb-2">
            <div class="col-6">
              <input type="text" class="form-control form-control-sm" placeholder="First name" value="${this.escapeHtml(firstName)}" data-person-multi-select-target="firstName">
            </div>
            <div class="col-6">
              <input type="text" class="form-control form-control-sm" placeholder="Last name" value="${this.escapeHtml(lastName)}" data-person-multi-select-target="lastName">
            </div>
          </div>
          <div class="d-flex gap-2">
            <button type="button" class="btn btn-sm btn-primary" data-action="click->person-multi-select#createPerson">Create</button>
            <button type="button" class="btn btn-sm btn-ghost-secondary" data-action="click->person-multi-select#hideCreateForm">Cancel</button>
          </div>
          <div data-person-multi-select-target="createError" class="text-danger small mt-1" style="display:none"></div>
        </div>
      </div>
    `
    this.createFormTarget.style.display = "block"
  }

  hideCreateForm() {
    this.createFormTarget.style.display = "none"
    this.createFormTarget.innerHTML = ""
  }

  async createPerson() {
    const firstNameEl = this.element.querySelector("[data-person-multi-select-target='firstName']")
    const lastNameEl = this.element.querySelector("[data-person-multi-select-target='lastName']")
    const errorEl = this.element.querySelector("[data-person-multi-select-target='createError']")
    const firstName = firstNameEl?.value?.trim()
    const lastName = lastNameEl?.value?.trim()

    if (!firstName || !lastName) {
      errorEl.textContent = "Both first and last name are required"
      errorEl.style.display = "block"
      return
    }

    try {
      const token = document.querySelector("meta[name='csrf-token']")?.content
      const response = await fetch(this.createUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": token
        },
        body: JSON.stringify({ person: { first_name: firstName, last_name: lastName } })
      })

      if (response.ok) {
        const person = await response.json()
        this.selectedPeople.push({ id: person.id, name: person.name })
        this.renderChips()
        this.inputTarget.value = ""
        this.hideCreateForm()
        this.inputTarget.focus()
      } else {
        const data = await response.json()
        errorEl.textContent = data.errors?.join(", ") || "Failed to create person"
        errorEl.style.display = "block"
      }
    } catch (e) {
      errorEl.textContent = "Network error, please try again"
      errorEl.style.display = "block"
    }
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
