class ReplaceUploadPersonFieldsWithReferences < ActiveRecord::Migration[8.1]
  def change
    remove_column :uploads, :source_owner, :string
    remove_column :uploads, :scanned_by, :string
    add_reference :uploads, :source_owner, foreign_key: { to_table: :people }, null: true
    add_reference :uploads, :scanned_by_person, foreign_key: { to_table: :people }, null: true
  end
end
