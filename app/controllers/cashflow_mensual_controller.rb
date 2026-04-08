class CashflowMensualController < ApplicationController
  SPENDING_ACCOUNTS = %w[
    88d62f0b-6993-4852-ae36-fe6cec193d2b
    98c1eb20-896f-40d7-8075-7929726ad43b
  ].freeze

  TRANSFER_CATEGORIES = ["Services", "Savings & Investments"].freeze

  def show
    @months = build_monthly_data
    @categories_breakdown = build_category_breakdown
  end

  private

  def transfer_category_ids
    @transfer_category_ids ||= Current.family.categories.where(name: TRANSFER_CATEGORIES).pluck(:id)
  end

  def real_expenses(start_date, end_date)
    scope = Entry.where(
      account_id: SPENDING_ACCOUNTS,
      entryable_type: "Transaction",
      date: start_date..end_date
    ).where("entries.excluded IS NOT TRUE")
     .where("entries.amount > 0 AND entries.amount < 5000")

    if transfer_category_ids.any?
      scope = scope.joins("INNER JOIN transactions ON transactions.id = entries.entryable_id AND entries.entryable_type = 'Transaction'")
                   .where("transactions.category_id IS NULL OR transactions.category_id NOT IN (?)", transfer_category_ids)
    end

    scope
  end

  def salary_income(start_date, end_date)
    Entry.where(
      account_id: SPENDING_ACCOUNTS,
      entryable_type: "Transaction",
      date: start_date..end_date
    ).where("entries.amount < 0")
     .where("entries.name ILIKE '%nomina%' OR entries.name ILIKE '%level%' OR entries.name ILIKE '%iberia%'")
  end

  def build_monthly_data
    months = []
    # Last 6 months + current
    7.times do |i|
      date = i.months.ago.to_date
      start_d = date.beginning_of_month
      end_d = date.end_of_month
      end_d = Date.current if end_d > Date.current

      gastos = real_expenses(start_d, end_d).sum(:amount).to_f
      ingresos = salary_income(start_d, end_d).sum("ABS(entries.amount)").to_f
      ahorro = ingresos - gastos

      months << {
        label: I18n.l(start_d, format: "%B %Y").capitalize,
        month: start_d.strftime("%Y-%m"),
        gastos: gastos.round(2),
        ingresos: ingresos.round(2),
        ahorro: ahorro.round(2),
        ahorro_pct: ingresos > 0 ? (ahorro / ingresos * 100).round(1) : 0,
        num_tx: real_expenses(start_d, end_d).count
      }
    end

    months.reverse
  end

  def build_category_breakdown
    start_d = 3.months.ago.to_date.beginning_of_month
    end_d = Date.current

    real_expenses(start_d, end_d)
      .joins("INNER JOIN transactions t2 ON t2.id = entries.entryable_id AND entries.entryable_type = 'Transaction'")
      .joins("LEFT JOIN categories ON categories.id = t2.category_id")
      .group("COALESCE(categories.name, 'Sin categoría')", "categories.color")
      .order(Arel.sql("SUM(entries.amount) DESC"))
      .pluck(Arel.sql("COALESCE(categories.name, 'Sin categoría')"), "categories.color", Arel.sql("SUM(entries.amount)"), Arel.sql("COUNT(*)"))
      .map do |name, color, total, count|
        {
          name: name,
          color: color || "#9E9E9E",
          total: total.to_f.round(2),
          mensual: (total.to_f / 3).round(2),
          count: count
        }
      end
  end
end
