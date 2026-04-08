class PassiveIncomeController < ApplicationController
  def show
    @properties = Current.family.accounts.active.where(accountable_type: "Property").includes(:accountable)
    @rental_income = @properties.sum { |p| p.accountable.renta_mensual || 0 }

    # Interest from remuneradas (2% TIN daily)
    remuneradas = Current.family.accounts.active.where("name ILIKE '%remunerada%'")
    @interest_monthly = remuneradas.sum { |a| a.balance.to_f * 0.02 / 12 }

    @total_passive = @rental_income + @interest_monthly

    # Coverage: what % of expenses does passive income cover?
    @monthly_expenses = 1950.0 # estimated
    @coverage_pct = @monthly_expenses > 0 ? (@total_passive / @monthly_expenses * 100).round(1) : 0

    # Goal: how much passive income needed for financial independence
    @goal_monthly = @monthly_expenses
    @gap = [@goal_monthly - @total_passive, 0].max
  end
end
