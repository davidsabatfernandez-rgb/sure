class Loan < ApplicationRecord
  include Accountable

  SUBTYPES = {
    "mortgage" => { short: "Mortgage", long: "Mortgage" },
    "student" => { short: "Student", long: "Student Loan" },
    "auto" => { short: "Auto", long: "Auto Loan" },
    "other" => { short: "Other", long: "Other Loan" }
  }.freeze

  def monthly_payment
    return nil if term_months.nil? || interest_rate.nil? || rate_type.nil? || rate_type != "fixed"
    return Money.new(0, account.currency) if account.loan.original_balance.amount.zero? || term_months.zero?

    annual_rate = interest_rate / 100.0
    monthly_rate = annual_rate / 12.0

    if monthly_rate.zero?
      payment = account.loan.original_balance.amount / term_months
    else
      payment = (account.loan.original_balance.amount * monthly_rate * (1 + monthly_rate)**term_months) / ((1 + monthly_rate)**term_months - 1)
    end

    Money.new(payment.round, account.currency)
  end

  def original_balance
    Money.new(account.first_valuation_amount, account.currency)
  end

  # Amortization schedule: returns array of monthly breakdowns
  # Each entry: { month:, cuota:, capital:, intereses:, pendiente: }
  def amortization_schedule(capital: nil, cuota_extra: 0)
    cap = capital || account.balance.to_f.abs
    return [] if cap <= 0 || interest_rate.nil? || interest_rate.zero?

    r = interest_rate / 100.0 / 12.0
    remaining = cap
    cuota_base = monthly_payment_amount(cap)
    cuota_total = cuota_base + cuota_extra
    schedule = []
    month = 0

    while remaining > 0.01 && month < 600 # max 50 years safety
      month += 1
      interes_mes = remaining * r
      capital_mes = [cuota_total - interes_mes, remaining].min
      remaining -= capital_mes

      schedule << {
        month: month,
        cuota: (capital_mes + interes_mes).round(2),
        capital: capital_mes.round(2),
        intereses: interes_mes.round(2),
        pendiente: [remaining, 0].max.round(2)
      }

      break if remaining <= 0.01
    end

    schedule
  end

  def total_intereses_restantes
    amortization_schedule.sum { |m| m[:intereses] }
  end

  def fecha_liquidacion
    meses = amortization_schedule.size
    return nil if meses.zero?
    Date.current + meses.months
  end

  def porcentaje_amortizado
    return 0 if initial_balance.nil? || initial_balance.zero?
    paid = initial_balance - account.balance.to_f.abs
    (paid / initial_balance * 100).round(1)
  end

  def coste_total
    return 0 if initial_balance.nil?
    initial_balance + total_intereses_restantes
  end

  # Current month breakdown
  def current_month_breakdown
    schedule = amortization_schedule
    return nil if schedule.empty?
    first = schedule.first
    {
      cuota: first[:cuota],
      capital: first[:capital],
      intereses: first[:intereses],
      capital_pct: ((first[:capital] / first[:cuota]) * 100).round(1),
      intereses_pct: ((first[:intereses] / first[:cuota]) * 100).round(1)
    }
  end

  # How much interest you've already paid (estimated)
  def intereses_ya_pagados
    return 0 if initial_balance.nil? || interest_rate.nil?
    total_paid = initial_balance - account.balance.to_f.abs
    # Rough estimate: total payments made - capital repaid
    months_elapsed = ((Date.current - (account.entries.valuations.order(:date).first&.date || Date.current)) / 30.0).round
    return 0 if months_elapsed <= 0
    cuota = monthly_payment_amount(initial_balance)
    total_payments = cuota * months_elapsed
    total_payments - total_paid
  end

  # Full loan timeline data
  def full_timeline
    return [] if initial_balance.nil? || interest_rate.nil?
    # Generate schedule from the ORIGINAL balance
    r = interest_rate / 100.0 / 12.0
    n = term_months || 360
    cap = initial_balance.to_f
    return [] if cap <= 0 || r <= 0

    cuota = (cap * r * (1 + r)**n) / ((1 + r)**n - 1)
    remaining = cap
    timeline = []
    month = 0

    while remaining > 0.01 && month < 600
      month += 1
      int_mes = remaining * r
      cap_mes = [cuota - int_mes, remaining].min
      remaining -= cap_mes
      timeline << {
        month: month,
        capital: cap_mes.round(2),
        intereses: int_mes.round(2),
        pendiente: [remaining, 0].max.round(2)
      }
      break if remaining <= 0.01
    end

    timeline
  end

  # Simulate early repayment or increased payment
  def simulate(amortizacion_anticipada: 0, cuota_extra: 0)
    capital_actual = account.balance.to_f.abs
    capital_simulado = capital_actual - amortizacion_anticipada

    schedule_actual = amortization_schedule
    schedule_simulado = amortization_schedule(capital: capital_simulado, cuota_extra: cuota_extra)

    meses_actual = schedule_actual.size
    meses_simulado = schedule_simulado.size
    intereses_actual = schedule_actual.sum { |m| m[:intereses] }
    intereses_simulado = schedule_simulado.sum { |m| m[:intereses] }

    {
      meses_ahorrados: meses_actual - meses_simulado,
      intereses_ahorrados: (intereses_actual - intereses_simulado).round(2),
      nueva_fecha_liquidacion: Date.current + meses_simulado.months,
      schedule_actual: schedule_actual,
      schedule_simulado: schedule_simulado
    }
  end

  # Smart amortization analysis comparing loan cost vs investment returns
  def amortization_analysis(family)
    return nil if interest_rate.nil?

    # Gather family financial context
    all_accounts = family.accounts.active
    loans = all_accounts.where(accountable_type: "Loan").includes(:accountable)
    investments = all_accounts.where(accountable_type: %w[Investment Conjunta])

    # Known return rates
    savings_rate = 2.0 # Remuneradas TIN
    loan_rate = interest_rate

    schedule = amortization_schedule
    return nil if schedule.empty?

    # Find the crossover point: where monthly interest < what you'd earn investing
    crossover_month = nil
    schedule.each do |month|
      monthly_investment_return = month[:pendiente] * (savings_rate / 100.0 / 12.0)
      if month[:intereses] < monthly_investment_return
        crossover_month = month[:month]
        break
      end
    end

    # Calculate total interest by year blocks
    interest_by_year = schedule.each_slice(12).map.with_index do |year_months, i|
      total_interest = year_months.sum { |m| m[:intereses] }
      total_capital = year_months.sum { |m| m[:capital] }
      last_pending = year_months.last&.dig(:pendiente) || 0
      {
        year: i + 1,
        total_interest: total_interest.round(2),
        total_capital: total_capital.round(2),
        pending: last_pending.round(2),
        interest_pct: (total_interest + total_capital) > 0 ? (total_interest / (total_interest + total_capital) * 100).round(1) : 0
      }
    end

    # Opportunity cost: if you put X euros to amortize vs invest at savings_rate
    amounts_to_test = [5000, 10000, 20000, 50000].select { |a| a <= account.balance.to_f.abs * 0.8 }
    opportunity_analysis = amounts_to_test.map do |amount|
      sim = simulate(amortizacion_anticipada: amount)
      interest_saved = sim[:intereses_ahorrados]
      # What would that money earn in savings over the remaining loan period?
      months_remaining = schedule.size
      investment_earned = amount * (savings_rate / 100.0) * (months_remaining / 12.0)

      {
        amount: amount,
        interest_saved: interest_saved,
        investment_earned: investment_earned.round(2),
        net_benefit: (interest_saved - investment_earned).round(2),
        months_saved: sim[:meses_ahorrados],
        recommendation: interest_saved > investment_earned ? "amortizar" : "invertir"
      }
    end

    # Build AI context summary
    other_loans = loans.reject { |l| l.id == account.id }.map do |l|
      { name: l.name, balance: l.balance.to_f.abs, rate: l.accountable.interest_rate }
    end

    {
      loan_rate: loan_rate,
      savings_rate: savings_rate,
      capital_pendiente: account.balance.to_f.abs,
      crossover_month: crossover_month,
      interest_by_year: interest_by_year,
      opportunity_analysis: opportunity_analysis,
      other_loans: other_loans,
      total_liquid: investments.sum(:balance).to_f,
      recommendation_summary: build_recommendation(loan_rate, savings_rate, opportunity_analysis, other_loans)
    }
  end

  private
    def build_recommendation(loan_rate, savings_rate, opportunity, other_loans)
      lines = []

      # Compare rates
      if loan_rate > savings_rate
        lines << "Tu préstamo cobra #{loan_rate}% vs tus ahorros que rinden #{savings_rate}%. Amortizar tiene sentido financiero."
      else
        lines << "Tu préstamo cobra #{loan_rate}% y tus ahorros rinden #{savings_rate}%. Matemáticamente es mejor invertir que amortizar."
      end

      # Check if there are higher-rate loans
      higher_rate_loans = other_loans.select { |l| l[:rate] && l[:rate] > loan_rate }
      if higher_rate_loans.any?
        names = higher_rate_loans.map { |l| "#{l[:name]} (#{l[:rate]}%)" }.join(", ")
        lines << "Prioridad: amortizar primero #{names} que tienen tipo más alto."
      end

      # Best opportunity
      best = opportunity.max_by { |o| o[:net_benefit] }
      if best
        if best[:recommendation] == "amortizar"
          lines << "Amortizar #{best[:amount].to_i}€ te ahorraría #{best[:interest_saved].round(0)}€ en intereses (#{best[:months_saved]} meses menos)."
        else
          lines << "Invertir #{best[:amount].to_i}€ al #{savings_rate}% generaría #{best[:investment_earned].round(0)}€, más que los #{best[:interest_saved].round(0)}€ que ahorrarías amortizando."
        end
      end

      lines.join(" ")
    end

  public

  private
    def monthly_payment_amount(capital = nil)
      cap = capital || account.balance.to_f.abs
      return 0 if cap <= 0 || interest_rate.nil?

      r = interest_rate / 100.0 / 12.0
      n = term_months || 360

      if r.zero?
        cap / n
      else
        (cap * r * (1 + r)**n) / ((1 + r)**n - 1)
      end
    end

  public

  class << self
    def color
      "#D444F1"
    end

    def icon
      "hand-coins"
    end

    def classification
      "liability"
    end
  end
end
