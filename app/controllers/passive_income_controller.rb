class PassiveIncomeController < ApplicationController
  def show
    @calc = PassiveIncomeCalculator.new(Current.family)
    @total_passive = @calc.total_monthly_passive_income
    @coverage_pct = @calc.coverage_pct.round(1)
    @gap = @calc.income_gap
    @years_to_fi = @calc.years_to_independence
    @property_sources = @calc.property_sources
    @remunerada_sources = @calc.remunerada_sources
    @dividend_sources = @calc.dividend_sources
    @monthly_expenses = @calc.monthly_expenses
  end
end
