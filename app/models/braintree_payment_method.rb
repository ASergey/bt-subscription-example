class BraintreePaymentMethod < ActiveRecord::Base
  acts_as_paranoid

  CREDIT_CARD_TYPE = 'credit_card'.freeze
  PAYPAL_TYPE = 'paypal'.freeze

  belongs_to :user
  has_many :braintree_subscriptions, -> { with_deleted }

  def cc_payment?
    payment_method_type == BraintreePaymentMethod::CREDIT_CARD_TYPE
  end
end
