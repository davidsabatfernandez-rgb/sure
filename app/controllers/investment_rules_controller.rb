class InvestmentRulesController < ApplicationController
  before_action :set_investment_rule, only: %i[update destroy]

  def index
    @investment_rules = Current.family.investment_rules.active.includes(:category)
    @categories = Current.family.categories.alphabetically
    @investment_rule = Current.family.investment_rules.new
    @summary = InvestmentRule.monthly_summary(Current.family)
    @monthly_total = @summary.sum { |s| s[:to_invest] }
  end

  def create
    @investment_rule = Current.family.investment_rules.new(investment_rule_params)

    if @investment_rule.save
      redirect_to investment_rules_path, notice: t(".success")
    else
      @investment_rules = Current.family.investment_rules.active.includes(:category)
      @categories = Current.family.categories.alphabetically
      @summary = InvestmentRule.monthly_summary(Current.family)
      @monthly_total = @summary.sum { |s| s[:to_invest] }
      render :index, status: :unprocessable_entity
    end
  end

  def update
    if @investment_rule.update(investment_rule_params)
      redirect_to investment_rules_path, notice: t(".success")
    else
      redirect_to investment_rules_path, alert: t(".error")
    end
  end

  def destroy
    @investment_rule.destroy
    redirect_to investment_rules_path, notice: t(".success")
  end

  private

    def set_investment_rule
      @investment_rule = Current.family.investment_rules.find(params[:id])
    end

    def investment_rule_params
      params.require(:investment_rule).permit(:category_id, :percentage, :target_type, :active)
    end
end
