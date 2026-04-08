class CashflowDetailController < ApplicationController
  SPENDING_ACCOUNT_IDS = FamilyFinancialSummary::SPENDING_ACCOUNT_IDS

  def show
    @node_name = params[:node]
    @period = Period.from_param(params[:period])

    entries_scope = Entry.where(
      account_id: SPENDING_ACCOUNT_IDS,
      entryable_type: "Transaction",
      date: @period.date_range
    ).where("entries.excluded IS NOT TRUE")
     .includes(:account)
     .joins("INNER JOIN transactions ON transactions.id = entries.entryable_id AND entries.entryable_type = 'Transaction'")
     .joins("LEFT JOIN categories ON categories.id = transactions.category_id")

    @entries = case @node_name&.downcase
    when "income"
      entries_scope.where("entries.amount < 0").order(date: :desc)
    when "cash flow"
      entries_scope.order(date: :desc).limit(50)
    else
      # Category name match
      if @node_name == "Sin clasificar" || @node_name == "Uncategorized"
        entries_scope.where("transactions.category_id IS NULL AND entries.amount > 0").order(date: :desc)
      else
        entries_scope.where("categories.name = ? AND entries.amount > 0", @node_name).order(date: :desc)
      end
    end

    @total = @entries.sum("ABS(entries.amount)").to_f
    @count = @entries.count

    render layout: false
  end
end
