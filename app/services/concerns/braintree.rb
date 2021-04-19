module Services::Concerns::Braintree
  extend ActiveSupport::Concern

  def gateway
    @braintree_gateway ||= Braintree::Gateway.new(
      environment: ENV['BRAINTREE_ENVIRONMENT'],
      merchant_id: ENV['BRAINTREE_MERCHANT_ID'],
      public_key: ENV['BRAINTREE_PUBLIC_KEY'],
      private_key: ENV['BRAINTREE_PRIVATE_KEY'],
      merchant_account_id: ENV['BRAINTREE_MERCHANT_ACCOUNT_ID']
    )
  end

  def logger
    return @logger unless @logger.nil?
    return @logger = Logger.new(STDOUT) if ENV['LOG_TO_FILE'].to_i.zero?
    log_path = Rails.root.join('log', 'braintree')
    FileUtils.mkdir_p Rails.public_path.join(log_path)
    @logger = Logger.new("#{log_path}/braintree-#{Time.current.to_formatted_s(:logger)}.log")
  end

  private

  def prepare_save(subscription)
    {
      plan_id:                    subscription.plan_id,
      balance:                    subscription.balance,
      price:                      subscription.price,
      status:                     subscription.status.downcase.tr(' ', '_'),
      billing_day_of_month:       subscription.billing_day_of_month,
      billing_period_start_date:  subscription.billing_period_start_date,
      billing_period_end_date:    subscription.billing_period_end_date,
      paid_through_date:          subscription.paid_through_date,
      next_billing_date:          subscription.next_billing_date,
      next_billing_period_amount: subscription.next_billing_period_amount,
      days_past_due:              subscription.days_past_due,
      current_billing_cycle:      subscription.current_billing_cycle
    }
  end
end
