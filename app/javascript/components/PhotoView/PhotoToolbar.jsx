import React from 'react'

export function PhotoToolbar({
  zoomLevel,
  maxZoom,
  isTagMode,
  isFullscreen,
  onZoomIn,
  onZoomOut,
  onToggleTag,
  onToggleFullscreen
}) {
  return (
    <div className="photo-view-modal__toolbar">
      <button
        className="photo-view-modal__toolbar-btn photo-view-modal__toolbar-btn--zoom-in"
        onClick={onZoomIn}
        disabled={zoomLevel >= maxZoom || isTagMode}
        aria-label="Zoom in"
      >
        <i className="ti ti-zoom-in" />
      </button>
      <button
        className="photo-view-modal__toolbar-btn photo-view-modal__toolbar-btn--zoom-out"
        onClick={onZoomOut}
        disabled={zoomLevel <= 0 || isTagMode}
        aria-label="Zoom out"
      >
        <i className="ti ti-zoom-out" />
      </button>
      <button
        className={`photo-view-modal__toolbar-btn photo-view-modal__toolbar-btn--tag ${isTagMode ? 'photo-view-modal__toolbar-btn--active' : ''}`}
        onClick={onToggleTag}
        disabled={zoomLevel > 0}
        aria-label="Tag people"
      >
        <i className="ti ti-tag" />
      </button>
      <button
        className="photo-view-modal__toolbar-btn photo-view-modal__toolbar-btn--fullscreen"
        onClick={onToggleFullscreen}
        aria-label={isFullscreen ? "Exit fullscreen" : "Enter fullscreen"}
      >
        <i className={`ti ${isFullscreen ? 'ti-arrows-minimize' : 'ti-arrows-maximize'}`} />
      </button>
    </div>
  )
}
