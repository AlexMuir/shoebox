require "rails_helper"

RSpec.describe "Date determination flow", type: :integration do
  describe "end-to-end determination lifecycle" do
    it "creates EXIF determination on upload and populates determined fields" do
      photo = create(:photo)
      vips_image = instance_double(Vips::Image)
      exif_timestamp = "2020:07:04 10:11:12"

      allow(Vips::Image).to receive(:new_from_file).and_return(vips_image)
      allow(vips_image).to receive(:get).with("exif-ifd2-DateTimeOriginal").and_return(exif_timestamp)

      expect {
        photo.send(:extract_exif_taken_at)
      }.to change { photo.date_determinations.where(source_type: "exif").count }.by(1)

      photo.reload
      determination = photo.date_determinations.find_by!(source_type: "exif")

      expect(determination.determined_year).to eq(2020)
      expect(determination.determined_month).to eq(7)
      expect(determination.determined_day).to eq(4)
      expect(photo.determined_year).to eq(2020)
      expect(photo.determined_month).to eq(7)
      expect(photo.determined_day).to eq(4)
      expect(photo.determined_date_text).to eq("04 July 2020")
    end

    it "creates age-based determination and updates determined year when confidence is higher" do
      person = create(:person, dob_year: 1950, date_of_birth: Date.new(1950, 6, 10))
      photo = create(:photo, family: person.family)
      create(:date_determination, photo: photo, source_type: "filename", determined_year: 1999, confidence: 0.6)
      photo_person = create(:photo_person, photo: photo, person: person, estimated_age: 25)

      expect {
        Photo::DateDeterminationService.from_age_estimate(photo_person: photo_person)
      }.to change { photo.date_determinations.where(source_type: "age_estimate").count }.by(1)

      photo.reload
      determination = photo.date_determinations.where(source_type: "age_estimate").order(:id).last

      expect(determination.confidence).to eq(0.85)
      expect(determination.determined_year).to eq(1975)
      expect(determination.determined_month).to eq(6)
      expect(photo.best_date_determination_id).to eq(determination.id)
      expect(photo.determined_year).to eq(1975)
      expect(photo.determined_month).to eq(6)
    end

    it "keeps the highest-confidence determination when multiple determinations exist" do
      photo = create(:photo)

      low = create(:date_determination, photo: photo, source_type: "filename", determined_year: 1980, determined_month: nil, determined_day: nil, confidence: 0.6)
      high = create(:date_determination, photo: photo, source_type: "manual", determined_year: 1972, determined_month: nil, determined_day: nil, confidence: 0.9)
      create(:date_determination, photo: photo, source_type: "age_estimate", determined_year: 1978, determined_month: nil, determined_day: nil, confidence: 0.85)

      photo.reload

      expect(photo.date_determinations.count).to eq(3)
      expect(photo.best_date_determination_id).to eq(high.id)
      expect(photo.determined_year).to eq(1972)
      expect(photo.determined_date_text).to eq("1972")
      expect(low.confidence).to eq(0.6)
    end

    it "recalculates age determinations after DOB change and updates photo determined date" do
      person = create(:person, dob_year: 1950, date_of_birth: nil)
      photo = create(:photo, family: person.family)
      photo_person = create(:photo_person, photo: photo, person: person, estimated_age: 20)
      determination = Photo::DateDeterminationService.from_age_estimate(photo_person: photo_person)

      expect(determination.determined_year).to eq(1970)
      expect(photo.reload.determined_year).to eq(1970)

      person.update!(date_of_birth: Date.new(1955, 8, 15), dob_year: 1955)

      determination.reload
      photo.reload

      expect(determination.determined_year).to eq(1975)
      expect(determination.determined_month).to eq(8)
      expect(determination.confidence).to eq(0.85)
      expect(photo.determined_year).to eq(1975)
      expect(photo.determined_month).to eq(8)
      expect(photo.best_date_determination_id).to eq(determination.id)
    end

    it "does not create a determination when tagging person without DOB" do
      person = create(:person, dob_year: nil, date_of_birth: nil)
      photo = create(:photo, family: person.family)

      expect {
        create(:photo_person, photo: photo, person: person)
      }.to change(PhotoPerson, :count).by(1)
       .and change(DateDetermination, :count).by(0)

      expect(photo.reload.determined_year).to be_nil
    end

    it "does not create a determination when tagging with age but person has no DOB" do
      person = create(:person, dob_year: nil, date_of_birth: nil)
      photo = create(:photo, family: person.family)
      photo_person = create(:photo_person, photo: photo, person: person, estimated_age: 30)

      expect {
        result = Photo::DateDeterminationService.from_age_estimate(photo_person: photo_person)
        expect(result).to be_nil
      }.not_to change(DateDetermination, :count)

      expect(photo.reload.determined_year).to be_nil
    end

    it "creates two valid determinations when same person is tagged via photo_person and photo_face" do
      person = create(:person, dob_year: 1950, date_of_birth: Date.new(1950, 1, 1))
      photo = create(:photo, family: person.family)
      photo_person = create(:photo_person, photo: photo, person: person, estimated_age: 25)
      photo_face = create(:photo_face, photo: photo, person: person, estimated_age: 25)

      expect {
        Photo::DateDeterminationService.from_age_estimate(photo_person: photo_person)
        Photo::DateDeterminationService.from_age_estimate(photo_face: photo_face)
      }.to change { photo.date_determinations.where(source_type: "age_estimate").count }.by(2)

      determinations = photo.date_determinations.where(source_type: "age_estimate").order(:id)

      expect(determinations.map(&:determined_year)).to all(eq(1975))
      expect(determinations.map(&:confidence)).to all(eq(0.85))
      expect(determinations.map(&:photo_person_id).compact).to contain_exactly(photo_person.id)
      expect(determinations.map(&:photo_face_id).compact).to contain_exactly(photo_face.id)
      expect(photo.reload.determined_year).to eq(1975)
    end
  end
end
