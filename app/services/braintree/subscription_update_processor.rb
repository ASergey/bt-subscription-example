class Services::Braintree::SubscriptionUpdateProcessor
  include Services::Concerns::Service
  include Services::Concerns::Braintree

  attr_reader :braintree_subscription, :subscription

  def initialize(subscription)
    @subscription = subscription
    @braintree_subscription = BraintreeSubscription.find_by(subscription_id: subscription.id)
    raise "Subscription '#{subscription.id}' not found" if @braintree_subscription.blank?
  end

  def call
    save_params = prepare_save(subscription)
    braintree_subscription.assign_attributes(save_params)
    set_date_past_due
    reset_reminder_status
    braintree_subscription.save
    UserRoleSubscriptionJob.perform_later(
      user_id: braintree_subscription.user_id,
      braintree_subscription_id: braintree_subscription.id
    )
  end

  private

  def reset_reminder_status
    return unless braintree_subscription.status == BraintreeSubscription::STATUS_ACTIVE
    braintree_subscription.reminder_status = {}
  end

  def set_date_past_due
    return unless braintree_subscription.status_changed?

    braintree_subscription.date_past_due = nil
    if braintree_subscription.status == BraintreeSubscription::STATUS_PAST_DUE
      braintree_subscription.date_past_due = Date.current
    end
  end
end
