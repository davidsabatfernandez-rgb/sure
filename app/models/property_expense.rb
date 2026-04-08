class PropertyExpense < ApplicationRecord
  belongs_to :property

  TIPOS = %w[recurrente puntual].freeze
  FRECUENCIAS = %w[mensual trimestral anual].freeze
  CATEGORIAS = %w[material impuesto arquitecta paleta otro].freeze

  validates :concepto, :importe, :tipo, presence: true
  validates :importe, numericality: { greater_than: 0 }
  validates :tipo, inclusion: { in: TIPOS }
  validates :frecuencia, inclusion: { in: FRECUENCIAS }, allow_nil: true
  validates :categoria, inclusion: { in: CATEGORIAS }, allow_nil: true

  scope :recurrentes, -> { where(tipo: "recurrente") }
  scope :puntuales, -> { where(tipo: "puntual") }
  scope :ordered, -> { order(created_at: :desc) }

  # Coste anualizado de este gasto
  def coste_anual
    case tipo
    when "recurrente"
      case frecuencia
      when "mensual" then importe * 12
      when "trimestral" then importe * 4
      when "anual" then importe
      else importe
      end
    when "puntual"
      importe
    else
      importe
    end
  end

  def categoria_label
    {
      "material" => "Material",
      "impuesto" => "Impuesto",
      "arquitecta" => "Arquitecta",
      "paleta" => "Paleta",
      "otro" => "Otro"
    }[categoria] || categoria&.capitalize
  end
end
