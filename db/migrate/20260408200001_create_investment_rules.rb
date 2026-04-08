class CreateInvestmentRules < ActiveRecord::Migration[7.2]
  def change
    create_table :investment_rules, id: :uuid do |t|
      t.references :family, type: :uuid, null: false, foreign_key: true
      t.references :category, type: :uuid, null: false, foreign_key: true
      t.integer :percentage, null: false, default: 10
      t.string :target_type, default: "savings"
      t.boolean :active, default: true
      t.timestamps
    end
  end
end
