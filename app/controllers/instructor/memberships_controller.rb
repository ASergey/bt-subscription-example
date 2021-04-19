class Instructor::MembershipsController < ApplicationController
  before_action :authenticate_user!, except: :show
  before_action :authorize_membership, except: %i[show payment_method]

  def show; end

  def new
    @payment_method = current_user.braintree_payment_method
    gon.push GeoLocations.resource_locations(current_user)
                         .merge(
                           client_token: braintree_payment.client_token,
                           user: user_billing_info,
                           payment_method_url: payment_method_membership_path,
                           subscription_url: membership_path,
                           submit_text: I18n.t('membership.form.submit'),
                           payment_token: @payment_method.try(:payment_token),
                           braintree_monthly_plan_id: Setting['braintree_monthly_plan_id'],
                           subscription_monthly_price: money(ENV['SUBSCRIPTION_MONTHLY_PRICE']),
                           subscription_yearly_price: money(ENV['SUBSCRIPTION_YEARLY_PRICE']),
                           subscription_plan_id: Setting['braintree_monthly_plan_id']
                         )
  end

  def create
    payment_method = BraintreePaymentMethod.find_by(user_id: current_user.id, payment_token: params[:payment_token])
    return ajax_error(I18n.t('membership.payment_method.not_found')) if payment_method.blank?
    if [Setting['braintree_monthly_plan_id'], Setting['braintree_yearly_plan_id']].exclude?(params['plan_id'])
      return ajax_error(errors: { plan_id: [I18n.t('errors.messages.inclusion')] })
    end

    result = Services::Braintree::Subscription.new.call(
      payment_method: payment_method, payment_nonce: params[:payment_nonce], plan_id: params[:plan_id]
    )
    return ajax_error(result[:error]) if result != true && result[:error].present?
    ajax_ok(redirect_url: users_subscription_url)
  end

  def payment_method
    authorize!(:access_payment_method, :user)
    payment_method_form = Forms::Braintree::PaymentMethodForm.new(BraintreePaymentMethod.new(user: current_user))
    payment_method_form.prepopulate!
    if payment_method_form.validate(params)
      payment_method = Services::Braintree::Customer.call(payment_method_form)
      return ajax_error(payment_method[:error]) if payment_method[:error].present?
      return ajax_ok(customer: payment_method, method_nonce: nil)
    end
    ajax_error(payment_method_form.errors.messages)
  end

  private

  def braintree_payment
    @braintree_payment ||= Services::Braintree::Payment.new
  end

  def user_billing_info
    payment_method = BraintreePaymentMethod.where(user_id: current_user.id).last
    return payment_method.attributes.symbolize_keys.extract!(*billing_info_params) if payment_method.present?

    current_user.attributes.symbolize_keys.extract!(*billing_info_params).merge(address: current_user.shipping_address)
  end

  def billing_info_params
    %i[email first_name last_name phone address unit country state city zip_code company payment_token]
  end

  def authorize_membership
    authorize!(:subscribe_to_membership, :user)
  end
end
