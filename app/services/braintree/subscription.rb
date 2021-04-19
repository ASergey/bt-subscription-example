class Services::Braintree::Subscription
  include Services::Concerns::Braintree

  def call(payment_method:, payment_nonce: nil, plan_id:)
    subscription_exists = BraintreeSubscription.in_action(payment_method.id).exists?
    return { error: I18n.t('membership.subscription.exists') } if subscription_exists

    result = gateway.subscription.create(create_params(payment_method: payment_method, plan_id: plan_id))
    raise "Could not create braintree subscription. Reason: #{result.try(:message)}" unless result.success?
    old_payment_methods = BraintreePaymentMethod.where(user_id: payment_method.user.id)
                                                .where.not(payment_token: payment_method.payment_token)
    save_params = prepare_save(result.subscription)
    braintree_subscription = BraintreeSubscription.new(
      save_params.merge(
        user: payment_method.user,
        braintree_payment_method: payment_method,
        subscription_id:          result.subscription.id,
        first_billing_date:       result.subscription.first_billing_date
      )
    )
    ActiveRecord::Base.transaction do
      braintree_subscription.save!
      old_payment_methods.destroy_all if old_payment_methods.present?
      UserRoleSubscriptionJob.perform_later(
        user_id: payment_method.user_id,
        braintree_subscription_id: braintree_subscription.id
      )
    end
    process_mailers(braintree_subscription.user_id) if braintree_subscription.persisted?
    true
  rescue StandardError => e
    logger.error "#{self.class}. #{e}; Backtrace: #{e.backtrace}"
    return { error: I18n.t('membership.subscription.create_failed') }
  end

  def mark_canceled(braintree_subscription)
    raise ActiveRecord::RecordNotFound unless braintree_subscription.available?
    if braintree_subscription.year_commitment_active?
      return false if braintree_subscription.cancel_date.present?
      braintree_subscription.update(cancel_date: braintree_subscription.year_commitment_date)
    else
      cancel(braintree_subscription)
    end
  rescue StandardError => e
    logger.error "#{self.class}. #{e}; Backtrace: #{e.backtrace}"
    return false
  end

  def cancel(braintree_subscription)
    raise ActiveRecord::RecordNotFound unless braintree_subscription.available?
    result = gateway.subscription.cancel(braintree_subscription.subscription_id)
    raise "Could not cancel braintree subscription. Reason: #{result.try(:message)}" unless result.success?
    braintree_subscription.update(status: BraintreeSubscription::STATUS_CANCELED)
  rescue StandardError => e
    logger.error "#{self.class}. #{e}; Backtrace: #{e.backtrace}"
    return false
  end

  def update(subscription:, payment_token:, payment_nonce: nil)
    old_payment_methods = BraintreePaymentMethod.where(user_id: subscription.user.id)
                                                .where.not(payment_token: payment_token)
    new_payment_method = BraintreePaymentMethod.find_by(user_id: subscription.user.id, payment_token: payment_token)
    raise ActiveRecord::RecordNotFound unless subscription.available?
    raise ActiveRecord::RecordNotFound if new_payment_method.blank?

    result = gateway.subscription.update(subscription.subscription_id, payment_method_token: payment_token)
    unless result.success?
      raise "Could not update subscription '#{subscription.subscription_id}'. " \
            "Reason: #{result.try(:message)}"
    end

    ActiveRecord::Base.transaction do
      subscription.update!(braintree_payment_method: new_payment_method)
      old_payment_methods.destroy_all if old_payment_methods.present?
    end

    true
  rescue StandardError => e
    logger.error "#{self.class}. #{e}; Backtrace: #{e.backtrace}"
    return { error: I18n.t('membership.subscription.update_failed') }
  end

  def retry_charge(braintree_subscription)
    result = gateway.subscription.retry_charge(
      braintree_subscription.subscription_id,
      braintree_subscription.balance,
      true
    )
    unless result.success?
      raise "Could not update subscription '#{braintree_subscription.subscription_id}'. " \
            "Reason: #{result.try(:message)}"
    end
    braintree_subscription.update(status: BraintreeSubscription::STATUS_ACTIVE, date_past_due: nil)
  rescue StandardError => e
    logger.error "#{self.class}. #{e}; Backtrace: #{e.backtrace}"
    return { error: I18n.t('membership.subscription.retry_charge.failed') }
  end

  private

  def create_params(payment_method:, payment_nonce: nil, plan_id:)
    params = { plan_id: plan_id }
    if payment_nonce.present?
      params[:payment_method_nonce] = payment_nonce
    else
      params[:payment_method_token] = payment_method.payment_token
    end

    previous_subscription = BraintreeSubscription.canceled_before_expired.where(user_id: payment_method.user.id).first
    params[:first_billing_date] = previous_subscription.next_billing_date if previous_subscription.present?
    params
  end

  def process_mailers(user_id)
    MembershipMailer.join_play_confirmation(user_id).deliver_later
    if ZumbiniClass.posted_before_membership(user_id).exists?
      MembershipMailer.sessions_posted_fyi(user_id).deliver_later
    end
  end
end
