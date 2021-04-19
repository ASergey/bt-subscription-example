class Instructor::MembershipsControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers

  setup do
    Services::Braintree::Payment.any_instance.stubs(:client_token).returns('client_token')
    Setting['braintree_monthly_plan_id'] = 'monthly_plan'
    Setting['braintree_yearly_plan_id'] = 'yearly_plan'
  end

  test 'show unauthorized' do
    get :show
    assert_response :success
  end

  test 'show no zin role or training_user' do
    sign_in(create(:user))
    get :show
    assert_response :success
  end

  test 'show no zin role with unpaid training_user' do
    user = create(:training_user, status: TrainingUser::STATUS_UNPAID, training: create(:training_started)).user
    sign_in(user)
    get :show
    assert_response :success
  end

  test 'show access for training_user with existent active subscription' do
    user = create(:training_user, training: create(:training_started)).user
    create(:braintree_subscription, user: user)
    sign_in(user)
    get :show
    assert_response :success
  end

  test 'show access for zin role with existent active subscription' do
    user = create(:user_zin)
    create(:braintree_subscription, user: user)
    sign_in(user)
    get :show
    assert_response :success
  end

  test 'show access for zin role' do
    sign_in(create(:user_zin))
    get :show
    assert_response :success
  end

  test 'show access for training_user' do
    user = create(:training_user, training: create(:training_started)).user
    sign_in(user)
    get :show
    assert_response :success
  end

  test 'show access for zin with canceled subscription' do
    user = create(:user_zin)
    create(
      :braintree_subscription,
      status: BraintreeSubscription::STATUS_CANCELED,
      user: user
    )

    sign_in(user)
    get :show
    assert_response :success
  end

  test 'new unauthorized' do
    get :new
    assert_response :redirect
    assert_redirected_to new_user_session_url
  end

  test 'new no zin role or training_user' do
    sign_in(create(:user))
    get :new
    assert_response :redirect
  end

  test 'new no zin role with unpaid training_user' do
    user = create(:training_user, status: TrainingUser::STATUS_UNPAID, training: create(:training_started)).user
    sign_in(user)
    get :new
    assert_response :redirect
  end

  test 'new no access for training_user with existent active subscription' do
    user = create(:training_user, training: create(:training_started)).user
    create(:braintree_subscription, user: user)
    sign_in(user)
    get :new
    assert_response :redirect
  end

  test 'new no access for zin role with existent active subscription' do
    user = create(:user_zin)
    create(:braintree_subscription, user: user)
    sign_in(user)
    get :new
    assert_response :redirect
  end

  test 'new access for zin role' do
    sign_in(create(:user_zin))
    get :new
    assert_response :success
  end

  test 'new access for training_user' do
    user = create(:training_user, training: create(:training_started)).user
    sign_in(user)
    get :new
    assert_response :success
  end

  test 'new access for zin with canceled subscription' do
    user = create(:user_zin)
    create(
      :braintree_subscription,
      status: BraintreeSubscription::STATUS_CANCELED,
      user: user
    )
    Services::Braintree::Payment.any_instance
                                .expects(:client_token)
                                .returns('client_token')

    sign_in(user)
    get :new
    assert_response :success
  end

  test 'create unauthorized' do
    Services::Braintree::Subscription.any_instance.expects(:call).never
    post :create
    assert_response :redirect
    assert_redirected_to new_user_session_url
  end

  test 'create no zin role or training_user' do
    Services::Braintree::Subscription.any_instance.expects(:call).never
    sign_in(create(:user))
    post :create
    assert_response :redirect
  end

  test 'create no zin role with unpaid training_user' do
    user = create(:training_user, status: TrainingUser::STATUS_UNPAID, training: create(:training_started)).user
    Services::Braintree::Subscription.any_instance.expects(:call).never

    sign_in(user)
    post :create
    assert_response :redirect
  end

  test 'create no access for training_user with existent active subscription' do
    user = create(:training_user, training: create(:training_started)).user
    create(:braintree_subscription, user: user)
    Services::Braintree::Subscription.any_instance.expects(:call).never

    sign_in(user)
    post :create
    assert_response :redirect
  end

  test 'create no access for zin role with existent active subscription' do
    user = create(:user_zin)
    create(:braintree_subscription, user: user)
    BraintreePaymentMethod.expects(:find_by).never
    Services::Braintree::Subscription.any_instance.expects(:call).never

    sign_in(user)
    post :create
    assert_response :redirect
  end

  test 'create failed for not found payment token' do
    payment_method = create(:braintree_payment_method, user: create(:user_zin))
    Services::Braintree::Subscription.any_instance.expects(:call).never

    sign_in(payment_method.user)
    post :create, payment_token: 'not_registered_payment_token'
    assert_response :unprocessable_entity
    response_body = JSON.parse(@response.body)
    assert_not_empty response_body
    assert_equal I18n.t('membership.payment_method.not_found'), response_body['common']
  end

  test 'create success zin role' do
    payment_method = create(:braintree_payment_method, payment_token: 'payment_token', user: create(:user_zin))
    Services::Braintree::Subscription.any_instance.expects(:call).with(
      payment_method: payment_method,
      payment_nonce: 'nonce',
      plan_id: 'monthly_plan'
    ).returns(true)

    sign_in(payment_method.user)
    post :create, payment_token: 'payment_token', payment_nonce: 'nonce', plan_id: 'monthly_plan'
    assert_response :success
    response_body = JSON.parse(@response.body)
    assert_not_empty response_body
    assert_equal ({ 'redirect_url' => users_subscription_url }), response_body
  end

  test 'create success training_user' do
    user = create(:training_user, training: create(:training_started)).user
    payment_method = create(:braintree_payment_method, payment_token: 'payment_token', user: user)
    Services::Braintree::Subscription.any_instance.expects(:call).with(
      payment_method: payment_method,
      payment_nonce: 'nonce',
      plan_id: 'monthly_plan'
    ).returns(true)

    sign_in(user)
    post :create, payment_token: 'payment_token', payment_nonce: 'nonce', plan_id: 'monthly_plan'
    assert_response :success
    response_body = JSON.parse(@response.body)
    assert_not_empty response_body
    assert_equal ({ 'redirect_url' => users_subscription_url }), response_body
  end

  test 'create access for zin with expired subscription' do
    user = create(:user_zin)
    payment_method = create(:braintree_payment_method, payment_token: 'payment_token', user: user)
    create(
      :braintree_subscription,
      status: BraintreeSubscription::STATUS_EXPIRED,
      braintree_payment_method: payment_method
    )
    Services::Braintree::Subscription.any_instance.expects(:call).with(
      payment_method: payment_method,
      payment_nonce: 'nonce',
      plan_id: 'monthly_plan'
    ).returns(true)

    sign_in(user)
    post :create, payment_token: 'payment_token', payment_nonce: 'nonce', plan_id: 'monthly_plan'
    assert_response :success
    response_body = JSON.parse(@response.body)
    assert_not_empty response_body
    assert_equal ({ 'redirect_url' => users_subscription_url }), response_body
  end

  test 'create when subscription plan_id is invalid' do
    user = create(:user_zin)
    create(:braintree_payment_method, user: user, payment_token: 'payment_token')
    Services::Braintree::Subscription.any_instance.expects(:call).never

    sign_in(user)
    post :create, payment_token: 'payment_token', payment_nonce: 'nonce', plan_id: 'invalid_plan_id'
    assert_response :unprocessable_entity
    response_body = JSON.parse(@response.body)
    assert_not_empty response_body
    assert_equal 'is not included in the list', response_body['errors']['plan_id'].first
  end

  test 'create subscription service fails' do
    user = create(:user_zin)
    payment_method = create(:braintree_payment_method, user: user, payment_token: 'payment_token')
    Services::Braintree::Subscription.any_instance.expects(:call).with(
      payment_method: payment_method,
      payment_nonce: 'nonce',
      plan_id: 'monthly_plan'
    ).returns(error: 'subscription_create_error')

    sign_in(user)
    post :create, payment_token: 'payment_token', payment_nonce: 'nonce', plan_id: 'monthly_plan'
    assert_response :unprocessable_entity
    response_body = JSON.parse(@response.body)
    assert_not_empty response_body
    assert_equal 'subscription_create_error', response_body['common']
  end

  test 'payment_method unauthorized' do
    post :payment_method
    assert_response :redirect
    assert_redirected_to new_user_session_url
  end

  test 'payment_method no zin role or training_user' do
    sign_in(create(:user))
    post :payment_method
    assert_response :redirect
  end

  test 'payment_method no zin role with unpaid training_user' do
    Services::Braintree::Customer.any_instance.expects(:call).never
    user = create(:training_user, status: TrainingUser::STATUS_UNPAID, training: create(:training_started)).user
    sign_in(user)
    post :payment_method
    assert_response :redirect
  end

  test 'payment_method with invalid params for training_user with existent active subscription' do
    Services::Braintree::Customer.any_instance.expects(:call).never
    Services::Braintree::Payment.any_instance.expects(:payment_method_nonce).never
    user = create(:training_user, training: create(:training_started)).user
    create(:braintree_subscription, user: user)
    sign_in(user)
    post :payment_method
    assert_response :unprocessable_entity
  end

  test 'payment_method with invalid params for zin role with existent active subscription' do
    Services::Braintree::Customer.any_instance.expects(:call).never
    Services::Braintree::Payment.any_instance.expects(:payment_method_nonce).never
    user = create(:user_zin)
    create(:braintree_subscription, user: user)
    sign_in(user)
    post :payment_method
    assert_response :unprocessable_entity
  end

  test 'payment_method request with invalid params' do
    Services::Braintree::Customer.any_instance.expects(:call).never
    Services::Braintree::Payment.any_instance.expects(:payment_method_nonce).never

    sign_in(create(:user_zin))
    post :payment_method,
         payment_nonce: 'payment_nonce',
         card_type: 'card_type',
         card_exp_month: 12,
         card_exp_year: 2022,
         card_last_four: 1234,
         card_bin: 'card_bin',
         email: 'email',
         first_name: 'first name',
         last_name: 'last name',
         phone: '123445677',
         address: 'address',
         unit: 'unit',
         country: 'US',
         state: 'state',
         city: 'city',
         zip_code: 'zip_code',
         user: {
           instructor_agreement: true
         }
    assert_response :unprocessable_entity
    response_body = JSON.parse(@response.body)
    assert_not_empty response_body
    assert_equal ({ 'email' => ['is invalid'] }), response_body
  end

  test 'payment_method access for zin role' do
    user = create(:user_zin)
    payment_method = create(:braintree_payment_method, user: user)
    Forms::Braintree::PaymentMethodForm.any_instance.expects(:validate).returns(true)
    Services::Braintree::Customer.any_instance.expects(:call).returns(payment_method)
    sign_in(user)
    post :payment_method
    assert_response :success
    response_body = JSON.parse(@response.body)
    assert_not_empty response_body
    assert_not_empty response_body['customer']
    assert_nil response_body['method_nonce']
  end

  test 'payment_method access for training_user and fails on payment_method creation' do
    user = create(:training_user, training: create(:training_started)).user
    create(:braintree_payment_method, user: user)
    Forms::Braintree::PaymentMethodForm.any_instance.expects(:validate).returns(true)
    Services::Braintree::Customer.any_instance.expects(:call).returns(error: 'payment_method_create_error')
    Services::Braintree::Payment.any_instance.expects(:payment_method_nonce).never

    sign_in(user)
    post :payment_method
    assert_response :unprocessable_entity
    response_body = JSON.parse(@response.body)
    assert_not_empty response_body
    assert_equal 'payment_method_create_error', response_body['common']
  end

  test 'payment_method access for zin with canceled subscription' do
    user = create(:user_zin)
    create(
      :braintree_subscription,
      status: BraintreeSubscription::STATUS_CANCELED,
      user: user
    )
    Braintree::Gateway.any_instance
                      .expects(:customer)
                      .returns(stub(update: stub(
                        success?: true,
                        customer: stub(
                          credit_cards: [stub(token: 'payment_token', last_4: '1234', bin: 'card_bin')]
                        )
                      )))

    sign_in(user)
    assert_difference('BraintreePaymentMethod.count') do
      post :payment_method,
           payment_nonce: 'payment_nonce',
           card_type: 'card_type',
           card_exp_month: 12,
           card_exp_year: 2022,
           card_last_four: '1234',
           card_bin: 'card_bin',
           email: 'email@email.com',
           first_name: 'first name',
           last_name: 'last name',
           phone: '123445677',
           address: 'address',
           unit: 'unit',
           country: 'US',
           state: 'state',
           city: 'city',
           zip_code: 'zip_code',
           user: {
             instructor_agreement: true
           }
    end
    assert_response :success
    response_body = JSON.parse(@response.body)
    assert_not_empty response_body
    assert_not_empty response_body['customer']
    assert_nil response_body['method_nonce']
    assert_in_delta user.reload.instructor_agreement_accepted_at, Time.current, 5.seconds
  end

  test 'payment_method created successfully' do
    user = create(:user_zin)
    Braintree::Gateway.any_instance
                      .expects(:customer)
                      .returns(stub(create: stub(
                        success?: true,
                        customer: stub(
                          credit_cards: [stub(token: 'payment_token_updated', last_4: '1234', bin: 'card_bin')]
                        )
                      )))

    sign_in(user)
    assert_difference('BraintreePaymentMethod.count') do
      post :payment_method,
           payment_nonce: 'payment_nonce',
           card_type: 'card_type',
           card_exp_month: 12,
           card_exp_year: 2022,
           card_last_four: '1234',
           card_bin: 'card_bin',
           email: 'email@email.com',
           first_name: 'first name',
           last_name: 'last name',
           phone: '123445677',
           address: 'address',
           unit: 'unit',
           country: 'US',
           state: 'state',
           city: 'city',
           zip_code: 'zip_code',
           user: {
             instructor_agreement: true
           }

      assert_response :success
      response_body = JSON.parse(@response.body)
      assert_nil response_body['method_nonce']
      assert_in_delta user.reload.instructor_agreement_accepted_at, Time.current, 5.seconds
    end
  end
end
