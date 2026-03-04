export async function fetchPhoto(photoId) {
  const response = await fetch(`/photos/${photoId}.json`, { headers: { Accept: 'application/json' } })
  if (!response.ok) throw new Error(`HTTP ${response.status}`)
  return response.json()
}

export async function createFace(photoId, faceData, csrfToken) {
  const response = await fetch(`/photos/${photoId}/photo_faces.json`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Accept: 'application/json', 'X-CSRF-Token': csrfToken },
    body: JSON.stringify({ photo_face: faceData })
  })
  if (!response.ok) throw new Error(`HTTP ${response.status}`)
  return response.json()
}

export async function updateFace(photoId, faceId, data, csrfToken) {
  const response = await fetch(`/photos/${photoId}/photo_faces/${faceId}.json`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json', Accept: 'application/json', 'X-CSRF-Token': csrfToken },
    body: JSON.stringify({ photo_face: data })
  })
  if (!response.ok) throw new Error(`HTTP ${response.status}`)
  return response.json()
}

export async function deleteFace(photoId, faceId, csrfToken) {
  const response = await fetch(`/photos/${photoId}/photo_faces/${faceId}.json`, {
    method: 'DELETE',
    headers: { Accept: 'application/json', 'X-CSRF-Token': csrfToken }
  })
  if (!response.ok) throw new Error(`HTTP ${response.status}`)
  return response.json()
}

export async function searchPeople(query) {
  const response = await fetch(`/people/search?q=${encodeURIComponent(query)}`, { headers: { Accept: 'application/json' } })
  if (!response.ok) throw new Error(`HTTP ${response.status}`)
  return response.json()
}
