module FamilyFinancialSummary
  extend ActiveSupport::Concern

  DEFAULT_MONTHLY_BUDGET = 3000
  DEFAULT_SAVINGS_GOAL = 2800

  # Sum of today's expense transactions (positive amounts = expenses)
  def today_spending(user: Current.user)
    expense_entries_for(user: user)
      .where(date: Date.current)
      .sum(:amount)
  end

  # Sum of this month's expense transactions
  def month_spending(user: Current.user)
    expense_entries_for(user: user)
      .where(date: current_month_range)
      .sum(:amount)
  end

  # Sum of this month's income (negative amounts = income)
  def month_income(user: Current.user)
    income_entries_for(user: user)
      .where(date: current_month_range)
      .sum(:amount)
      .abs
  end

  # Income minus expenses this month
  def month_savings(user: Current.user)
    income = month_income(user: user)
    expenses = month_spending(user: user)
    income - expenses
  end

  # Week spending (Monday to Sunday)
  def week_spending(user: Current.user, week_start: Date.current.beginning_of_week)
    week_end = week_start.end_of_week
    expense_entries_for(user: user)
      .where(date: week_start..week_end)
      .sum(:amount)
  end

  # Top N expense categories for a date range
  def top_expense_categories(user: Current.user, date_range: current_week_range, limit: 3)
    account_ids = accounts_for_user(user).pluck(:id)

    Entry.where(account_id: account_ids, entryable_type: "Transaction")
         .where(excluded: false)
         .where("amount > 0")
         .where(date: date_range)
         .joins("INNER JOIN transactions ON transactions.id = entries.entryable_id")
         .joins("LEFT JOIN categories ON categories.id = transactions.category_id")
         .group("categories.id", "categories.name", "categories.color", "categories.lucide_icon")
         .order(Arel.sql("SUM(entries.amount) DESC"))
         .limit(limit)
         .pluck(
           Arel.sql("categories.name"),
           Arel.sql("categories.color"),
           Arel.sql("categories.lucide_icon"),
           Arel.sql("SUM(entries.amount)")
         )
         .map do |name, color, icon, total|
           {
             name: name || "Sin categoría",
             color: color || "#6b7280",
             icon: icon || "circle",
             total: total.to_f
           }
         end
  end

  # Last week's spending for comparison
  def last_week_spending(user: Current.user)
    last_week_start = 1.week.ago.to_date.beginning_of_week
    week_spending(user: user, week_start: last_week_start)
  end

  private

  def accounts_for_user(user)
    user ? user.accessible_accounts.visible : accounts.visible
  end

  def expense_entries_for(user: Current.user)
    account_ids = accounts_for_user(user).pluck(:id)

    Entry.where(account_id: account_ids, entryable_type: "Transaction")
         .where(excluded: false)
         .where("amount > 0")
  end

  def income_entries_for(user: Current.user)
    account_ids = accounts_for_user(user).pluck(:id)

    Entry.where(account_id: account_ids, entryable_type: "Transaction")
         .where(excluded: false)
         .where("amount < 0")
  end

  def current_month_range
    if uses_custom_month_start?
      start_date = custom_month_start_for(Date.current)
      end_date = custom_month_end_for(Date.current)
      start_date..end_date
    else
      Date.current.beginning_of_month..Date.current.end_of_month
    end
  end

  def current_week_range
    Date.current.beginning_of_week..Date.current.end_of_week
  end
end
