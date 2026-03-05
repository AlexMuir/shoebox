import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    photoIds: Array,
    sessionId: Number,
    currentIndex: { type: Number, default: 0 },
  }

  static targets = ["photo", "progress", "recordBtn", "stopBtn", "skipBtn"]

  connect() {
    this.mediaRecorder = null
    this.audioChunks = []
    this.stream = null
    this.isRecording = false
    this.recordingPhotoId = null
    this.pendingAfterStop = null
    this.stopPromise = null
    this.resolveStopPromise = null
    this.photoRequestToken = 0
    this.photoIds = Array.isArray(this.photoIdsValue) ? this.photoIdsValue : []

    this.boundHandleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.boundHandleKeydown)

    this.mediaRecorderSupported = typeof window.MediaRecorder !== "undefined"
    if (!this.mediaRecorderSupported) {
      this.recordBtnTarget.disabled = true
      this.stopBtnTarget.disabled = true
      this.skipBtnTarget.disabled = false
      this.recordBtnTarget.title = "Audio recording is not supported in this browser"
    }

    this.currentIndexValue = this.normalizeIndex(this.currentIndexValue)
    this.updateProgress()
    this.loadCurrentPhoto()
    this.updateControlState()
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundHandleKeydown)
    this.cleanupStream()
  }

  async startRecording() {
    if (!this.mediaRecorderSupported || this.isRecording) return
    if (!this.hasCurrentPhoto()) return
    if (!navigator.mediaDevices?.getUserMedia) {
      window.alert("This browser cannot access the microphone.")
      return
    }

    if (!this.stream) {
      try {
        this.stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      } catch (error) {
        if (error?.name === "NotAllowedError") {
          window.alert("Microphone access is blocked. Allow access to record stories.")
        } else {
          window.alert("Unable to access microphone for recording.")
        }
        return
      }
    }

    const mimeType = this.preferredMimeType()
    try {
      this.mediaRecorder = mimeType ? new MediaRecorder(this.stream, { mimeType }) : new MediaRecorder(this.stream)
    } catch {
      this.mediaRecorder = new MediaRecorder(this.stream)
    }

    this.audioChunks = []
    this.stopPromise = new Promise((resolve) => {
      this.resolveStopPromise = resolve
    })
    this.recordingPhotoId = this.currentPhotoId()
    this.mediaRecorder.ondataavailable = (event) => {
      if (event.data && event.data.size > 0) this.audioChunks.push(event.data)
    }
    this.mediaRecorder.onerror = () => {
      this.resetRecorderState()
      this.completeStopPromise()
      this.updateControlState()
    }
    this.mediaRecorder.onstop = async () => {
      await this.handleRecordingStopped()
      this.completeStopPromise()
    }

    this.mediaRecorder.start()
    this.isRecording = true
    this.updateControlState()
  }

  async stopRecording() {
    if (!this.isRecording || !this.mediaRecorder) {
      return this.stopPromise || Promise.resolve()
    }

    this.mediaRecorder.stop()
    this.isRecording = false
    this.updateControlState()
    return this.stopPromise
  }

  async next() {
    if (this.isRecording) {
      this.pendingAfterStop = { direction: 1, autoStart: true }
      await this.stopRecording()
      return
    }

    await this.advance(1)
  }

  async previous() {
    if (this.isRecording) {
      this.pendingAfterStop = { direction: -1, autoStart: false }
      await this.stopRecording()
      return
    }

    await this.advance(-1)
  }

  async skip() {
    if (this.isRecording) {
      this.pendingAfterStop = { direction: 1, autoStart: false }
      await this.stopRecording()
      return
    }

    await this.advance(1)
  }

  async exit() {
    this.pendingAfterStop = null
    if (this.isRecording) {
      await this.stopRecording()
    }
    this.cleanupStream()
    window.location.href = "/photos"
  }

  handleKeydown(event) {
    if (event.defaultPrevented) return
    if (event.target instanceof HTMLInputElement || event.target instanceof HTMLTextAreaElement) return

    if (event.key === "ArrowLeft") {
      event.preventDefault()
      this.previous()
      return
    }

    if (event.key === "ArrowRight") {
      event.preventDefault()
      this.next()
      return
    }

    if (event.key === " " || event.code === "Space") {
      event.preventDefault()
      if (this.isRecording) {
        this.stopRecording()
      } else {
        this.startRecording()
      }
      return
    }

    if (event.key === "Escape") {
      event.preventDefault()
      this.exit()
    }
  }

  async handleRecordingStopped() {
    try {
      if (!this.audioChunks.length || !this.recordingPhotoId) return

      const mimeType = this.mediaRecorder?.mimeType || this.preferredMimeType() || "audio/webm"
      const extension = this.fileExtensionForMimeType(mimeType)
      const blob = new Blob(this.audioChunks, { type: mimeType })
      const file = new File([blob], `story-${this.recordingPhotoId}.${extension}`, { type: mimeType })
      await this.uploadStory(this.recordingPhotoId, file)
    } finally {
      this.resetRecorderState()
      this.updateControlState()

      const pending = this.pendingAfterStop
      this.pendingAfterStop = null

      if (pending) {
        await this.advance(pending.direction)
        if (pending.autoStart && this.hasCurrentPhoto()) {
          await this.startRecording()
        }
      }
    }
  }

  async uploadStory(photoId, audioFile) {
    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content
    const formData = new FormData()
    formData.append("story[photo_id]", String(photoId))
    formData.append("story[audio]", audioFile)

    const response = await fetch(`/storytelling_sessions/${this.sessionIdValue}/stories`, {
      method: "POST",
      headers: csrfToken ? { "X-CSRF-Token": csrfToken } : {},
      body: formData,
    })

    if (!response.ok) {
      const payload = await response.json().catch(() => ({}))
      const message = Array.isArray(payload?.errors) ? payload.errors.join(", ") : "Unable to save recording"
      window.alert(message)
    }
  }

  async advance(direction) {
    if (!this.photoIds.length) return

    const nextIndex = this.normalizeIndex(this.currentIndexValue + direction)
    if (nextIndex === this.currentIndexValue) return

    this.currentIndexValue = nextIndex
    this.updateProgress()
    await this.loadCurrentPhoto()
    this.updateControlState()
  }

  async loadCurrentPhoto() {
    if (!this.hasCurrentPhoto()) {
      this.photoTarget.removeAttribute("src")
      this.photoTarget.alt = "No photos available"
      return
    }

    const token = ++this.photoRequestToken
    const photoId = this.currentPhotoId()

    try {
      const response = await fetch(`/photos/${photoId}.json`, { headers: { Accept: "application/json" } })
      if (!response.ok) throw new Error("Failed to load photo")
      const payload = await response.json()
      if (token !== this.photoRequestToken) return

      this.photoTarget.src = payload.image_url || ""
      this.photoTarget.alt = payload.title || "Storytelling photo"
    } catch {
      if (token !== this.photoRequestToken) return
      this.photoTarget.removeAttribute("src")
      this.photoTarget.alt = "Unable to load photo"
    }
  }

  updateProgress() {
    const total = this.photoIds.length
    const current = total > 0 ? this.currentIndexValue + 1 : 0
    this.progressTarget.textContent = `${current} of ${total} photos`
  }

  updateControlState() {
    const hasPhoto = this.hasCurrentPhoto()
    this.recordBtnTarget.disabled = !hasPhoto || !this.mediaRecorderSupported || this.isRecording
    this.stopBtnTarget.disabled = !this.isRecording
    this.skipBtnTarget.disabled = !hasPhoto
    this.recordBtnTarget.classList.toggle("d-none", this.isRecording)
    this.stopBtnTarget.classList.toggle("d-none", !this.isRecording)
  }

  hasCurrentPhoto() {
    return this.currentIndexValue >= 0 && this.currentIndexValue < this.photoIds.length
  }

  currentPhotoId() {
    return this.hasCurrentPhoto() ? this.photoIds[this.currentIndexValue] : null
  }

  normalizeIndex(index) {
    if (!this.photoIds.length) return 0
    if (index < 0) return 0
    if (index >= this.photoIds.length) return this.photoIds.length - 1
    return index
  }

  preferredMimeType() {
    if (!window.MediaRecorder?.isTypeSupported) return null

    const candidates = ["audio/webm;codecs=opus", "audio/mp4"]
    return candidates.find((type) => window.MediaRecorder.isTypeSupported(type)) || null
  }

  fileExtensionForMimeType(mimeType) {
    if (mimeType.includes("mp4")) return "m4a"
    if (mimeType.includes("ogg")) return "ogg"
    if (mimeType.includes("mpeg")) return "mp3"
    return "webm"
  }

  resetRecorderState() {
    this.isRecording = false
    this.mediaRecorder = null
    this.audioChunks = []
    this.recordingPhotoId = null
  }

  completeStopPromise() {
    if (typeof this.resolveStopPromise === "function") {
      this.resolveStopPromise()
    }
    this.resolveStopPromise = null
    this.stopPromise = null
  }

  cleanupStream() {
    if (!this.stream) return
    this.stream.getTracks().forEach((track) => track.stop())
    this.stream = null
  }
}
