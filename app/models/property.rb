class Property < ApplicationRecord
  include Accountable

  SUBTYPES = {
    "single_family_home" => { short: "Single Family Home", long: "Single Family Home" },
    "multi_family_home" => { short: "Multi-Family Home", long: "Multi-Family Home" },
    "condominium" => { short: "Condo", long: "Condominium" },
    "townhouse" => { short: "Townhouse", long: "Townhouse" },
    "investment_property" => { short: "Investment Property", long: "Investment Property" },
    "second_home" => { short: "Second Home", long: "Second Home" }
  }.freeze

  has_one :address, as: :addressable, dependent: :destroy
  has_many :reforms, dependent: :destroy
  has_many :property_expenses, dependent: :destroy
  has_many :property_scenarios, dependent: :destroy

  accepts_nested_attributes_for :address

  attribute :area_unit, :string, default: "sqft"

  class << self
    def icon
      "home"
    end

    def color
      "#06AED4"
    end

    def classification
      "asset"
    end
  end

  def area
    Measurement.new(area_value, area_unit) if area_value.present?
  end

  def purchase_price
    first_valuation_amount
  end

  def trend
    Trend.new(current: account.balance_money, previous: first_valuation_amount)
  end

  def balance_display_name
    "market value"
  end

  def opening_balance_display_name
    "original purchase price"
  end

  # Financial calculations for inmuebles module
  def total_reformas
    reforms.sum(:importe)
  end

  def total_gastos_recurrentes_anual
    property_expenses.recurrentes.sum { |e| e.coste_anual }
  end

  def total_gastos_puntuales
    property_expenses.puntuales.sum(:importe)
  end

  def inversion_total
    (purchase_price&.amount || 0) + (gastos_compra || 0) + total_reformas
  end

  def pnl_latente
    (account.balance || 0) - inversion_total
  end

  def pnl_latente_pct
    return 0 if inversion_total.zero?
    (pnl_latente / inversion_total * 100).round(2)
  end

  def equity_real(hipoteca_account = nil)
    valor = account.balance || 0
    deuda = hipoteca_account&.balance || 0
    valor - deuda
  end

  # Rental yield calculations
  def renta_anual_bruta
    (renta_mensual || 0) * 12
  end

  def rentabilidad_bruta
    return 0 if inversion_total.zero?
    (renta_anual_bruta / inversion_total * 100).round(2)
  end

  def renta_neta_anual
    (renta_anual_bruta - (gastos_anuales_alquiler || 0)) * ((ocupacion_pct || 100) / 100.0)
  end

  def rentabilidad_neta
    return 0 if inversion_total.zero?
    (renta_neta_anual / inversion_total * 100).round(2)
  end

  def cash_flow_mensual_neto
    renta_neta_anual / 12.0
  end

  def payback_years
    return nil if renta_neta_anual <= 0
    (inversion_total / renta_neta_anual).round(1)
  end

  private
    def first_valuation_amount
      account.entries.valuations.order(:date).first&.amount_money || account.balance_money
    end
end
