import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "hidden", "results", "createForm"]
  static values = {
    searchUrl: String,
    createUrl: String
  }

  connect() {
    this.timeout = null
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
    let html = ""

    if (people.length > 0) {
      people.forEach(person => {
        html += `<button type="button" class="dropdown-item" data-action="click->person-autocomplete#select" data-person-id="${person.id}" data-person-name="${this.escapeHtml(person.name)}">${this.escapeHtml(person.name)}</button>`
      })
    } else {
      html += `<div class="dropdown-item text-secondary disabled">No matches found</div>`
    }

    html += `<div class="dropdown-divider"></div>`
    html += `<button type="button" class="dropdown-item text-primary" data-action="click->person-autocomplete#showCreateForm"><i class="ti ti-plus me-1"></i>Create new person...</button>`

    this.resultsTarget.innerHTML = html
    this.resultsTarget.classList.add("show")
    this.hideCreateForm()
  }

  hideResults() {
    this.resultsTarget.classList.remove("show")
    this.resultsTarget.innerHTML = ""
  }

  select(event) {
    const id = event.currentTarget.dataset.personId
    const name = event.currentTarget.dataset.personName
    this.inputTarget.value = name
    this.hiddenTarget.value = id
    this.hideResults()
  }

  clear() {
    this.inputTarget.value = ""
    this.hiddenTarget.value = ""
    this.hideResults()
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
              <input type="text" class="form-control form-control-sm" placeholder="First name" value="${this.escapeHtml(firstName)}" data-person-autocomplete-target="firstName">
            </div>
            <div class="col-6">
              <input type="text" class="form-control form-control-sm" placeholder="Last name" value="${this.escapeHtml(lastName)}" data-person-autocomplete-target="lastName">
            </div>
          </div>
          <div class="d-flex gap-2">
            <button type="button" class="btn btn-sm btn-primary" data-action="click->person-autocomplete#createPerson">Create</button>
            <button type="button" class="btn btn-sm btn-ghost-secondary" data-action="click->person-autocomplete#hideCreateForm">Cancel</button>
          </div>
          <div data-person-autocomplete-target="createError" class="text-danger small mt-1" style="display:none"></div>
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
    const firstNameEl = this.element.querySelector("[data-person-autocomplete-target='firstName']")
    const lastNameEl = this.element.querySelector("[data-person-autocomplete-target='lastName']")
    const errorEl = this.element.querySelector("[data-person-autocomplete-target='createError']")
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
        this.inputTarget.value = person.name
        this.hiddenTarget.value = person.id
        this.hideCreateForm()
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
