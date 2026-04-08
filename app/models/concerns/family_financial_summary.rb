module FamilyFinancialSummary
  extend ActiveSupport::Concern

  # Categories that are transfers between accounts, not real expenses
  TRANSFER_CATEGORIES = ["Services", "Savings & Investments"].freeze

  def spending_entries_for(start_date, end_date)
    transfer_cat_ids = categories.where(name: TRANSFER_CATEGORIES).pluck(:id)

    scope = entries
      .where(entryable_type: "Transaction", date: start_date..end_date)
      .where("entries.excluded IS NOT TRUE")
      .where("entries.amount < 5000") # large transfers

    if transfer_cat_ids.any?
      scope = scope.joins("INNER JOIN transactions ON transactions.id = entries.entryable_id AND entries.entryable_type = 'Transaction'")
                   .where("transactions.category_id IS NULL OR transactions.category_id NOT IN (?)", transfer_cat_ids)
    end

    scope
  end

  def today_spending
    spending_entries_for(Date.current, Date.current)
      .where("entries.amount > 0")
      .sum("entries.amount").to_f
  end

  def month_spending(date = Date.current)
    spending_entries_for(date.beginning_of_month, date)
      .where("entries.amount > 0")
      .sum("entries.amount").to_f
  end

  def month_income(date = Date.current)
    entries.where(date: date.beginning_of_month..date, entryable_type: "Transaction")
           .where("entries.amount < 0")
           .where("entries.name ILIKE '%nomina%' OR entries.name ILIKE '%level%' OR entries.name ILIKE '%iberia%'")
           .sum("ABS(entries.amount)").to_f
  end

  def month_savings(date = Date.current)
    month_income(date) - month_spending(date)
  end

  def week_spending(date = Date.current)
    spending_entries_for(date.beginning_of_week, date)
      .where("entries.amount > 0")
      .sum("entries.amount").to_f
  end

  def last_week_spending
    last_monday = 1.week.ago.to_date.beginning_of_week
    spending_entries_for(last_monday, last_monday + 6.days)
      .where("entries.amount > 0")
      .sum("entries.amount").to_f
  end

  def top_expense_categories(start_date, end_date, limit = 5)
    transfer_cat_ids = categories.where(name: TRANSFER_CATEGORIES).pluck(:id)

    scope = entries
      .joins("INNER JOIN transactions ON transactions.id = entries.entryable_id AND entries.entryable_type = 'Transaction'")
      .joins("LEFT JOIN categories ON categories.id = transactions.category_id")
      .where(entryable_type: "Transaction", date: start_date..end_date)
      .where("entries.amount > 0 AND entries.amount < 5000")
      .where("entries.excluded IS NOT TRUE")

    scope = scope.where("transactions.category_id IS NULL OR transactions.category_id NOT IN (?)", transfer_cat_ids) if transfer_cat_ids.any?

    scope.group("categories.name, categories.color")
         .order(Arel.sql("SUM(entries.amount) DESC"))
         .limit(limit)
         .pluck(Arel.sql("COALESCE(categories.name, 'Sin categoría')"), "categories.color", Arel.sql("SUM(entries.amount)"))
         .map { |name, color, total| { name: name, color: color || "#9E9E9E", total: total.to_f.round(2) } }
  end

  def average_monthly_spending(months = 3)
    start_date = months.months.ago.to_date.beginning_of_month
    end_date = 1.month.ago.to_date.end_of_month
    total = spending_entries_for(start_date, end_date)
              .where("entries.amount > 0")
              .sum("entries.amount").to_f
    months > 0 ? total / months : 0
  end
end
