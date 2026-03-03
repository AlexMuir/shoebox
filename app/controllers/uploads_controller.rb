class UploadsController < ApplicationController
  before_action :set_upload, only: [ :show, :edit, :update ]

  def index
    @uploads = current_family.uploads.recent
  end

  def show
    @photos = @upload.photos.recent
  end

  def new
    @upload = current_family.uploads.build
  end

  def create
    @upload = current_family.uploads.build(upload_params.except(:files, :file_timestamps))
    @upload.user = Current.user

    if @upload.save
      process_uploaded_files(@upload)
      @upload.update!(status: "completed")
      redirect_to @upload, notice: "#{@upload.photos_count} photos uploaded successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @upload.update(upload_params.except(:files, :file_timestamps))
      redirect_to @upload, notice: "Upload updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_upload
    @upload = current_family.uploads.find(params[:id])
  end

  def upload_params
    params.expect(upload: [
      :source_album, :source_owner_id, :scanned_by_person_id, :scanned_at, :notes,
      :date_type, :year_from, :year_to, files: [], file_timestamps: []
    ])
  end
  def process_uploaded_files(upload)
    raw_files = params[:upload][:files]
    files = raw_files&.select { |f| f.respond_to?(:content_type) }
    return unless files&.any?

    timestamps = params[:upload][:file_timestamps]&.reject(&:blank?) || []

    files.each_with_index do |file, index|
      next unless file.content_type&.start_with?("image/")

      file_modified_at = timestamps[index].present? ? Time.zone.parse(timestamps[index]) : nil

      photo = current_family.photos.build(
        upload: upload,
        uploaded_by: Current.user,
        original_filename: file.original_filename,
        date_type: upload.date_type,
        year: upload.year_from,
        file_modified_at: file_modified_at
      )
      photo.original.attach(file)

      if photo.save
        PhotoProcessingJob.perform_later(photo.id)
        if upload.source_album.present?
          photo.photo_sources.create!(
            description: upload.source_album,
            notes: [ upload.source_owner&.full_name, upload.scanned_by_person&.full_name ].compact.join(", scanned by ")
          )
        end
      end
    end
  end
end
