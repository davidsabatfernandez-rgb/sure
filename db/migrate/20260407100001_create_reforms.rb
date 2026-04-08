class CreateReforms < ActiveRecord::Migration[7.2]
  def change
    create_table :reforms, id: :uuid do |t|
      t.references :property, type: :uuid, null: false, foreign_key: true
      t.string :concepto, null: false
      t.decimal :importe, precision: 19, scale: 4, null: false
      t.date :fecha, null: false
      t.timestamps
    end
  end
end
