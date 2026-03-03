import React, { useEffect } from 'react'
import { PhotoImage } from './PhotoImage'
import { PhotoToolbar } from './PhotoToolbar'
import { PhotoSidebar } from './PhotoSidebar'
import { PhotoNavigation } from './PhotoNavigation'
import { TagOverlay } from './TagOverlay'

export function PhotoViewModal({
  currentPhotoId,
  photoData,
  isLoading,
  isFullscreen,
  zoomLevel,
  isTagMode,
  onClose,
  onNavigate,
  setIsFullscreen,
  setZoomLevel,
  setIsTagMode,
  photoIds,
  csrfToken
}) {
  // Handle body scroll lock and URL restoration
  useEffect(() => {
    const originalOverflow = document.body.style.overflow
    const originalPathname = window.location.pathname

    document.body.style.overflow = 'hidden'

    return () => {
      document.body.style.overflow = originalOverflow
      window.history.replaceState(null, '', originalPathname)
    }
  }, [])

  // Handle URL updates when currentPhotoId changes
  useEffect(() => {
    if (currentPhotoId) {
      window.history.replaceState(null, '', `/photos/${currentPhotoId}`)
    }
  }, [currentPhotoId])

  // Handle keyboard events
  useEffect(() => {
    const handleKeyDown = (e) => {
      if (e.key === 'Escape') {
        onClose()
      } else if (e.key === 'ArrowLeft') {
        if (onNavigate) onNavigate('prev')
      } else if (e.key === 'ArrowRight') {
        if (onNavigate) onNavigate('next')
      }
    }

    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [onClose, onNavigate])

  const prevId = photoData?.prev_id
  const nextId = photoData?.next_id

  return (
    <div className={`photo-view-modal ${isFullscreen ? 'photo-view-modal--fullscreen' : ''}`}>
      <button className="photo-view-modal__close" onClick={onClose}>
        <i className="ti ti-x" />
      </button>
      
      <PhotoToolbar
        zoomLevel={zoomLevel}
        maxZoom={3}
        isTagMode={isTagMode}
        isFullscreen={isFullscreen}
        onZoomIn={() => setZoomLevel(Math.min(3, zoomLevel + 1))}
        onZoomOut={() => setZoomLevel(Math.max(0, zoomLevel - 1))}
        onToggleTag={() => { if (zoomLevel === 0) setIsTagMode(!isTagMode) }}
        onToggleFullscreen={() => setIsFullscreen(!isFullscreen)}
      />

      <div className="photo-view-modal__content">
        <div className="photo-view-modal__image-area">
          {isLoading ? (
            <div className="photo-view-modal__loading">Loading...</div>
          ) : (
            <PhotoImage
              imageUrl={photoData?.image_url}
              zoomLevel={zoomLevel}
              isTagMode={isTagMode}
              faces={photoData?.faces || []}
              onImageClick={() => {}}
              onFaceClick={() => {}}
            />
          )}
          <PhotoNavigation
            prevId={prevId}
            nextId={nextId}
            onNavigate={onNavigate}
            isTagMode={isTagMode}
          />
          <TagOverlay isTagMode={isTagMode} onFinishTagging={() => setIsTagMode(false)} />
        </div>
        
        {!isFullscreen && (
          <PhotoSidebar photoData={photoData} photoId={currentPhotoId} />
        )}
      </div>
    </div>
  )
}
