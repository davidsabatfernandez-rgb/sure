class NetWorthSnapshot < ApplicationRecord
  belongs_to :family

  validates :fecha, :activos, :pasivos, :patrimonio_neto, presence: true
  validates :fecha, uniqueness: { scope: :family_id }

  scope :ordered, -> { order(fecha: :asc) }

  def self.take_snapshot!(family)
    balance_sheet = BalanceSheet.new(family)

    activos_total = balance_sheet.assets.total
    pasivos_total = balance_sheet.liabilities.total

    desglose = {
      activos: balance_sheet.assets.account_groups.map { |g|
        { tipo: g.name, total: g.total.amount.to_f }
      },
      pasivos: balance_sheet.liabilities.account_groups.map { |g|
        { tipo: g.name, total: g.total.amount.to_f }
      }
    }

    create_or_find_by!(family: family, fecha: Date.current) do |snap|
      snap.activos = activos_total.amount
      snap.pasivos = pasivos_total.amount
      snap.patrimonio_neto = activos_total.amount - pasivos_total.amount
      snap.desglose = desglose
    end
  end
end
