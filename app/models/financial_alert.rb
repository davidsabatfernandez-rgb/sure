class FinancialAlert < ApplicationRecord
  belongs_to :family

  ALERT_TYPES = %w[budget_exceeded savings_goal loan_milestone inactivity].freeze
  SEVERITIES = %w[info warning success].freeze

  validates :alert_type, presence: true, inclusion: { in: ALERT_TYPES }
  validates :message, presence: true
  validates :severity, inclusion: { in: SEVERITIES }
  validates :date, presence: true

  scope :unread, -> { where(read: false) }
  scope :recent, -> { where("date >= ?", 30.days.ago.to_date).order(date: :desc) }

  def self.generate_daily!(family)
    check_budget_exceeded!(family)
    check_savings_milestones!(family)
    check_loan_milestones!(family)
  end

  def self.check_budget_exceeded!(family)
    today = Date.current
    month_start = today.beginning_of_month
    month_end = today.end_of_month

    family.categories.find_each do |category|
      # Calculate this month's spending for the category
      current_month_spent = Entry.joins(:account, :entryable)
                                  .where(accounts: { family_id: family.id })
                                  .where(entryable_type: "Transaction")
                                  .where(date: month_start..month_end)
                                  .joins("INNER JOIN transactions ON transactions.id = entries.entryable_id")
                                  .where(transactions: { category_id: category.id })
                                  .where("entries.amount > 0")
                                  .sum(:amount)

      next if current_month_spent.zero?

      # Calculate average of last 3 months
      three_months_ago = (today - 3.months).beginning_of_month
      last_month_end = (today - 1.month).end_of_month

      avg_spent = Entry.joins(:account, :entryable)
                       .where(accounts: { family_id: family.id })
                       .where(entryable_type: "Transaction")
                       .where(date: three_months_ago..last_month_end)
                       .joins("INNER JOIN transactions ON transactions.id = entries.entryable_id")
                       .where(transactions: { category_id: category.id })
                       .where("entries.amount > 0")
                       .sum(:amount) / 3.0

      next if avg_spent.zero?

      if current_month_spent > avg_spent
        existing = family.financial_alerts
                         .where(alert_type: "budget_exceeded", date: today)
                         .where("metadata->>'category_id' = ?", category.id.to_s)

        next if existing.exists?

        family.financial_alerts.create!(
          alert_type: "budget_exceeded",
          severity: "warning",
          date: today,
          message: "Spending in #{category.name} (#{current_month_spent.round(2)}) exceeds the 3-month average (#{avg_spent.round(2)})",
          metadata: { category_id: category.id, spent: current_month_spent, average: avg_spent }
        )
      end
    end
  end

  def self.check_savings_milestones!(family)
    today = Date.current
    milestones = [ 1000, 5000, 10_000, 25_000, 50_000, 100_000 ]

    family.accounts.where(accountable_type: "Depository").find_each do |account|
      balance = account.balance.to_f

      milestones.each do |milestone|
        next unless balance >= milestone

        existing = family.financial_alerts
                         .where(alert_type: "savings_goal")
                         .where("metadata->>'account_id' = ? AND metadata->>'milestone' = ?", account.id.to_s, milestone.to_s)

        next if existing.exists?

        family.financial_alerts.create!(
          alert_type: "savings_goal",
          severity: "success",
          date: today,
          message: "#{account.name} has reached #{milestone} #{family.currency}!",
          metadata: { account_id: account.id, milestone: milestone, balance: balance }
        )
      end
    end
  end

  def self.check_loan_milestones!(family)
    today = Date.current
    milestones = [ 50_000, 25_000, 10_000, 5000, 1000 ]

    family.accounts.where(accountable_type: "Loan").find_each do |account|
      balance = account.balance.to_f.abs

      milestones.each do |milestone|
        next unless balance <= milestone

        existing = family.financial_alerts
                         .where(alert_type: "loan_milestone")
                         .where("metadata->>'account_id' = ? AND metadata->>'milestone' = ?", account.id.to_s, milestone.to_s)

        next if existing.exists?

        family.financial_alerts.create!(
          alert_type: "loan_milestone",
          severity: "success",
          date: today,
          message: "#{account.name} balance has dropped below #{milestone} #{family.currency}!",
          metadata: { account_id: account.id, milestone: milestone, balance: balance }
        )
      end
    end
  end
end
