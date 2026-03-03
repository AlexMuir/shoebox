# frozen_string_literal: true

require "rails_helper"

RSpec.describe "photos:backfill rake task" do
  before do
    Rails.application.load_tasks
    allow_any_instance_of(Photo).to receive(:enqueue_photo_processing)
  end

  let(:family) { create(:family) }

  describe "photos:backfill" do
    it "enqueues PhotoProcessingJob for photos with empty image_metadata" do
      photo_with_empty_metadata = create(:photo, family: family, image_metadata: {})
      photo_with_nil_metadata = create(:photo, family: family, image_metadata: nil)
      photo_with_metadata = create(:photo, family: family, image_metadata: { "exif" => { "orientation" => 1 } })

      ActiveJob::Base.queue_adapter.enqueued_jobs.clear
      Rake::Task["photos:backfill"].execute

      enqueued_job_ids = ActiveJob::Base.queue_adapter.enqueued_jobs
        .select { |job| job[:job] == PhotoProcessingJob }
        .map { |job| job[:args].first }

      expect(enqueued_job_ids).to include(photo_with_empty_metadata.id, photo_with_nil_metadata.id)
      expect(enqueued_job_ids).not_to include(photo_with_metadata.id)
    end

    it "enqueues PhotoProcessingJob with correct photo IDs" do
      photo1 = create(:photo, family: family, image_metadata: {})
      photo2 = create(:photo, family: family, image_metadata: nil)

      ActiveJob::Base.queue_adapter.enqueued_jobs.clear
      Rake::Task["photos:backfill"].execute

      enqueued_job_ids = ActiveJob::Base.queue_adapter.enqueued_jobs
        .select { |job| job[:job] == PhotoProcessingJob }
        .map { |job| job[:args].first }

      expect(enqueued_job_ids).to include(photo1.id, photo2.id)
    end

    it "does not enqueue jobs for photos with existing metadata" do
      create(:photo, family: family, image_metadata: { "exif" => { "orientation" => 1 } })
      create(:photo, family: family, image_metadata: { "file" => { "size" => 1024 } })

      ActiveJob::Base.queue_adapter.enqueued_jobs.clear
      Rake::Task["photos:backfill"].execute

      enqueued_job_ids = ActiveJob::Base.queue_adapter.enqueued_jobs
        .select { |job| job[:job] == PhotoProcessingJob }

      expect(enqueued_job_ids).to be_empty
    end

    it "handles empty database gracefully" do
      ActiveJob::Base.queue_adapter.enqueued_jobs.clear
      expect {
        Rake::Task["photos:backfill"].execute
      }.not_to raise_error
    end
  end
end
