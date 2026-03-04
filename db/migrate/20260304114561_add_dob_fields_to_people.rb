class AddDobFieldsToPeople < ActiveRecord::Migration[8.1]
  def change
    add_column :people, :dob_year, :integer
    add_column :people, :dob_circa, :boolean, default: false
  end
end
