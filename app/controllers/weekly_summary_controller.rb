class WeeklySummaryController < ApplicationController
  def show
    family = Current.family

    @week_spending = family.week_spending
    @last_week_spending = family.last_week_spending
    @top_categories = family.top_expense_categories(limit: 3)
    @month_savings = family.month_savings
    @month_income = family.month_income
    @month_spending = family.month_spending

    @spending_diff = @week_spending - @last_week_spending
    @spending_diff_pct = @last_week_spending.zero? ? 0 : ((@spending_diff / @last_week_spending.to_f) * 100).round(1)

    # Motivational: estimate months to pay off car loan (e.g. 15000 remaining)
    @car_remaining = 15_000
    @monthly_savings_rate = @month_savings > 0 ? @month_savings : 0
    @months_to_payoff = @monthly_savings_rate > 0 ? (@car_remaining / @monthly_savings_rate.to_f).ceil : nil

    @savings_goal = FamilyFinancialSummary::DEFAULT_SAVINGS_GOAL
    @savings_pct = @savings_goal.zero? ? 0 : [(@month_savings / @savings_goal.to_f * 100).clamp(0, 100).round, 100].min

    @breadcrumbs = [ [ "Home", root_path ], [ "Resumen semanal", nil ] ]
  end
end
