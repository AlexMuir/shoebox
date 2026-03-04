import { useEffect } from 'react'
import { PhotoImage } from './PhotoImage'
import { PhotoToolbar } from './PhotoToolbar'
import { PhotoSidebar } from './PhotoSidebar'
import { PhotoNavigation } from './PhotoNavigation'
import { TagOverlay } from './TagOverlay'
import { PersonAutocomplete } from './PersonAutocomplete'

export function PhotoViewModal({
  currentPhotoId,
  photoData,
  isLoading,
  isFullscreen,
  zoomLevel,
  isTagMode,
  pendingFace,
  onClose,
  onNavigate,
  onImageClick,
  onFaceClick,
  onFaceCreated,
  onCancelPendingFace,
  setIsFullscreen,
  setZoomLevel,
  setIsTagMode,
  csrfToken,
  loadError
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

  const handleModalClick = (event) => {
    if (!isTagMode || !pendingFace) return

    const sidebar = event.currentTarget.querySelector('.photo-view-modal__sidebar')
    if (sidebar && sidebar.contains(event.target)) return

    const autocomplete = event.currentTarget.querySelector('.photo-view-modal__autocomplete')
    if (autocomplete && autocomplete.contains(event.target)) return

    const imageArea = event.currentTarget.querySelector('.photo-view-modal__image-area')
    if (imageArea && imageArea.contains(event.target)) return

    onCancelPendingFace()
  }

  return (
    <div className={`photo-view-modal ${isFullscreen ? 'photo-view-modal--fullscreen' : ''}`} onClick={handleModalClick}>
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
            <div className="photo-view-modal__loading">
              <div className="photo-view-modal__spinner" />
            </div>
          ) : loadError === 'not_found' ? (
            <div className="photo-view-modal__error">
              <p>Photo not found.</p>
              <button onClick={onClose}>Close</button>
            </div>
          ) : loadError === 'network_error' ? (
            <div className="photo-view-modal__error">
              <p>Failed to load photo. Please try again.</p>
            </div>
          ) : !photoData?.image_url ? (
            <div className="photo-view-modal__no-image">
              <i className="ti ti-photo" />
              <p>No image attached</p>
            </div>
          ) : (
            <PhotoImage
              imageUrl={photoData?.image_url}
              zoomLevel={zoomLevel}
              isTagMode={isTagMode}
              faces={photoData?.faces || []}
              pendingFace={pendingFace}
              onImageClick={onImageClick}
              onFaceClick={onFaceClick}
            />
          )}
          <PhotoNavigation
            prevId={prevId}
            nextId={nextId}
            onNavigate={onNavigate}
            isTagMode={isTagMode}
          />
          <TagOverlay isTagMode={isTagMode} onFinishTagging={() => setIsTagMode(false)} />
          <PersonAutocomplete
            pendingFace={pendingFace}
            onPersonSelected={onFaceCreated}
            onCancel={onCancelPendingFace}
            csrfToken={csrfToken}
          />
        </div>
        
        {!isFullscreen && (
          <PhotoSidebar photoData={photoData} photoId={currentPhotoId} />
        )}
      </div>
    </div>
  )
}
