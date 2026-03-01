require "rails_helper"

RSpec.describe OrientationDetectionJob, type: :job do
  def stub_orientation_response(rotation:, confidence: 0.93)
    response = instance_double(Net::HTTPOK, body: {
      rotation: rotation,
      predicted_class: rotation / 90,
      confidence: confidence
    }.to_json)
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)

    allow(Net::HTTP).to receive(:start).and_return(response)
  end

  describe "#perform" do
    it "updates orientation_correction from the service response" do
      photo = create(:photo)
      stub_orientation_response(rotation: 270)

      described_class.perform_now(photo.id)

      expect(photo.reload.orientation_correction).to eq(270)
    end

    it "stores 0 when the service says the image is upright" do
      photo = create(:photo)
      stub_orientation_response(rotation: 0)

      described_class.perform_now(photo.id)

      expect(photo.reload.orientation_correction).to eq(0)
    end

    it "discards the job when the photo no longer exists" do
      expect {
        described_class.perform_now(-1)
      }.not_to raise_error
    end
  end
end
