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
