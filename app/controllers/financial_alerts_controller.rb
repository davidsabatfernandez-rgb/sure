class FinancialAlertsController < ApplicationController
  def index
    @alerts = Current.family.financial_alerts.recent
    @unread_count = Current.family.financial_alerts.unread.count
  end

  def mark_read
    alert = Current.family.financial_alerts.find(params[:id])
    alert.update!(read: true)

    redirect_to financial_alerts_path, notice: t(".success")
  end

  def mark_all_read
    Current.family.financial_alerts.unread.update_all(read: true)

    redirect_to financial_alerts_path, notice: t(".success")
  end
end
