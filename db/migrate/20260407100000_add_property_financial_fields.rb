class AddPropertyFinancialFields < ActiveRecord::Migration[7.2]
  def change
    add_column :properties, :gastos_compra, :decimal, precision: 19, scale: 4, default: 0
    add_column :properties, :valor_post_reforma, :decimal, precision: 19, scale: 4
    add_column :properties, :renta_mensual, :decimal, precision: 19, scale: 4, default: 0
    add_column :properties, :gastos_anuales_alquiler, :decimal, precision: 19, scale: 4, default: 0
    add_column :properties, :ocupacion_pct, :integer, default: 100
  end
end
