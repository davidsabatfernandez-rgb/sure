class PassiveIncomeCalculator
  attr_reader :family

  def initialize(family)
    @family = family
  end

  def total_monthly_passive_income
    property_income_total + remunerada_monthly_interest + dividend_monthly_estimate
  end

  def monthly_expenses
    avg = family.average_monthly_spending(3)
    avg > 0 ? avg : 1500.0
  end

  def property_sources
    @property_sources ||= begin
      family.accounts.active.where(accountable_type: "Property").includes(:accountable).filter_map do |account|
        prop = account.accountable
        renta = prop.renta_mensual || 0
        next if renta.zero?
        gastos_mensuales = (prop.gastos_anuales_alquiler || 0) / 12.0
        ocupacion = (prop.ocupacion_pct || 100) / 100.0
        {
          name: account.name, account: account,
          gross_monthly: renta,
          net_monthly: (renta - gastos_mensuales) * ocupacion,
          value: account.balance.to_f
        }
      end
    end
  end

  def property_income_total
    property_sources.sum { |s| s[:net_monthly] }
  end

  def remunerada_sources
    @remunerada_sources ||= begin
      family.accounts.active
        .where("name ILIKE '%remunerada%' OR (name ILIKE '%conjunta%' AND balance > 100)")
        .map do |account|
          balance = account.balance.to_f
          next if balance <= 0
          daily = balance * 0.02 / 365.0
          { name: account.name, account: account, balance: balance,
            annual_rate: 2.0, daily_interest: daily.round(4),
            monthly_interest: (daily * 30).round(2) }
        end.compact
    end
  end

  def remunerada_monthly_interest
    remunerada_sources.sum { |s| s[:monthly_interest] }
  end

  def dividend_sources
    @dividend_sources ||= begin
      family.entries
        .where(date: 12.months.ago.to_date..Date.current, entryable_type: "Transaction")
        .where("entries.name ILIKE '%dividend%' OR entries.name ILIKE '%dividendo%'")
        .group(:account_id).sum(:amount)
        .filter_map do |account_id, total|
          next if total.to_f.abs < 1
          account = family.accounts.find_by(id: account_id)
          next unless account
          { name: account.name, annual_amount: total.to_f.abs, monthly_amount: (total.to_f.abs / 12.0).round(2) }
        end
    rescue
      []
    end
  end

  def dividend_monthly_estimate
    dividend_sources.sum { |s| s[:monthly_amount] }
  end

  def coverage_pct
    return 0.0 if monthly_expenses.zero?
    (total_monthly_passive_income / monthly_expenses) * 100
  end

  def income_gap
    [monthly_expenses - total_monthly_passive_income, 0].max
  end

  def years_to_independence
    return 0 if income_gap.zero?
    target_capital = income_gap * 12 / 0.05
    current = family.accounts.active
      .where(accountable_type: %w[Investment Crypto Conjunta])
      .where("name NOT ILIKE '%santa elena%'")
      .sum(:balance).to_f
    remaining = [target_capital - current, 0].max
    return 0 if remaining.zero?
    r = 0.05 / 12.0
    n = Math.log(remaining * r / 4000.0 + 1) / Math.log(1 + r)
    (n / 12.0).ceil
  rescue
    99
  end

  def projected_with_iglesia
    future = total_monthly_passive_income + 2050
    { total: future, coverage_pct: monthly_expenses > 0 ? (future / monthly_expenses * 100).round(1) : 0 }
  end
end
