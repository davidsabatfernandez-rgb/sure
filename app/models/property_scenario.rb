class PropertyScenario < ApplicationRecord
  belongs_to :property

  validates :nombre, presence: true

  def inversion_total
    (precio_compra || 0) + (gastos_compra || 0) + (reformas_estimadas || 0)
  end

  def renta_anual_bruta
    (renta_mensual_estimada || 0) * 12
  end

  def rentabilidad_bruta
    return 0 if inversion_total.zero?
    (renta_anual_bruta / inversion_total * 100).round(2)
  end

  def renta_neta_anual
    (renta_anual_bruta - (gastos_anuales_estimados || 0)) * ((ocupacion_pct || 100) / 100.0)
  end

  def rentabilidad_neta
    return 0 if inversion_total.zero?
    (renta_neta_anual / inversion_total * 100).round(2)
  end

  def cash_flow_mensual
    renta_neta_anual / 12.0
  end

  def payback_years
    return nil if renta_neta_anual <= 0
    (inversion_total / renta_neta_anual).round(1)
  end

  def pnl_estimado
    (valor_estimado_post || 0) - inversion_total
  end

  def pnl_pct
    return 0 if inversion_total.zero?
    (pnl_estimado / inversion_total * 100).round(1)
  end
end
