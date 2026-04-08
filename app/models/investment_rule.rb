class InvestmentRule < ApplicationRecord
  belongs_to :family
  belongs_to :category

  TARGET_TYPES = %w[savings crypto stocks].freeze

  validates :percentage, presence: true, inclusion: { in: 1..100 }
  validates :target_type, inclusion: { in: TARGET_TYPES }
  validates :category_id, uniqueness: { scope: :family_id }

  scope :active, -> { where(active: true) }

  def calculate_monthly(date = Date.current)
    month_start = date.beginning_of_month
    month_end = date.end_of_month

    spent = Entry.joins(:account, :entryable)
                 .where(accounts: { family_id: family_id })
                 .where(entryable_type: "Transaction")
                 .where(date: month_start..month_end)
                 .joins("INNER JOIN transactions ON transactions.id = entries.entryable_id")
                 .where(transactions: { category_id: category_id })
                 .where("entries.amount > 0") # expenses are positive amounts
                 .sum(:amount)

    (spent * percentage / 100.0).round(2)
  end

  def self.monthly_summary(family, date = Date.current)
    family.investment_rules.active.includes(:category).map do |rule|
      spent = rule.calculate_monthly(date)
      to_invest = (spent * rule.percentage / 100.0).round(2)

      {
        category_name: rule.category.name,
        spent: spent,
        percentage: rule.percentage,
        to_invest: to_invest,
        target_type: rule.target_type
      }
    end
  end
end
