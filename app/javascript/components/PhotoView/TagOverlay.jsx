import React from 'react'

export function TagOverlay({ isTagMode, onFinishTagging }) {
  if (!isTagMode) return null

  return (
    <div className="photo-view-modal__tag-overlay">
      <p className="photo-view-modal__tag-overlay-text">
        Click on the photo to start tagging. Click on a tag to remove it.
      </p>
      <button className="photo-view-modal__tag-done-btn" onClick={onFinishTagging}>
        Finished tagging
      </button>
    </div>
  )
}
