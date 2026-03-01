class PeopleController < ApplicationController
  before_action :set_person, only: [ :show, :edit, :update, :destroy ]

  def index
    @people = current_family.people.alphabetical
  end

  def search
    @people = current_family.people
      .where("first_name ILIKE :q OR last_name ILIKE :q OR CONCAT(first_name, ' ', last_name) ILIKE :q", q: "%#{params[:q]}%")
      .alphabetical
      .limit(10)
    render json: @people.map { |p| { id: p.id, name: p.full_name } }
  end

  def show
    @photos = @person.photos.recent
  end

  def new
    @person = current_family.people.build
  end

  def create
    @person = current_family.people.build(person_params)

    respond_to do |format|
      if @person.save
        format.html { redirect_to @person, notice: "Person added successfully." }
        format.json { render json: { id: @person.id, name: @person.full_name }, status: :created }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { errors: @person.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def update
    if @person.update(person_params)
      redirect_to @person, notice: "Person updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @person.destroy
    redirect_to people_path, notice: "Person removed."
  end

  private

  def set_person
    @person = current_family.people.find(params[:id])
  end

  def person_params
    params.expect(person: [ :first_name, :last_name, :maiden_name, :date_of_birth, :date_of_death, :bio ])
  end
end
