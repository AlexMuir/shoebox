import React from 'react'

export function PhotoNavigation({ prevId, nextId, isTagMode, onNavigate }) {
  const disabledStyle = isTagMode ? { pointerEvents: 'none', opacity: 0.3 } : {}

  return (
    <>
      {prevId && (
        <button
          className="photo-view-modal__nav-arrow photo-view-modal__nav-arrow--prev"
          onClick={() => onNavigate('prev')}
          aria-label="Previous photo"
          disabled={isTagMode}
          style={disabledStyle}
        >
          <i className="ti ti-chevron-left" />
        </button>
      )}
      
      {nextId && (
        <button
          className="photo-view-modal__nav-arrow photo-view-modal__nav-arrow--next"
          onClick={() => onNavigate('next')}
          aria-label="Next photo"
          disabled={isTagMode}
          style={disabledStyle}
        >
          <i className="ti ti-chevron-right" />
        </button>
      )}
    </>
  )
}
