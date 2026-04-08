class CreateNetWorthSnapshots < ActiveRecord::Migration[7.2]
  def change
    create_table :net_worth_snapshots, id: :uuid do |t|
      t.references :family, type: :uuid, null: false, foreign_key: true
      t.date :fecha, null: false
      t.decimal :activos, precision: 19, scale: 4, null: false
      t.decimal :pasivos, precision: 19, scale: 4, null: false
      t.decimal :patrimonio_neto, precision: 19, scale: 4, null: false
      t.jsonb :desglose, default: {}
      t.timestamps
    end

    add_index :net_worth_snapshots, [:family_id, :fecha], unique: true
  end
end
