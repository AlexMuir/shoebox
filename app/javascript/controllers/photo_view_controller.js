import { Controller } from "@hotwired/stimulus"
import { createRoot } from "react-dom/client"

export default class extends Controller {
  static values = {
    photoIds: Array,
  }

  connect() {
    this.root = null
    this.mountPoint = null
  }

  async open(event) {
    event.preventDefault()
    const photoId = event.currentTarget.dataset.photoViewPhotoIdValue
    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content

    if (!this.mountPoint) {
      this.mountPoint = document.createElement("div")
      this.mountPoint.id = "photo-view-root"
      document.body.appendChild(this.mountPoint)
    }

    const { PhotoViewApp } = await import("../components/PhotoView/PhotoViewApp")
    const { createElement } = await import("react")

    this.root = createRoot(this.mountPoint)
    this.root.render(
      createElement(PhotoViewApp, {
        photoId: parseInt(photoId, 10),
        photoIds: this.photoIdsValue,
        csrfToken,
        onClose: () => this.close(),
      })
    )
  }

  close() {
    if (this.root) {
      this.root.unmount()
      this.root = null
    }
    if (this.mountPoint) {
      this.mountPoint.remove()
      this.mountPoint = null
    }
  }

  disconnect() {
    this.close()
  }
}
