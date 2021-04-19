class BraintreeSubscription < ActiveRecord::Base
  STATUS_ACTIVE   = 'active'.freeze
  STATUS_PENDING  = 'pending'.freeze
  STATUS_PAST_DUE = 'past_due'.freeze
  STATUS_EXPIRED  = 'expired'.freeze
  STATUS_CANCELED = 'canceled'.freeze

  has_many :subscription_invoices, dependent: :destroy
  belongs_to :braintree_payment_method
  belongs_to :user

  scope :available, ->         { where.not(status: [STATUS_EXPIRED, STATUS_CANCELED]) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_user, lambda { |user_id|
    joins(:braintree_payment_method).where('braintree_payment_methods.user_id' => user_id).order(id: :desc)
  }
  scope :in_action, lambda { |payment_method_id|
    available.where(braintree_payment_method_id: payment_method_id)
  }
  scope :canceled_before_expired, lambda {
    where(status: STATUS_CANCELED).where('next_billing_date > ?', Time.current.beginning_of_day).order(id: :desc)
  }

  def available?
    status != STATUS_EXPIRED && status != STATUS_CANCELED
  end

  def past_due?
    status == STATUS_PAST_DUE
  end

  def year_commitment_active?
    Date.current < year_commitment_date
  end

  def year_commitment_date
    return cancel_date if cancel_date.present?
    first_subscription = Queries::BraintreeSubscriptions::FirstTimePaid.call(user_id)
    first_subscription = first_subscription.presence || self
    (first_subscription.first_billing_date + 1.year).to_date
  end
end
