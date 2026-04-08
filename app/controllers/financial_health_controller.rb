class FinancialHealthController < ApplicationController
  def show
    @calculator = FinancialHealthCalculator.new(Current.family)
    @score = @calculator.score
    @breakdown = @calculator.breakdown
    @recommendations = @calculator.recommendations
    @color = @calculator.color
  end
end
