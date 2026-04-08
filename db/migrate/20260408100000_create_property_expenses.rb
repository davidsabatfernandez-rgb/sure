class CreatePropertyExpenses < ActiveRecord::Migration[7.2]
  def change
    create_table :property_expenses, id: :uuid do |t|
      t.references :property, type: :uuid, null: false, foreign_key: true
      t.string :concepto, null: false
      t.decimal :importe, precision: 19, scale: 4, null: false
      t.string :tipo, null: false, default: "puntual" # "recurrente" | "puntual"
      t.string :frecuencia # "mensual" | "trimestral" | "anual" (solo recurrentes)
      t.string :categoria # "material" | "impuesto" | "arquitecta" | "paleta" | "otro" (solo puntuales)
      t.date :fecha
      t.text :notas
      t.timestamps
    end

    add_index :property_expenses, [:property_id, :tipo]
  end
end
