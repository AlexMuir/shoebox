import { useEffect, useMemo, useRef, useState } from 'react'

const ZOOM_SCALES = [1, 1.5, 2.25, 3.375]

function clampPan(panX, panY, container, scale) {
  if (!container || scale <= 1) {
    return { x: 0, y: 0 }
  }

  const maxX = (container.clientWidth * (scale - 1)) / 2
  const maxY = (container.clientHeight * (scale - 1)) / 2

  return {
    x: Math.max(-maxX, Math.min(maxX, panX)),
    y: Math.max(-maxY, Math.min(maxY, panY))
  }
}

export function PhotoImage({
  imageUrl,
  zoomLevel,
  isTagMode,
  faces,
  onImageClick,
  onFaceClick
}) {
  const containerRef = useRef(null)
  const dragStartRef = useRef(null)

  const [panX, setPanX] = useState(0)
  const [panY, setPanY] = useState(0)
  const [isDragging, setIsDragging] = useState(false)

  const safeZoomLevel = useMemo(() => {
    if (Number.isInteger(zoomLevel) && zoomLevel >= 0 && zoomLevel <= 3) {
      return zoomLevel
    }

    return 0
  }, [zoomLevel])

  const scale = ZOOM_SCALES[safeZoomLevel]
  const isZoomed = safeZoomLevel > 0

  useEffect(() => {
    if (safeZoomLevel === 0) {
      setPanX(0)
      setPanY(0)
      setIsDragging(false)
      dragStartRef.current = null
      return
    }

    const nextPan = clampPan(panX, panY, containerRef.current, scale)
    if (nextPan.x !== panX) setPanX(nextPan.x)
    if (nextPan.y !== panY) setPanY(nextPan.y)
  }, [panX, panY, safeZoomLevel, scale])

  const handleMouseDown = (event) => {
    if (!isZoomed || event.button !== 0) {
      return
    }

    event.preventDefault()
    setIsDragging(true)
    dragStartRef.current = {
      mouseX: event.clientX,
      mouseY: event.clientY,
      panX,
      panY
    }
  }

  const handleMouseMove = (event) => {
    if (!isDragging || !dragStartRef.current) {
      return
    }

    const deltaX = event.clientX - dragStartRef.current.mouseX
    const deltaY = event.clientY - dragStartRef.current.mouseY

    const nextPan = clampPan(
      dragStartRef.current.panX + deltaX,
      dragStartRef.current.panY + deltaY,
      containerRef.current,
      scale
    )

    setPanX(nextPan.x)
    setPanY(nextPan.y)
  }

  const stopDragging = () => {
    if (!isDragging) {
      return
    }

    setIsDragging(false)
    dragStartRef.current = null
  }

  const handleImageClick = (event) => {
    if (!isTagMode || !onImageClick) {
      return
    }

    const rect = event.currentTarget.getBoundingClientRect()
    if (rect.width === 0 || rect.height === 0) {
      return
    }

    const normalizedX = (event.clientX - rect.left) / rect.width
    const normalizedY = (event.clientY - rect.top) / rect.height

    onImageClick(normalizedX, normalizedY)
  }

  const containerClassName = [
    'photo-view-modal__image-container',
    isZoomed ? 'photo-view-modal__image-container--zoomable' : '',
    isDragging ? 'photo-view-modal__image-container--dragging' : ''
  ].filter(Boolean).join(' ')

  return (
    <div
      ref={containerRef}
      className={containerClassName}
      onMouseDown={handleMouseDown}
      onMouseMove={handleMouseMove}
      onMouseUp={stopDragging}
      onMouseLeave={stopDragging}
      style={{ overflow: 'hidden' }}
    >
      <div
        style={{
          position: 'relative',
          transformOrigin: 'center center',
          transform: `translate(${panX}px, ${panY}px) scale(${scale})`
        }}
      >
        <img
          src={imageUrl}
          alt=""
          className="photo-view-modal__image"
          onClick={handleImageClick}
          draggable={false}
        />

        <div className="photo-view-modal__face-layer">
          {faces.map((face) => {
            const faceClassName = [
              'photo-view-modal__face-box',
              face.person ? 'photo-view-modal__face-box--tagged' : '',
              isTagMode ? 'photo-view-modal__face-box--tagging' : ''
            ].filter(Boolean).join(' ')

            return (
              <div
                key={face.id}
                className={faceClassName}
                style={{
                  left: `${face.x * 100}%`,
                  top: `${face.y * 100}%`,
                  width: `${face.width * 100}%`,
                  height: `${face.height * 100}%`,
                  pointerEvents: isTagMode ? 'auto' : 'none'
                }}
                onClick={(event) => {
                  if (!isTagMode || !onFaceClick) {
                    return
                  }

                  event.stopPropagation()
                  onFaceClick(face.id)
                }}
              >
                {face.person && (
                  <span className="photo-view-modal__face-label">{face.person.name}</span>
                )}
              </div>
            )
          })}
        </div>
      </div>
    </div>
  )
}
