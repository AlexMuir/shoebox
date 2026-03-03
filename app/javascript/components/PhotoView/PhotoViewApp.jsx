import React, { useState, useEffect, useCallback } from 'react'
import { PhotoViewModal } from './PhotoViewModal'
import { fetchPhoto } from './api'

export function PhotoViewApp({ photoId, photoIds, csrfToken, onClose }) {
  const [currentPhotoId, setCurrentPhotoId] = useState(photoId)
  const [photoData, setPhotoData] = useState(null)
  const [isLoading, setIsLoading] = useState(true)
  const [isFullscreen, setIsFullscreen] = useState(false)
  const [zoomLevel, setZoomLevel] = useState(0)
  const [isTagMode, setIsTagMode] = useState(false)

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
  }, [currentPhotoId])

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
      photoIds={photoIds}
      csrfToken={csrfToken}
    />
  )
}
