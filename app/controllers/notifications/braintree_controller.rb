class Notifications::BraintreeController < ActionController::Base
  def create
    notification = parse_notification
    if [
      Braintree::WebhookNotification::Kind::SubscriptionCanceled,
      Braintree::WebhookNotification::Kind::SubscriptionChargedSuccessfully,
      Braintree::WebhookNotification::Kind::SubscriptionChargedUnsuccessfully,
      Braintree::WebhookNotification::Kind::SubscriptionExpired,
      Braintree::WebhookNotification::Kind::SubscriptionWentActive,
      Braintree::WebhookNotification::Kind::SubscriptionWentPastDue
    ].include?(notification.kind)
      Services::Braintree::SubscriptionUpdateProcessor.call(notification.subscription)
    end
    if notification.kind == Braintree::WebhookNotification::Kind::PaymentMethodRevokedByCustomer
      subscription_model = BraintreeSubscription.find_by(subscription_id: notification.subscription.id)
      raise "Subscription '#{subscription.id}' not found" if subscription_model.blank?
      subscription_model.braintree_payment_method.destroy
    end
    if [
      Braintree::WebhookNotification::Kind::SubscriptionChargedSuccessfully,
      Braintree::WebhookNotification::Kind::SubscriptionChargedUnsuccessfully
    ].include?(notification.kind)
      Services::Braintree::SubscriptionInvoiceProcessor.call(notification)
    end
    head :ok
  rescue Braintree::InvalidSignature
    braintree_service.logger.error('Invalid webhook request signature')
    head :bad_request
  rescue StandardError => e
    braintree_service.logger.error(message: e.message, backtrace: e.backtrace)
    head :ok
  end

  private

  def parse_notification
    notification = braintree_service.gateway.webhook_notification.parse(
      request.params['bt_signature'],
      request.params['bt_payload']
    )
    log_params = { class_name: self.class.name, kind: notification.kind, timestamp: notification.timestamp }
    braintree_service.logger.info(log_params.merge(debug_subscription: notification.subscription))
    notification
  end

  def braintree_service
    @braintree ||= Services::Braintree::Payment.new
  end
end
