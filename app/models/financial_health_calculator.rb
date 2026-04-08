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
      debt_ratio: { score: debt_ratio_score, weight: WEIGHTS[:debt_ratio], label: "Ratio deuda/activos", detail: debt_ratio_detail },
      savings_rate: { score: savings_rate_score, weight: WEIGHTS[:savings_rate], label: "Tasa de ahorro", detail: savings_rate_detail },
      emergency_fund: { score: emergency_fund_score, weight: WEIGHTS[:emergency_fund], label: "Fondo de emergencia", detail: emergency_fund_detail },
      diversification: { score: diversification_score, weight: WEIGHTS[:diversification], label: "Diversificación", detail: diversification_detail },
      debt_cost: { score: debt_cost_score, weight: WEIGHTS[:debt_cost], label: "Coste de deuda", detail: debt_cost_detail }
    }
  end

  def recommendations
    recs = []
    b = breakdown

    recs << "Reduce tu deuda para mejorar el ratio deuda/activos" if b[:debt_ratio][:score] < 70
    recs << "Intenta ahorrar más del 30% de tus ingresos" if b[:savings_rate][:score] < 60
    recs << "Aumenta tu fondo de emergencia a 6 meses de gastos" if b[:emergency_fund][:score] < 70
    recs << "Diversifica más: no pongas todo en inmuebles" if b[:diversification][:score] < 60
    recs << "Prioriza pagar las deudas con tipo de interés más alto" if b[:debt_cost][:score] < 50

    recs << "Tu salud financiera es excelente, sigue así" if score >= 80
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
      val.respond_to?(:amount) ? val.amount.to_f : val.to_f
    end
  end

  def liabilities_total
    @liabilities_total ||= begin
      val = @balance_sheet.liabilities.total
      val.respond_to?(:amount) ? val.amount.to_f.abs : val.to_f.abs
    end
  end

  def debt_ratio_score
    return 100 if assets_total <= 0
    ratio = liabilities_total / assets_total * 100
    case ratio
    when 0..10 then 100
    when 10..20 then 80
    when 20..30 then 60
    when 30..40 then 40
    when 40..50 then 20
    else 0
    end
  end

  def debt_ratio_detail
    return "Sin activos" if assets_total <= 0
    ratio = (liabilities_total / assets_total * 100).round(1)
    "#{ratio}% de tus activos son deuda"
  end

  def savings_rate_score
    # Estimated: 2800 savings / 4750 income = 59%
    rate = 59
    case rate
    when 50..100 then 100
    when 40..49 then 85
    when 30..39 then 70
    when 20..29 then 50
    when 10..19 then 30
    else 10
    end
  end

  def savings_rate_detail
    "Ahorras ~59% de tus ingresos (2.800€ de ~4.750€)"
  end

  def emergency_fund_score
    liquid = family.accounts.active
      .where(accountable_type: %w[Depository Investment Conjunta])
      .where("name ILIKE '%remunerada%' OR name ILIKE '%conjunta%' OR name ILIKE '%sabadell%' OR name ILIKE '%rev card%'")
      .sum(:balance).to_f

    # Assume monthly expenses ~1950€ (4750 - 2800)
    months_covered = liquid / 1950.0
    case months_covered
    when 6.. then 100
    when 4..5.99 then 75
    when 3..3.99 then 55
    when 1..2.99 then 35
    else 10
    end
  end

  def emergency_fund_detail
    liquid = family.accounts.active
      .where(accountable_type: %w[Depository Investment Conjunta])
      .where("name ILIKE '%remunerada%' OR name ILIKE '%conjunta%' OR name ILIKE '%sabadell%' OR name ILIKE '%rev card%'")
      .sum(:balance).to_f
    months = (liquid / 1950.0).round(1)
    "#{months} meses de gastos cubiertos (#{liquid.round(0)}€ líquidos)"
  end

  def diversification_score
    types = family.accounts.active.distinct.pluck(:accountable_type).count
    case types
    when 5.. then 100
    when 4 then 80
    when 3 then 60
    when 2 then 40
    else 20
    end
  end

  def diversification_detail
    types = family.accounts.active.distinct.pluck(:accountable_type)
    "#{types.count} tipos de activos: #{types.join(', ')}"
  end

  def debt_cost_score
    loans = family.accounts.active.where(accountable_type: "Loan")
    return 100 if loans.empty?

    total_debt = 0.0
    weighted_rate = 0.0
    loans.each do |loan|
      bal = loan.balance.to_f.abs
      rate = loan.accountable&.interest_rate || 0
      total_debt += bal
      weighted_rate += bal * rate
    end

    return 100 if total_debt <= 0
    avg_rate = weighted_rate / total_debt

    case avg_rate
    when 0..2 then 100
    when 2..3 then 85
    when 3..4 then 70
    when 4..5 then 55
    when 5..6 then 40
    when 6..8 then 25
    else 10
    end
  end

  def debt_cost_detail
    loans = family.accounts.active.where(accountable_type: "Loan").includes(:accountable)
    return "Sin deudas" if loans.empty?
    loans.map { |l| "#{l.name}: #{l.accountable&.interest_rate || '?'}%" }.join(", ")
  end
end
