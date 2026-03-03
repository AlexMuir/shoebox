import { useState, useEffect, useCallback } from 'react'
import { PhotoViewModal } from './PhotoViewModal'
import { createFace, deleteFace, fetchPhoto } from './api'

export function PhotoViewApp({ photoId, photoIds, csrfToken, onClose }) {
  const [currentPhotoId, setCurrentPhotoId] = useState(photoId)
  const [photoData, setPhotoData] = useState(null)
  const [isLoading, setIsLoading] = useState(true)
  const [isFullscreen, setIsFullscreen] = useState(false)
  const [zoomLevel, setZoomLevel] = useState(0)
  const [isTagMode, setIsTagMode] = useState(false)
  const [pendingFace, setPendingFace] = useState(null)

  const loadPhoto = useCallback(async (id) => {
    setIsLoading(true)
    try {
      const data = await fetchPhoto(id)
      setPhotoData(data)
    } catch (error) {
      console.error('Failed to fetch photo:', error)
    } finally {
      setIsLoading(false)
    }
  }, [])

  useEffect(() => {
    loadPhoto(currentPhotoId)
  }, [currentPhotoId, loadPhoto])

  useEffect(() => {
    if (zoomLevel > 0) {
      setIsTagMode(false)
    }
  }, [zoomLevel])

  useEffect(() => {
    setZoomLevel(0)
    setIsTagMode(false)
    setPendingFace(null)
  }, [currentPhotoId])

  const handleImageClick = useCallback((normalizedX, normalizedY) => {
    if (!isTagMode) return

    const width = 0.1
    const height = 0.1
    const x = Math.max(0, Math.min(1 - width, normalizedX - width / 2))
    const y = Math.max(0, Math.min(1 - height, normalizedY - height / 2))

    setPendingFace({ x, y, width, height })
  }, [isTagMode])

  const handleFaceCreated = useCallback(async (personId, _personName) => {
    if (!pendingFace) return

    try {
      const faceData = { ...pendingFace, person_id: personId }
      await createFace(currentPhotoId, faceData, csrfToken)
      const updatedPhoto = await fetchPhoto(currentPhotoId)
      setPhotoData(updatedPhoto)
      setPendingFace(null)
    } catch (error) {
      console.error('Failed to create face:', error)
      setPendingFace(null)
    }
  }, [pendingFace, currentPhotoId, csrfToken])

  const handleCancelPendingFace = useCallback(() => {
    setPendingFace(null)
  }, [])

  const handleFaceClick = useCallback(async (faceId) => {
    if (!isTagMode) return

    try {
      await deleteFace(currentPhotoId, faceId, csrfToken)
      const updatedPhoto = await fetchPhoto(currentPhotoId)
      setPhotoData(updatedPhoto)
    } catch (error) {
      console.error('Failed to delete face:', error)
    }
  }, [isTagMode, currentPhotoId, csrfToken])

  const handleNavigate = useCallback((direction) => {
    if (!photoIds || photoIds.length === 0) return

    const currentIndex = photoIds.indexOf(currentPhotoId)
    if (currentIndex === -1) return

    let nextIndex
    if (direction === 'next') {
      nextIndex = (currentIndex + 1) % photoIds.length
    } else if (direction === 'prev') {
      nextIndex = (currentIndex - 1 + photoIds.length) % photoIds.length
    }

    if (nextIndex !== undefined) {
      setCurrentPhotoId(photoIds[nextIndex])
    }
  }, [currentPhotoId, photoIds])

  return (
    <PhotoViewModal
      currentPhotoId={currentPhotoId}
      photoData={photoData}
      isLoading={isLoading}
      isFullscreen={isFullscreen}
      zoomLevel={zoomLevel}
      isTagMode={isTagMode}
      onClose={onClose}
      onNavigate={handleNavigate}
      setCurrentPhotoId={setCurrentPhotoId}
      setPhotoData={setPhotoData}
      setIsFullscreen={setIsFullscreen}
      setZoomLevel={setZoomLevel}
      setIsTagMode={setIsTagMode}
      pendingFace={pendingFace}
      onImageClick={handleImageClick}
      onFaceClick={handleFaceClick}
      onFaceCreated={handleFaceCreated}
      onCancelPendingFace={handleCancelPendingFace}
      csrfToken={csrfToken}
    />
  )
}
