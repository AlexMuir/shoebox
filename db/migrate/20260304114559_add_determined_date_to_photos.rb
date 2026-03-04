class AddDeterminedDateToPhotos < ActiveRecord::Migration[8.1]
  def change
    add_column :photos, :determined_year, :integer
    add_column :photos, :determined_month, :integer
    add_column :photos, :determined_day, :integer
    add_reference :photos, :best_date_determination, foreign_key: { to_table: :date_determinations }
  end
end
