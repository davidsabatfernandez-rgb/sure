class PatrimonioController < ApplicationController
  def show
    @balance_sheet = BalanceSheet.new(Current.family)
    @net_worth = @balance_sheet.net_worth
    @assets = @balance_sheet.assets
    @liabilities = @balance_sheet.liabilities
    @snapshots = Current.family.net_worth_snapshots.ordered
    @previous_snapshot = @snapshots.last
  end

  def save_snapshot
    NetWorthSnapshot.take_snapshot!(Current.family)
    redirect_to patrimonio_path, notice: "Snapshot guardado"
  rescue ActiveRecord::RecordNotUnique
    redirect_to patrimonio_path, alert: "Ya existe un snapshot de hoy"
  end
end
