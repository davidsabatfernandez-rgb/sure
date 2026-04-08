class CreatePropertyScenarios < ActiveRecord::Migration[7.2]
  def change
    create_table :property_scenarios, id: :uuid do |t|
      t.references :property, type: :uuid, null: false, foreign_key: true
      t.string :nombre, null: false
      t.decimal :precio_compra, precision: 19, scale: 4, default: 0
      t.decimal :gastos_compra, precision: 19, scale: 4, default: 0
      t.decimal :reformas_estimadas, precision: 19, scale: 4, default: 0
      t.decimal :valor_estimado_post, precision: 19, scale: 4, default: 0
      t.decimal :renta_mensual_estimada, precision: 19, scale: 4, default: 0
      t.decimal :gastos_anuales_estimados, precision: 19, scale: 4, default: 0
      t.integer :ocupacion_pct, default: 100
      t.text :notas
      t.timestamps
    end
  end
end
