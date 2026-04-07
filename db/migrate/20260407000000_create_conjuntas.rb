class CreateConjuntas < ActiveRecord::Migration[7.2]
  def change
    create_table :conjuntas, id: :uuid do |t|
      t.jsonb :locked_attributes, default: {}
      t.string :subtype
      t.timestamps
    end
  end
end
