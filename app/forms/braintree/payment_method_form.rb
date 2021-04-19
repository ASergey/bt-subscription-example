class Forms::Braintree::PaymentMethodForm < Reform::Form
  model :braintree_payment_method

  property :payment_nonce, virtual: true
  property :payment_token
  property :paypal_email
  property :card_type
  property :card_exp_month
  property :card_exp_year
  property :card_last_four
  property :card_bin
  property :email
  property :first_name
  property :last_name
  property :phone
  property :address
  property :unit
  property :country
  property :state
  property :city
  property :zip_code
  property :company
  property :user do
    property :instructor_agreement, prepopulator: ->(_options) { self.instructor_agreement = false }
    validates :instructor_agreement, acceptance: { accept: true }
  end

  validates :payment_nonce, presence: true
  validates :card_exp_month,
            presence: true,
            numericality: { greater_than: 0, less_than_or_equal: 12 },
            if: 'card_type.present?'
  validates :card_exp_year,
            presence: true,
            numericality: { greater_than_or_equal_to: Time.current.year },
            if: 'card_type.present?'
  validates :email, presence: true, format: { with: Devise.email_regexp }
  validates :paypal_email, presence: true, unless: 'card_type.present?'
  validates :first_name, presence: true, format: { with: User::REGEXP_NAME }
  validates :last_name, presence: true, format: { with: User::REGEXP_NAME }
  validates :phone, presence: true, phone: true
  validates :country, presence: true, inclusion: {
    in: GeoLocations.countries_codes, message: I18n.t('validations.location.invalid_country')
  }
  validates :city, presence: true
  validates :address, presence: true
  validates :zip_code, presence: {
    message: I18n.t('validations.location.zip_code_presence')
  }, unless: '!GoingPostal.required?(country)'
  validates :user, presence: true

  def sync
    super
    model.payment_method_type = if card_type.present?
                                  BraintreePaymentMethod::CREDIT_CARD_TYPE
                                else
                                  BraintreePaymentMethod::PAYPAL_TYPE
                                end
    model.customer_id = "zumbini_member_#{user.id}"
    model.user.validated_scopes = [:no_password]
    model.user.instructor_agreement_accepted_at = Time.current
  end
end
