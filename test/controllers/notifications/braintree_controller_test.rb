class Notifications:: BraintreeControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers

  test 'parse_notification raises InvalidSignature' do
    assert_raises(Braintree::InvalidSignature) do
      @controller.send(:parse_notification)
    end
  end

  test 'parse_notification returns parsed notification' do
    logger = mock('logger')
    logger.expects(:info).with(
      class_name: 'Notifications::BraintreeController',
      kind: 'kind',
      timestamp: 'timestamp',
      debug_subscription: 'subscription'
    )
    Services::Braintree::Payment.any_instance.stubs(:logger).returns(logger)
    gateway = mock('gateway')
    parse = mock('parse')
    parse.expects(:parse).returns(stub(kind: 'kind', subscription: 'subscription', timestamp: 'timestamp'))
    gateway.expects(:webhook_notification).returns(parse)
    Services::Braintree::Payment.any_instance.stubs(:gateway).returns(gateway)
    result = @controller.send(:parse_notification)
    assert_equal 'kind', result.kind
    assert_equal 'timestamp', result.timestamp
    assert_equal 'subscription', result.subscription
  end

  test 'bad_request: parse notification raised Braintree::InvalidSignature' do
    logger = mock('logger')
    logger.expects(:error).with('Invalid webhook request signature')
    Services::Braintree::Payment.any_instance.stubs(:logger).returns(logger)
    post :create
    assert_response :bad_request
  end

  test 'parse notification raises StandardError' do
    logger = mock('logger')
    logger.expects(:error)
    Services::Braintree::Payment.any_instance.stubs(:logger).returns(logger)
    gateway = mock('gateway')
    parse = mock('parse')
    parse.expects(:parse).raises(StandardError.new)
    gateway.expects(:webhook_notification).returns(parse)
    Services::Braintree::Payment.any_instance.stubs(:gateway).returns(gateway)
    post :create
    assert_response :success
  end

  test 'subscription canceled' do
    gateway = mock('gateway')
    parse = mock('parse')
    parse.expects(:parse)
         .with('signature', 'payload')
         .returns(
           stub(
             kind: Braintree::WebhookNotification::Kind::SubscriptionCanceled,
             subscription: 'subscription',
             timestamp: 'timestamp'
           )
         )
    gateway.expects(:webhook_notification).returns(parse)
    Services::Braintree::Payment.any_instance.stubs(:gateway).returns(gateway)
    Services::Braintree::SubscriptionUpdateProcessor.expects(:call).with('subscription')
    Services::Braintree::SubscriptionInvoiceProcessor.expects(:call).never
    post :create, bt_signature: 'signature', bt_payload: 'payload'
    assert_response :success
  end

  test 'subscription expired' do
    gateway = mock('gateway')
    parse = mock('parse')
    parse.expects(:parse)
         .with('signature', 'payload')
         .returns(
           stub(
             kind: Braintree::WebhookNotification::Kind::SubscriptionExpired,
             subscription: 'subscription',
             timestamp: 'timestamp'
           )
         )
    gateway.expects(:webhook_notification).returns(parse)
    Services::Braintree::Payment.any_instance.stubs(:gateway).returns(gateway)
    Services::Braintree::SubscriptionUpdateProcessor.expects(:call).with('subscription')
    Services::Braintree::SubscriptionInvoiceProcessor.expects(:call).never
    post :create, bt_signature: 'signature', bt_payload: 'payload'
    assert_response :success
  end

  test 'subscription went active' do
    gateway = mock('gateway')
    parse = mock('parse')
    parse.expects(:parse)
         .with('signature', 'payload')
         .returns(
           stub(
             kind: Braintree::WebhookNotification::Kind::SubscriptionWentActive,
             subscription: 'subscription',
             timestamp: 'timestamp'
           )
         )
    gateway.expects(:webhook_notification).returns(parse)
    Services::Braintree::Payment.any_instance.stubs(:gateway).returns(gateway)
    Services::Braintree::SubscriptionUpdateProcessor.expects(:call).with('subscription')
    Services::Braintree::SubscriptionInvoiceProcessor.expects(:call).never
    post :create, bt_signature: 'signature', bt_payload: 'payload'
    assert_response :success
  end

  test 'subscription went past due' do
    gateway = mock('gateway')
    parse = mock('parse')
    parse.expects(:parse)
         .with('signature', 'payload')
         .returns(
           stub(
             kind: Braintree::WebhookNotification::Kind::SubscriptionWentPastDue,
             subscription: 'subscription',
             timestamp: 'timestamp'
           )
         )
    gateway.expects(:webhook_notification).returns(parse)
    Services::Braintree::Payment.any_instance.stubs(:gateway).returns(gateway)
    Services::Braintree::SubscriptionUpdateProcessor.expects(:call).with('subscription')
    Services::Braintree::SubscriptionInvoiceProcessor.expects(:call).never
    post :create, bt_signature: 'signature', bt_payload: 'payload'
    assert_response :success
  end

  test 'subscription charged successfully' do
    gateway = mock('gateway')
    parse = mock('parse')
    parse.expects(:parse)
         .with('signature', 'payload')
         .returns(
           stub(
             kind: Braintree::WebhookNotification::Kind::SubscriptionChargedSuccessfully,
             subscription: 'subscription',
             timestamp: 'timestamp'
           )
         )
    gateway.expects(:webhook_notification).returns(parse)
    Services::Braintree::Payment.any_instance.stubs(:gateway).returns(gateway)
    Services::Braintree::SubscriptionUpdateProcessor.expects(:call).with('subscription')
    Services::Braintree::SubscriptionInvoiceProcessor.expects(:call)
    post :create, bt_signature: 'signature', bt_payload: 'payload'
    assert_response :success
  end

  test 'subscription charged unsuccessfully' do
    gateway = mock('gateway')
    parse = mock('parse')
    parse.expects(:parse)
         .with('signature', 'payload')
         .returns(
           stub(
             kind: Braintree::WebhookNotification::Kind::SubscriptionChargedUnsuccessfully,
             subscription: 'subscription',
             timestamp: 'timestamp'
           )
         )
    gateway.expects(:webhook_notification).returns(parse)
    Services::Braintree::Payment.any_instance.stubs(:gateway).returns(gateway)
    Services::Braintree::SubscriptionUpdateProcessor.expects(:call).with('subscription')
    Services::Braintree::SubscriptionInvoiceProcessor.expects(:call)
    post :create, bt_signature: 'signature', bt_payload: 'payload'
    assert_response :success
  end

  test 'payment method revoked by customer' do
    payment_method = create(:braintree_payment_method)
    bt_subscription = create(
      :braintree_subscription, braintree_payment_method: payment_method, user: payment_method.user
    )
    gateway = mock('gateway')
    parse = mock('parse')
    parse.expects(:parse)
         .with('signature', 'payload')
         .returns(
           stub(
             kind: Braintree::WebhookNotification::Kind::PaymentMethodRevokedByCustomer,
             subscription: stub(id: bt_subscription.subscription_id),
             timestamp: 'timestamp'
           )
         )
    gateway.expects(:webhook_notification).returns(parse)
    Services::Braintree::Payment.any_instance.stubs(:gateway).returns(gateway)
    Services::Braintree::SubscriptionUpdateProcessor.expects(:call).never
    Services::Braintree::SubscriptionInvoiceProcessor.expects(:call).never
    post :create, bt_signature: 'signature', bt_payload: 'payload'
    assert_response :success
    payment_method.reload
    assert payment_method.deleted?
  end

  test 'payment method revoked by customer with not found subscription' do
    gateway = mock('gateway')
    parse = mock('parse')
    parse.expects(:parse)
         .with('signature', 'payload')
         .returns(
           stub(
             kind: Braintree::WebhookNotification::Kind::PaymentMethodRevokedByCustomer,
             subscription: stub(id: 'subscription_id'),
             timestamp: 'timestamp'
           )
         )
    gateway.expects(:webhook_notification).returns(parse)
    Services::Braintree::Payment.any_instance.stubs(:gateway).returns(gateway)
    Services::Braintree::SubscriptionUpdateProcessor.expects(:call).never
    Services::Braintree::SubscriptionInvoiceProcessor.expects(:call).never
    logger = mock('logger')
    logger.expects(:info)
    logger.expects(:error)
    Services::Braintree::Payment.any_instance.stubs(:logger).returns(logger)
    post :create, bt_signature: 'signature', bt_payload: 'payload'
    assert_response :success
  end
end
