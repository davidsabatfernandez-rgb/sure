class PassiveIncomeCalculator
  MONTHLY_EXPENSES_ESTIMATE = 1950 # 4750 - 2800

  attr_reader :family

  def initialize(family)
    @family = family
    @balance_sheet = BalanceSheet.new(family)
  end

  def total_monthly_passive_income
    property_income_total + remunerada_monthly_interest + dividend_monthly_estimate
  end

  def currency
    family.currency
  end

  def monthly_expenses
    MONTHLY_EXPENSES_ESTIMATE.to_f
  end

  # --- Property Income ---

  def property_sources
    @property_sources ||= begin
      property_accounts = family.accounts.visible.assets.where(accountable_type: "Property").includes(:accountable)
      property_accounts.map do |account|
        property = account.accountable
        # Properties in this schema don't have rental fields,
        # so we check for "investment_property" subtype and estimate from notes or return 0
        estimated_rent = estimate_property_rent(account)
        next if estimated_rent.zero?

        {
          name: account.name,
          account: account,
          gross_monthly: estimated_rent,
          net_monthly: estimated_rent * 0.85, # estimate 15% expenses
          value: account.balance.to_f
        }
      end.compact
    end
  end

  def property_income_total
    property_sources.sum { |s| s[:net_monthly] }
  end

  # --- Remunerada (Interest-bearing savings) ---

  def remunerada_sources
    @remunerada_sources ||= begin
      remunerada_accounts = family.accounts.visible.assets
        .where(accountable_type: "Investment")
        .where("name ILIKE ?", "%remunerada%")

      remunerada_accounts.map do |account|
        annual_rate = estimate_remunerada_rate(account)
        balance = account.balance.to_f
        daily_interest = (balance * annual_rate / 100.0) / 365.0
        monthly_interest = daily_interest * 30

        {
          name: account.name,
          account: account,
          balance: balance,
          annual_rate: annual_rate,
          daily_interest: daily_interest,
          monthly_interest: monthly_interest
        }
      end
    end
  end

  def remunerada_monthly_interest
    remunerada_sources.sum { |s| s[:monthly_interest] }
  end

  # --- Dividends ---

  def dividend_sources
    @dividend_sources ||= begin
      # Look for dividend transactions in the last 12 months
      twelve_months_ago = 12.months.ago.to_date
      dividend_entries = family.accounts.visible
        .joins(entries: :entryable)
        .where(entries: { date: twelve_months_ago..Date.current })
        .where("entries.name ILIKE ? OR entries.name ILIKE ?", "%dividend%", "%dividendo%")
        .select("accounts.name as account_name, SUM(entries.amount) as total_amount, accounts.currency as currency")
        .group("accounts.name, accounts.currency")

      dividend_entries.map do |entry|
        annual = entry.total_amount.to_f.abs
        {
          name: entry.account_name,
          annual_amount: annual,
          monthly_amount: annual / 12.0,
          currency: entry.currency
        }
      end
    rescue
      []
    end
  end

  def dividend_monthly_estimate
    dividend_sources.sum { |s| s[:monthly_amount] }
  end

  # --- Coverage & Goals ---

  def coverage_pct
    return 0.0 if monthly_expenses.zero?
    (total_monthly_passive_income / monthly_expenses) * 100
  end

  def income_gap
    [ monthly_expenses - total_monthly_passive_income, 0 ].max
  end

  def years_to_independence
    return 0 if income_gap.zero?

    # Estimate based on current savings rate growing investments
    monthly_savings = 2800.0
    annual_return = 0.05 # 5% return assumption
    target_capital = income_gap * 12 / annual_return # capital needed at 5% yield

    current_investments = family.accounts.visible.assets
      .where(accountable_type: %w[Investment Crypto])
      .sum(:balance).to_f

    remaining = [ target_capital - current_investments, 0 ].max
    return 0 if remaining.zero?

    # Simple compound growth formula: FV = PMT * ((1+r)^n - 1) / r
    # Solve for n: n = log(FV * r / PMT + 1) / log(1 + r)
    r = annual_return / 12.0
    pmt = monthly_savings

    return 99 if pmt.zero? || r.zero?

    n_months = Math.log(remaining * r / pmt + 1) / Math.log(1 + r)
    (n_months / 12.0).ceil
  rescue
    99
  end

  # --- All sources for display ---

  def all_sources
    sources = []
    property_sources.each { |s| sources << s.merge(type: :property) }
    remunerada_sources.each { |s| sources << s.merge(type: :remunerada) }
    dividend_sources.each { |s| sources << s.merge(type: :dividend) }
    sources
  end

  private

    def estimate_property_rent(account)
      # If the property is subtyped as investment_property, estimate rent as 0.4% of value monthly
      if account.accountable&.subtype == "investment_property"
        account.balance.to_f * 0.004
      else
        0.0
      end
    end

    def estimate_remunerada_rate(account)
      # Default estimate for remunerada accounts - typically 2-3% in Spain
      name = account.name.downcase
      if name.include?("trade republic") || name.include?("trade")
        3.25
      elsif name.include?("myinvestor")
        2.0
      elsif name.include?("wise")
        3.5
      else
        2.5 # default estimate
      end
    end
end
