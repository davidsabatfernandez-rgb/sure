class CreateFinancialAlerts < ActiveRecord::Migration[7.2]
  def change
    create_table :financial_alerts, id: :uuid do |t|
      t.references :family, type: :uuid, null: false, foreign_key: true
      t.string :alert_type, null: false
      t.string :message, null: false
      t.string :severity, default: "info"
      t.boolean :read, default: false
      t.date :date, null: false
      t.jsonb :metadata, default: {}
      t.timestamps
    end
  end
end
