class Reform < ApplicationRecord
  belongs_to :property

  validates :concepto, :importe, :fecha, presence: true
  validates :importe, numericality: { greater_than: 0 }

  scope :ordered, -> { order(fecha: :desc) }
end
