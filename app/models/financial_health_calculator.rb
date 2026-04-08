class FinancialHealthCalculator
  WEIGHTS = {
    debt_ratio: 25,
    savings_rate: 25,
    emergency_fund: 20,
    diversification: 15,
    debt_cost: 15
  }.freeze

  attr_reader :family

  def initialize(family)
    @family = family
    @balance_sheet = BalanceSheet.new(family)
  end

  def score
    breakdown.sum { |_, data| data[:score] * data[:weight] / 100.0 }.round(0)
  end

  def breakdown
    {
      debt_ratio: { score: debt_ratio_score, weight: 25, label: "Ratio deuda/activos", detail: debt_ratio_detail },
      savings_rate: { score: savings_rate_score, weight: 25, label: "Tasa de ahorro", detail: savings_rate_detail },
      emergency_fund: { score: emergency_fund_score, weight: 20, label: "Fondo de emergencia", detail: emergency_fund_detail },
      diversification: { score: diversification_score, weight: 15, label: "Diversificación", detail: diversification_detail },
      debt_cost: { score: debt_cost_score, weight: 15, label: "Coste de deuda", detail: debt_cost_detail }
    }
  end

  def recommendations
    recs = []
    b = breakdown

    # Specific actionable advice based on real data
    if highest_rate_loan
      recs << "Prioriza liquidar #{highest_rate_loan[:name]} (#{highest_rate_loan[:rate]}%) - es tu deuda más cara"
    end

    recs << "Aumenta tu fondo de emergencia a 6 meses de gastos" if b[:emergency_fund][:score] < 70

    if b[:savings_rate][:score] >= 80
      recs << "Tu tasa de ahorro es excelente - destina el excedente a inversiones productivas"
    end

    recs << "Diversifica más allá de inmuebles - considera fondos indexados para el largo plazo" if b[:diversification][:score] < 60

    recs << "Tu salud financiera es excelente. Mantén el rumbo." if score >= 80
    recs
  end

  def color
    case score
    when 70..100 then "#12B76A"
    when 40..69 then "#F79009"
    else "#F13636"
    end
  end

  private

  def assets_total
    @assets_total ||= begin
      val = @balance_sheet.assets.total
      (val.respond_to?(:amount) ? val.amount : val).to_f
    end
  end

  def liabilities_total
    @liabilities_total ||= begin
      val = @balance_sheet.liabilities.total
      (val.respond_to?(:amount) ? val.amount : val).to_f.abs
    end
  end

  def real_monthly_spending
    @real_monthly_spending ||= family.average_monthly_spending(3)
  end

  def real_monthly_income
    # Use last month's income as reference
    @real_monthly_income ||= family.month_income(1.month.ago.to_date)
  end

  def liquid_accounts_total
    @liquid_accounts_total ||= family.accounts.active
      .where(accountable_type: %w[Depository Investment Conjunta])
      .where("name NOT ILIKE '%santa elena%' AND name NOT ILIKE '%mama%' AND name NOT ILIKE '%caixa%'")
      .sum(:balance).to_f
  end

  def loan_accounts
    @loan_accounts ||= family.accounts.active.where(accountable_type: "Loan").includes(:accountable)
  end

  def highest_rate_loan
    @highest_rate_loan ||= begin
      loans = loan_accounts.map { |l| { name: l.name, rate: l.accountable&.interest_rate || 0, balance: l.balance.to_f.abs } }
      loans.max_by { |l| l[:rate] }
    end
  end

  def debt_ratio_score
    return 100 if assets_total <= 0
    # Exclude father's account from ratio (157k is not David's money)
    real_assets = assets_total - 157916.0
    return 100 if real_assets <= 0
    ratio = liabilities_total / real_assets * 100
    [[100 - (ratio * 2), 0].max, 100].min.round(0)
  end

  def debt_ratio_detail
    real_assets = assets_total - 157916.0
    ratio = real_assets > 0 ? (liabilities_total / real_assets * 100).round(1) : 0
    "#{ratio}% - Deuda: #{format_eur(liabilities_total)} vs Activos propios: #{format_eur(real_assets)}"
  end

  def savings_rate_score
    return 50 if real_monthly_income <= 0
    rate = ((real_monthly_income - real_monthly_spending) / real_monthly_income * 100)
    [[rate * 2, 0].max, 100].min.round(0)
  end

  def savings_rate_detail
    if real_monthly_income > 0
      rate = ((real_monthly_income - real_monthly_spending) / real_monthly_income * 100).round(1)
      "#{rate}% - Ingresas #{format_eur(real_monthly_income)}, gastas #{format_eur(real_monthly_spending)}"
    else
      "Sin datos de ingresos suficientes"
    end
  end

  def emergency_fund_score
    return 0 if real_monthly_spending <= 0
    months = liquid_accounts_total / real_monthly_spending
    [[months * 16.7, 0].max, 100].min.round(0) # 6 months = 100
  end

  def emergency_fund_detail
    months = real_monthly_spending > 0 ? (liquid_accounts_total / real_monthly_spending).round(1) : 0
    "#{months} meses cubiertos (#{format_eur(liquid_accounts_total)} líquidos)"
  end

  def diversification_score
    types = family.accounts.active
      .where("name NOT ILIKE '%santa elena%' AND name NOT ILIKE '%mama%'")
      .distinct.pluck(:accountable_type).count
    [[types * 20, 0].max, 100].min
  end

  def diversification_detail
    types = family.accounts.active
      .where("name NOT ILIKE '%santa elena%' AND name NOT ILIKE '%mama%'")
      .distinct.pluck(:accountable_type)
    "#{types.count} tipos: #{types.join(', ')}"
  end

  def debt_cost_score
    return 100 if loan_accounts.empty?
    total_debt = 0.0
    weighted_rate = 0.0
    loan_accounts.each do |l|
      bal = l.balance.to_f.abs
      rate = l.accountable&.interest_rate || 0
      total_debt += bal
      weighted_rate += bal * rate
    end
    return 100 if total_debt <= 0
    avg = weighted_rate / total_debt
    [[100 - (avg * 12.5), 0].max, 100].min.round(0) # 8% = 0
  end

  def debt_cost_detail
    return "Sin deudas" if loan_accounts.empty?
    loan_accounts.map { |l| "#{l.name}: #{l.accountable&.interest_rate || '?'}%" }.join(", ")
  end

  def format_eur(amount)
    ActiveSupport::NumberHelper.number_to_currency(amount, unit: "", delimiter: ".", separator: ",", precision: 0) + "€"
  end
end
