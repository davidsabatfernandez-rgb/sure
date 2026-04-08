class PropertyExpensesController < ApplicationController
  before_action :set_account
  before_action :set_expense, only: [:update, :destroy]

  def create
    @property = @account.accountable
    @expense = @property.property_expenses.build(expense_params)

    if @expense.save
      redirect_to account_inmueble_path(@account, anchor: "impuestos"), notice: "Gasto añadido"
    else
      redirect_to account_inmueble_path(@account, anchor: "impuestos"), alert: "Error al añadir gasto"
    end
  end

  def update
    if @expense.update(expense_params)
      redirect_to account_inmueble_path(@account, anchor: "impuestos"), notice: "Gasto actualizado"
    else
      redirect_to account_inmueble_path(@account, anchor: "impuestos"), alert: "Error al actualizar"
    end
  end

  def destroy
    @expense.destroy
    redirect_to account_inmueble_path(@account, anchor: "impuestos"), notice: "Gasto eliminado"
  end

  private
    def set_account
      @account = Current.family.accounts.find(params[:account_id])
    end

    def set_expense
      @expense = @account.accountable.property_expenses.find(params[:id])
    end

    def expense_params
      params.require(:property_expense).permit(:concepto, :importe, :tipo, :frecuencia, :categoria, :fecha, :notas)
    end
end
