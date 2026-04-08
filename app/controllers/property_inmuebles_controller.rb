class PropertyInmueblesController < ApplicationController
  before_action :set_account

  def show
    @property = @account.accountable
    @reforms = @property.reforms.ordered
    @expenses_recurrentes = @property.property_expenses.recurrentes.ordered
    @expenses_puntuales = @property.property_expenses.puntuales.ordered
    @scenarios = @property.property_scenarios.order(:created_at)
    @hipoteca = find_linked_hipoteca
  end

  def update_rental
    @property = @account.accountable

    if @property.update(rental_params)
      redirect_to account_inmueble_path(@account), notice: "Datos actualizados"
    else
      redirect_to account_inmueble_path(@account), alert: "Error al actualizar"
    end
  end

  private
    def set_account
      @account = Current.family.accounts.find(params[:account_id])
    end

    def find_linked_hipoteca
      Current.family.accounts
        .where(accountable_type: "Loan")
        .joins("INNER JOIN loans ON loans.id = accounts.accountable_id")
        .where(loans: { subtype: "mortgage" })
        .first
    end

    def rental_params
      params.require(:property).permit(:renta_mensual, :gastos_anuales_alquiler, :ocupacion_pct, :gastos_compra, :valor_post_reforma)
    end
end
