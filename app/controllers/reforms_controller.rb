class ReformsController < ApplicationController
  before_action :set_account
  before_action :set_reform, only: [:update, :destroy]

  def create
    @property = @account.accountable
    @reform = @property.reforms.build(reform_params)

    if @reform.save
      redirect_to property_inmueble_path(@account), notice: "Reforma añadida"
    else
      redirect_to property_inmueble_path(@account), alert: "Error al añadir reforma"
    end
  end

  def update
    if @reform.update(reform_params)
      redirect_to property_inmueble_path(@account), notice: "Reforma actualizada"
    else
      redirect_to property_inmueble_path(@account), alert: "Error al actualizar reforma"
    end
  end

  def destroy
    @reform.destroy
    redirect_to property_inmueble_path(@account), notice: "Reforma eliminada"
  end

  private
    def set_account
      @account = Current.family.accounts.find(params[:account_id])
    end

    def set_reform
      @reform = @account.accountable.reforms.find(params[:id])
    end

    def reform_params
      params.require(:reform).permit(:concepto, :importe, :fecha)
    end
end
