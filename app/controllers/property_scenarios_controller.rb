class PropertyScenariosController < ApplicationController
  before_action :set_account
  before_action :set_scenario, only: [:update, :destroy]

  def create
    @property = @account.accountable
    @scenario = @property.property_scenarios.build(scenario_params)

    if @scenario.save
      redirect_to account_inmueble_path(@account, anchor: "escenarios"), notice: "Escenario creado"
    else
      redirect_to account_inmueble_path(@account, anchor: "escenarios"), alert: "Error al crear escenario"
    end
  end

  def update
    if @scenario.update(scenario_params)
      redirect_to account_inmueble_path(@account, anchor: "escenarios"), notice: "Escenario actualizado"
    else
      redirect_to account_inmueble_path(@account, anchor: "escenarios"), alert: "Error al actualizar"
    end
  end

  def destroy
    @scenario.destroy
    redirect_to account_inmueble_path(@account, anchor: "escenarios"), notice: "Escenario eliminado"
  end

  private
    def set_account
      @account = Current.family.accounts.find(params[:account_id])
    end

    def set_scenario
      @scenario = @account.accountable.property_scenarios.find(params[:id])
    end

    def scenario_params
      params.require(:property_scenario).permit(
        :nombre, :precio_compra, :gastos_compra, :reformas_estimadas,
        :valor_estimado_post, :renta_mensual_estimada, :gastos_anuales_estimados,
        :ocupacion_pct, :notas
      )
    end
end
