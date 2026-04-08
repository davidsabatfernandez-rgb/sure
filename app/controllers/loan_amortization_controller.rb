class LoanAmortizationController < ApplicationController
  before_action :set_account

  def show
    @loan = @account.accountable
    @schedule = @loan.amortization_schedule
    @total_intereses = @loan.total_intereses_restantes
    @fecha_liquidacion = @loan.fecha_liquidacion
    @pct_amortizado = @loan.porcentaje_amortizado
    @coste_total = @loan.coste_total
    @analysis = @loan.amortization_analysis(Current.family)
  end

  def simulate
    @loan = @account.accountable
    amort = params[:amortizacion_anticipada].to_f
    cuota_extra = params[:cuota_extra].to_f

    result = @loan.simulate(amortizacion_anticipada: amort, cuota_extra: cuota_extra)

    render json: {
      meses_ahorrados: result[:meses_ahorrados],
      intereses_ahorrados: result[:intereses_ahorrados],
      nueva_fecha_liquidacion: result[:nueva_fecha_liquidacion]&.strftime("%B %Y"),
      schedule_actual: result[:schedule_actual].each_slice(12).map { |year|
        { capital: year.sum { |m| m[:capital] }, intereses: year.sum { |m| m[:intereses] } }
      },
      schedule_simulado: result[:schedule_simulado].each_slice(12).map { |year|
        { capital: year.sum { |m| m[:capital] }, intereses: year.sum { |m| m[:intereses] } }
      }
    }
  end

  private
    def set_account
      @account = Current.family.accounts.find(params[:account_id])
    end
end
