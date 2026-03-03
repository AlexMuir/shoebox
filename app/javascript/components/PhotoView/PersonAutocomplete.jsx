import { useEffect, useRef, useState } from 'react'
import { searchPeople } from './api'

export function PersonAutocomplete({ pendingFace, onPersonSelected, onCancel, csrfToken }) {
  const inputRef = useRef(null)
  const [query, setQuery] = useState('')
  const [results, setResults] = useState([])
  const [isSearching, setIsSearching] = useState(false)
  const [showCreateForm, setShowCreateForm] = useState(false)
  const [firstName, setFirstName] = useState('')
  const [lastName, setLastName] = useState('')
  const [createError, setCreateError] = useState('')

  useEffect(() => {
    if (!pendingFace) return

    inputRef.current?.focus()
    setQuery('')
    setResults([])
    setShowCreateForm(false)
    setFirstName('')
    setLastName('')
    setCreateError('')
  }, [pendingFace])

  useEffect(() => {
    if (!pendingFace) return

    const trimmedQuery = query.trim()
    if (trimmedQuery.length < 2) {
      setResults([])
      setIsSearching(false)
      return
    }

    const timeout = setTimeout(async () => {
      setIsSearching(true)

      try {
        const people = await searchPeople(trimmedQuery)
        setResults(Array.isArray(people) ? people : [])
      } catch (error) {
        console.error('Failed to search people:', error)
        setResults([])
      } finally {
        setIsSearching(false)
      }
    }, 250)

    return () => clearTimeout(timeout)
  }, [query, pendingFace])

  if (!pendingFace) {
    return null
  }

  const isNearRightEdge = pendingFace.x + pendingFace.width > 0.7
  const autocompleteStyle = {
    top: `${pendingFace.y * 100}%`,
    left: isNearRightEdge ? `${pendingFace.x * 100}%` : `${(pendingFace.x + pendingFace.width) * 100}%`,
    transform: isNearRightEdge ? 'translateX(calc(-100% - 8px))' : 'translateX(8px)'
  }

  const showResults = query.trim().length >= 2

  const handleShowCreateForm = () => {
    const parts = query.trim().split(/\s+/).filter(Boolean)
    setFirstName(parts[0] || '')
    setLastName(parts.slice(1).join(' ') || '')
    setShowCreateForm(true)
    setCreateError('')
  }

  const handleCreatePerson = async () => {
    const trimmedFirstName = firstName.trim()
    const trimmedLastName = lastName.trim()

    if (!trimmedFirstName || !trimmedLastName) {
      setCreateError('Both first and last name are required')
      return
    }

    try {
      const response = await fetch('/people.json', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
          'X-CSRF-Token': csrfToken
        },
        body: JSON.stringify({ person: { first_name: trimmedFirstName, last_name: trimmedLastName } })
      })

      if (!response.ok) {
        const data = await response.json()
        setCreateError(data.errors?.join(', ') || 'Failed to create person')
        return
      }

      const person = await response.json()
      onPersonSelected(person.id, person.name)
    } catch (error) {
      console.error('Failed to create person:', error)
      setCreateError('Network error, please try again')
    }
  }

  const handleKeyDown = (event) => {
    if (event.key === 'Escape') {
      event.preventDefault()
      onCancel()
    }
  }

  return (
    <div className="photo-view-modal__autocomplete" style={autocompleteStyle} onKeyDown={handleKeyDown}>
      <input
        ref={inputRef}
        type="text"
        value={query}
        placeholder="Search people"
        className="photo-view-modal__autocomplete-input"
        onChange={(event) => {
          setQuery(event.target.value)
          setShowCreateForm(false)
          setCreateError('')
        }}
      />

      {showResults && (
        <div className="photo-view-modal__autocomplete-results">
          {isSearching ? (
            <div className="photo-view-modal__autocomplete-item">Searching...</div>
          ) : results.length > 0 ? (
            results.map((person) => (
              <button
                key={person.id}
                type="button"
                className="photo-view-modal__autocomplete-item"
                onClick={() => onPersonSelected(person.id, person.name)}
              >
                {person.name}
              </button>
            ))
          ) : (
            <>
              <div className="photo-view-modal__autocomplete-item">No matches found</div>
              <button
                type="button"
                className="photo-view-modal__autocomplete-item"
                onClick={handleShowCreateForm}
              >
                Create new person...
              </button>
            </>
          )}
        </div>
      )}

      {showCreateForm && (
        <div className="photo-view-modal__autocomplete-create">
          <input
            type="text"
            className="photo-view-modal__autocomplete-input"
            placeholder="First name"
            value={firstName}
            onChange={(event) => setFirstName(event.target.value)}
          />
          <input
            type="text"
            className="photo-view-modal__autocomplete-input"
            placeholder="Last name"
            value={lastName}
            onChange={(event) => setLastName(event.target.value)}
          />
          <button
            type="button"
            className="photo-view-modal__autocomplete-item"
            onClick={handleCreatePerson}
          >
            Create
          </button>
          {createError && <div className="photo-view-modal__autocomplete-error">{createError}</div>}
        </div>
      )}
    </div>
  )
}
