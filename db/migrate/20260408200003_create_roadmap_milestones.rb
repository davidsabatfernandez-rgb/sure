class CreateRoadmapMilestones < ActiveRecord::Migration[7.2]
  def change
    create_table :roadmap_milestones, id: :uuid do |t|
      t.references :family, type: :uuid, null: false, foreign_key: true
      t.string :nombre, null: false
      t.text :descripcion
      t.date :fecha_inicio, null: false
      t.date :fecha_objetivo, null: false
      t.decimal :monto_objetivo, precision: 19, scale: 4
      t.decimal :monto_actual, precision: 19, scale: 4, default: 0
      t.string :estado, default: "pendiente"
      t.string :color, default: "#3B82F6"
      t.integer :orden, default: 0
      t.timestamps
    end
  end
end
