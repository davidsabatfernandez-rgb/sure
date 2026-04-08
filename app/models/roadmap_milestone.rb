class RoadmapMilestone < ApplicationRecord
  belongs_to :family

  ESTADOS = %w[pendiente en_progreso completado].freeze

  validates :nombre, presence: true
  validates :fecha_inicio, presence: true
  validates :fecha_objetivo, presence: true
  validates :estado, inclusion: { in: ESTADOS }
  validates :monto_objetivo, numericality: { greater_than: 0 }, allow_nil: true

  scope :ordered, -> { order(:orden, :fecha_objetivo) }
  scope :active, -> { where(estado: %w[pendiente en_progreso]) }
  scope :completed, -> { where(estado: "completado") }

  def progreso_pct
    return 0 if monto_objetivo.nil? || monto_objetivo.zero?
    [(monto_actual / monto_objetivo * 100).round(1), 100].min
  end

  def dias_restantes
    (fecha_objetivo - Date.current).to_i
  end

  def on_track?
    return true if estado == "completado"
    return true if monto_objetivo.nil? || monto_objetivo.zero?

    total_days = (fecha_objetivo - fecha_inicio).to_f
    return progreso_pct >= 100 if total_days <= 0

    elapsed_days = (Date.current - fecha_inicio).to_f
    expected_progress = (elapsed_days / total_days) * 100

    progreso_pct >= expected_progress * 0.85
  end

  def status_color
    return "#9CA3AF" if estado == "completado"

    if on_track?
      "#22C55E"
    elsif progreso_pct >= expected_linear_progress * 0.6
      "#EAB308"
    else
      "#EF4444"
    end
  end

  private

    def expected_linear_progress
      total_days = (fecha_objetivo - fecha_inicio).to_f
      return 100 if total_days <= 0

      elapsed_days = (Date.current - fecha_inicio).to_f
      [(elapsed_days / total_days) * 100, 100].min
    end
end
