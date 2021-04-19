require 'test_helper'

class SubscriptionTest < ActiveSupport::TestCase
  setup do
    Setting.stubs(:membership_release_date).returns(5.days.ago.to_date)
  end

  test 'subscription entity exists' do
    payment_method = create(:braintree_payment_method)
    create(:braintree_subscription, braintree_payment_method: payment_method)
    Services::Braintree::Subscription.any_instance.expects(:logger).never
    MembershipMailer.expects(:join_play_confirmation).never
    MembershipMailer.expects(:sessions_posted_fyi).never

    result = Services::Braintree::Subscription.new.call(
      payment_method: payment_method, payment_nonce: 'nonce', plan_id: 'monthly_plan'
    )
    assert_includes result, :error
    assert_equal I18n.t('membership.subscription.exists'), result[:error]
    UserRoleSubscriptionJob.expects(:perform_later).never
  end

  test 'creates subscription with success' do
    payment_method = create(:braintree_payment_method)
    subscription = mock('subscription')
    subscription.expects(:create).with(
      payment_method_token: payment_method.payment_token,
      plan_id: 'monthly_plan'
    ).returns(stub(
                success?: true,
                subscription: stub(
                  id: 'subscription_id',
                  billing_day_of_month: 8,
                  status: BraintreeSubscription::STATUS_ACTIVE,
                  first_billing_date: Time.current.to_date,
                  next_billing_date: 30.days.from_now.to_date,
                  price: 35.0,
                  plan_id: 'monthly_plan',
                  balance: 0.0,
                  billing_period_start_date: Date.current,
                  billing_period_end_date: 1.month.from_now.to_date,
                  paid_through_date: 1.month.from_now.to_date,
                  next_billing_period_amount: 35.0,
                  days_past_due:              0,
                  current_billing_cycle:      1
                )
    ))
    Braintree::Gateway.any_instance.stubs(:subscription).returns(subscription)
    Services::Braintree::Subscription.any_instance.expects(logger: stub(:error)).never
    UserRoleSubscriptionJob.expects(:perform_later)
    MembershipMailer.expects(:join_play_confirmation).returns(stub(:deliver_later))
    MembershipMailer.expects(:sessions_posted_fyi).never

    assert_difference('BraintreeSubscription.count') do
      assert Services::Braintree::Subscription.new.call(
        payment_method: payment_method, plan_id: 'monthly_plan'
      )
    end
    bt_subscription = BraintreeSubscription.order(id: :desc).first
    assert_equal payment_method.id, bt_subscription.braintree_payment_method_id
    assert_equal 'monthly_plan', bt_subscription.plan_id
    assert_equal 'subscription_id', bt_subscription.subscription_id
    assert_equal 8, bt_subscription.billing_day_of_month
    assert_equal BraintreeSubscription::STATUS_ACTIVE, bt_subscription.status
    assert_equal Time.current.to_date, bt_subscription.first_billing_date
    assert_equal 30.days.from_now.to_date, bt_subscription.next_billing_date
    assert_equal 35.0, bt_subscription.price
    assert_equal 0.0, bt_subscription.balance
    assert_equal Date.current, bt_subscription.billing_period_start_date
    assert_equal 1.month.from_now.to_date, bt_subscription.billing_period_end_date
    assert_equal 1.month.from_now.to_date, bt_subscription.paid_through_date
    assert_equal 35.0, bt_subscription.next_billing_period_amount
    assert_equal 0, bt_subscription.days_past_due
    assert_equal 1, bt_subscription.current_billing_cycle
  end

  test 'creates subscription sends sessions_posted_fyi email' do
    subscription = mock('subscription')
    subscription.expects(:create).with(
      payment_method_token: 'token',
      plan_id: 'monthly_plan'
    ).returns(stub(
                success?: true,
                subscription: stub(
                  id: 'subscription_id',
                  billing_day_of_month: 8,
                  status: BraintreeSubscription::STATUS_ACTIVE,
                  first_billing_date: Time.current.to_date,
                  next_billing_date: 30.days.from_now.to_date,
                  price: 35.0,
                  plan_id: 'monthly_plan',
                  balance: 0.0,
                  billing_period_start_date: Date.current,
                  billing_period_end_date: 1.month.from_now.to_date,
                  paid_through_date: 1.month.from_now.to_date,
                  next_billing_period_amount: 35.0,
                  days_past_due:              0,
                  current_billing_cycle:      1
                )
    ))
    Braintree::Gateway.any_instance.stubs(:subscription).returns(subscription)
    Services::Braintree::Subscription.any_instance.expects(logger: stub(:error)).never
    UserRoleSubscriptionJob.expects(:perform_later)
    ZumbiniClass.any_instance.stubs(:prepare_data_before_save).returns(true)
    MembershipMailer.expects(:join_play_confirmation).returns(stub(:deliver_later))
    MembershipMailer.expects(:sessions_posted_fyi).returns(stub(:deliver_later))

    zumbini_class = create(
      :zumbini_class_first_party,
      status: ClassStatus::ACTIVE,
      created_at: Setting.membership_release_date - 2.days
    )
    payment_method = create(:braintree_payment_method, user: zumbini_class.user, payment_token: 'token')
    assert_difference('BraintreeSubscription.count') do
      assert Services::Braintree::Subscription.new.call(
        payment_method: payment_method, plan_id: 'monthly_plan'
      )
    end
  end

  test 'creates subscription does not send sessions_posted_fyi email' do
    subscription = mock('subscription')
    subscription.expects(:create).with(
      payment_method_token: 'token',
      plan_id: 'monthly_plan'
    ).returns(stub(
                success?: true,
                subscription: stub(
                  id: 'subscription_id',
                  billing_day_of_month: 8,
                  status: BraintreeSubscription::STATUS_ACTIVE,
                  first_billing_date: Time.current.to_date,
                  next_billing_date: 30.days.from_now.to_date,
                  price: 35.0,
                  plan_id: 'monthly_plan',
                  balance: 0.0,
                  billing_period_start_date: Date.current,
                  billing_period_end_date: 1.month.from_now.to_date,
                  paid_through_date: 1.month.from_now.to_date,
                  next_billing_period_amount: 35.0,
                  days_past_due:              0,
                  current_billing_cycle:      1
                )
    ))
    Braintree::Gateway.any_instance.stubs(:subscription).returns(subscription)
    Services::Braintree::Subscription.any_instance.expects(logger: stub(:error)).never
    UserRoleSubscriptionJob.expects(:perform_later)
    ZumbiniClass.any_instance.stubs(:prepare_data_before_save).returns(true)
    MembershipMailer.expects(:join_play_confirmation).returns(stub(:deliver_later))
    MembershipMailer.expects(:sessions_posted_fyi).never

    zumbini_class = create(:zumbini_class_first_party, status: ClassStatus::ACTIVE)
    payment_method = create(:braintree_payment_method, user: zumbini_class.user, payment_token: 'token')
    assert_difference('BraintreeSubscription.count') do
      assert Services::Braintree::Subscription.new.call(
        payment_method: payment_method, plan_id: 'monthly_plan'
      )
    end
  end

  test 'creates subscription with new payment method' do
    user = create(:user_zin)
    subscription = mock('subscription')
    subscription.expects(:create).with(
      payment_method_token: 'payment_method_token',
      plan_id: 'monthly_plan'
    ).returns(stub(
                success?: true,
                subscription: stub(
                  id: 'subscription_id',
                  billing_day_of_month: 8,
                  status: BraintreeSubscription::STATUS_ACTIVE,
                  first_billing_date: Time.current.to_date,
                  next_billing_date: 30.days.from_now.to_date,
                  price: 35.0,
                  plan_id: 'monthly_plan',
                  balance: 0.0,
                  billing_period_start_date: Date.current,
                  billing_period_end_date: 1.month.from_now.to_date,
                  paid_through_date: 1.month.from_now.to_date,
                  next_billing_period_amount: 35.0,
                  days_past_due:              0,
                  current_billing_cycle:      1
                )
    ))
    Braintree::Gateway.any_instance.stubs(:subscription).returns(subscription)
    Services::Braintree::Subscription.any_instance.expects(logger: stub(:error)).never
    UserRoleSubscriptionJob.expects(:perform_later).with(has_entry(user_id: user.id))
    MembershipMailer.expects(:join_play_confirmation).returns(stub(:deliver_later))
    MembershipMailer.expects(:sessions_posted_fyi).never

    payment_method1 = create(:braintree_payment_method, user: user, payment_token: 'payment_token1')
    payment_method2 = create(:braintree_payment_method, user: user, payment_token: 'payment_token2')
    payment_method = create(:braintree_payment_method, user: user, payment_token: 'payment_method_token')

    assert_difference('BraintreeSubscription.count') do
      assert Services::Braintree::Subscription.new.call(
        payment_method: payment_method, plan_id: 'monthly_plan'
      )
    end
    bt_subscription = BraintreeSubscription.order(id: :desc).first
    assert_equal payment_method.id, bt_subscription.braintree_payment_method_id
    assert_equal 'monthly_plan', bt_subscription.plan_id
    assert_equal 'subscription_id', bt_subscription.subscription_id
    assert_equal 8, bt_subscription.billing_day_of_month
    assert_equal BraintreeSubscription::STATUS_ACTIVE, bt_subscription.status
    assert_equal Time.current.to_date, bt_subscription.first_billing_date
    assert_equal 30.days.from_now.to_date, bt_subscription.next_billing_date
    assert_equal 35.0, bt_subscription.price
    assert_equal 0.0, bt_subscription.balance
    assert_equal Date.current, bt_subscription.billing_period_start_date
    assert_equal 1.month.from_now.to_date, bt_subscription.billing_period_end_date
    assert_equal 1.month.from_now.to_date, bt_subscription.paid_through_date
    assert_equal 35.0, bt_subscription.next_billing_period_amount
    assert_equal 0, bt_subscription.days_past_due
    assert_equal 1, bt_subscription.current_billing_cycle
    payment_method1.reload
    payment_method2.reload
    assert_equal payment_method.id, bt_subscription.braintree_payment_method_id
    assert payment_method1.deleted?
    assert payment_method2.deleted?
  end

  test 'create when canceled subscription has unexpired membership period' do
    subscription = mock('subscription')
    subscription.expects(:create).with(
      payment_method_token: 'token',
      plan_id: 'monthly_plan',
      first_billing_date: 20.days.from_now.to_date
    ).returns(stub(
                success?: true,
                subscription: stub(
                  id: 'subscription_id',
                  billing_day_of_month: 10,
                  status: BraintreeSubscription::STATUS_PENDING,
                  first_billing_date: 20.days.from_now.to_date,
                  next_billing_date: 20.days.from_now.to_date,
                  price: 35.0,
                  plan_id: 'monthly_plan',
                  balance: 0.0,
                  billing_period_start_date: Date.current,
                  billing_period_end_date: 1.month.from_now.to_date,
                  paid_through_date: 1.month.from_now.to_date,
                  next_billing_period_amount: 35.0,
                  days_past_due:              0,
                  current_billing_cycle:      1
                )
    ))
    Braintree::Gateway.any_instance.stubs(:subscription).returns(subscription)
    Services::Braintree::Subscription.any_instance.expects(logger: stub(:error)).never
    UserRoleSubscriptionJob.expects(:perform_later)
    MembershipMailer.expects(:join_play_confirmation).returns(stub(:deliver_later))
    MembershipMailer.expects(:sessions_posted_fyi).never

    payment_method = create(:braintree_payment_method, payment_token: 'token')
    create(
      :braintree_subscription,
      braintree_payment_method: payment_method,
      status: BraintreeSubscription::STATUS_CANCELED,
      next_billing_date: 20.days.from_now.to_date,
      user: payment_method.user
    )
    assert_difference('BraintreeSubscription.count') do
      assert Services::Braintree::Subscription.new.call(
        payment_method: payment_method, plan_id: 'monthly_plan'
      )
    end
    bt_subscription = BraintreeSubscription.order(id: :desc).first
    assert_equal payment_method.id, bt_subscription.braintree_payment_method_id
    assert_equal 'monthly_plan', bt_subscription.plan_id
    assert_equal 'subscription_id', bt_subscription.subscription_id
    assert_equal 10, bt_subscription.billing_day_of_month
    assert_equal BraintreeSubscription::STATUS_PENDING, bt_subscription.status
    assert_equal 20.days.from_now.to_date, bt_subscription.first_billing_date
    assert_equal 20.days.from_now.to_date, bt_subscription.next_billing_date
    assert_equal 35.0, bt_subscription.price
    assert_equal 0.0, bt_subscription.balance
    assert_equal Date.current, bt_subscription.billing_period_start_date
    assert_equal 1.month.from_now.to_date, bt_subscription.billing_period_end_date
    assert_equal 1.month.from_now.to_date, bt_subscription.paid_through_date
    assert_equal 35.0, bt_subscription.next_billing_period_amount
    assert_equal 0, bt_subscription.days_past_due
    assert_equal 1, bt_subscription.current_billing_cycle
  end

  test 'create when canceled subscription has expired membership period' do
    payment_method = create(:braintree_payment_method)
    create(
      :braintree_subscription,
      braintree_payment_method: payment_method,
      status: BraintreeSubscription::STATUS_CANCELED,
      next_billing_date: 20.days.ago.to_date
    )
    subscription = mock('subscription')
    subscription.expects(:create).with(
      payment_method_token: payment_method.payment_token,
      plan_id: 'monthly_plan'
    ).returns(stub(
                success?: true,
                subscription: stub(
                  id: 'subscription_id',
                  billing_day_of_month: 10,
                  status: BraintreeSubscription::STATUS_ACTIVE,
                  first_billing_date: Time.current.to_date,
                  next_billing_date: 30.days.from_now.to_date,
                  price: 35.0,
                  plan_id: 'monthly_plan',
                  balance: 0.0,
                  billing_period_start_date: Date.current,
                  billing_period_end_date: 1.month.from_now.to_date,
                  paid_through_date: 1.month.from_now.to_date,
                  next_billing_period_amount: 35.0,
                  days_past_due:              0,
                  current_billing_cycle:      1
                )
    ))
    Braintree::Gateway.any_instance.stubs(:subscription).returns(subscription)
    Services::Braintree::Subscription.any_instance.expects(logger: stub(:error)).never
    MembershipMailer.expects(:join_play_confirmation).returns(stub(:deliver_later))
    MembershipMailer.expects(:sessions_posted_fyi).never

    assert_difference('BraintreeSubscription.count') do
      assert Services::Braintree::Subscription.new.call(
        payment_method: payment_method, plan_id: 'monthly_plan'
      )
    end
    bt_subscription = BraintreeSubscription.order(id: :desc).first
    assert_equal payment_method.id, bt_subscription.braintree_payment_method_id
    assert_equal 'monthly_plan', bt_subscription.plan_id
    assert_equal 'subscription_id', bt_subscription.subscription_id
    assert_equal 10, bt_subscription.billing_day_of_month
    assert_equal BraintreeSubscription::STATUS_ACTIVE, bt_subscription.status
    assert_equal Time.current.to_date, bt_subscription.first_billing_date
    assert_equal 30.days.from_now.to_date, bt_subscription.next_billing_date
    assert_equal 35.0, bt_subscription.price
    assert_equal 0.0, bt_subscription.balance
    assert_equal Date.current, bt_subscription.billing_period_start_date
    assert_equal 1.month.from_now.to_date, bt_subscription.billing_period_end_date
    assert_equal 1.month.from_now.to_date, bt_subscription.paid_through_date
    assert_equal 35.0, bt_subscription.next_billing_period_amount
    assert_equal 0, bt_subscription.days_past_due
    assert_equal 1, bt_subscription.current_billing_cycle
  end

  test 'create subscription responds with error' do
    payment_method = create(:braintree_payment_method)
    subscription = mock('subscription')
    subscription.expects(:create).with(
      payment_method_token: payment_method.payment_token,
      plan_id: 'monthly_plan'
    ).returns(stub(
                success?: false,
                errors: [stub(message: 'error_message')]
    ))

    Braintree::Gateway.any_instance.stubs(:subscription).returns(subscription)
    Services::Braintree::Subscription.any_instance.expects(logger: stub(:error))
    MembershipMailer.expects(:join_play_confirmation).never
    MembershipMailer.expects(:sessions_posted_fyi).never

    result = Services::Braintree::Subscription.new.call(
      payment_method: payment_method, plan_id: 'monthly_plan'
    )
    assert_includes result, :error
    assert_equal I18n.t('membership.subscription.create_failed'), result[:error]
  end

  test 'subscription create request raises error' do
    payment_method = create(:braintree_payment_method)
    subscription = mock('subscription')
    subscription.expects(:create).raises(StandardError.new('Test error'))

    Braintree::Gateway.any_instance.stubs(:subscription).returns(subscription)
    Services::Braintree::Subscription.any_instance.expects(logger: stub(:error))
    MembershipMailer.expects(:join_play_confirmation).never
    MembershipMailer.expects(:sessions_posted_fyi).never

    result = Services::Braintree::Subscription.new.call(
      payment_method: payment_method, plan_id: 'monthly_plan'
    )
    assert_includes result, :error
    assert_equal I18n.t('membership.subscription.create_failed'), result[:error]
  end

  test 'create subscription save transaction fails' do
    user = create(:user_zin)
    payment_method1 = create(:braintree_payment_method, user: user, payment_token: 'payment_token1')
    payment_method = create(:braintree_payment_method, user: user)
    subscription = mock('subscription')
    subscription.expects(:create).with(
      payment_method_token: payment_method.payment_token,
      plan_id: 'monthly_plan'
    ).returns(stub(
                success?: true,
                subscription: stub(
                  id: 'subscription_id',
                  billing_day_of_month: 8,
                  status: BraintreeSubscription::STATUS_ACTIVE,
                  first_billing_date: Time.current.to_date,
                  next_billing_date: 30.days.from_now.to_date,
                  price: 35.0,
                  plan_id: 'monthly_plan',
                  balance: 0.0,
                  billing_period_start_date: Date.current,
                  billing_period_end_date: 1.month.from_now.to_date,
                  paid_through_date: 1.month.from_now.to_date,
                  next_billing_period_amount: 35.0,
                  days_past_due:              0,
                  current_billing_cycle:      1
                )
    ))
    Braintree::Gateway.any_instance.stubs(:subscription).returns(subscription)
    Services::Braintree::Subscription.any_instance.expects(logger: stub(:error))
    UserRoleSubscriptionJob.expects(:perform_later).never
    MembershipMailer.expects(:join_play_confirmation).never
    MembershipMailer.expects(:sessions_posted_fyi).never
    BraintreeSubscription.any_instance.expects(:save!).raises(StandardError.new('Save fails'))

    assert_no_difference('BraintreeSubscription.count') do
      result = Services::Braintree::Subscription.new.call(
        payment_method: payment_method, plan_id: 'monthly_plan'
      )
      assert_includes result, :error
      assert_equal I18n.t('membership.subscription.create_failed'), result[:error]
    end
    payment_method1.reload
    assert_not payment_method1.deleted?
  end

  test 'cancel with unavailable subscription' do
    subscription = create(
      :braintree_subscription,
      status: BraintreeSubscription::STATUS_CANCELED
    )
    Services::Braintree::Subscription.any_instance.expects(logger: stub(:error))
    Braintree::Gateway.any_instance.expects(:subscription).never
    assert_not Services::Braintree::Subscription.new.cancel(subscription)
  end

  test 'mark_canceled with unavailable subscription' do
    subscription = create(
      :braintree_subscription,
      status: BraintreeSubscription::STATUS_CANCELED
    )
    Services::Braintree::Subscription.any_instance.expects(logger: stub(:error))
    Braintree::Gateway.any_instance.expects(:subscription).never
    Services::Braintree::Subscription.any_instance.expects(:cancel).never
    assert_not Services::Braintree::Subscription.new.mark_canceled(subscription)
  end

  test 'mark_canceled with past_due subscription' do
    subscription = create(
      :braintree_subscription,
      status: BraintreeSubscription::STATUS_PAST_DUE
    )
    Services::Braintree::Subscription.any_instance.expects(logger: stub(:error)).never
    Braintree::Gateway.any_instance.expects(:subscription).never
    Services::Braintree::Subscription.any_instance.expects(:cancel).never
    assert Services::Braintree::Subscription.new.mark_canceled(subscription)
    subscription.reload
    assert_equal BraintreeSubscription::STATUS_PAST_DUE, subscription.status
    assert_equal (subscription.first_billing_date + 1.year).to_date, subscription.cancel_date
  end

  test 'cancel subscription request raises error' do
    subscription = create(
      :braintree_subscription,
      status: BraintreeSubscription::STATUS_PENDING
    )
    gateway_subscription = mock('subscription')
    gateway_subscription.expects(:cancel)
                        .with(subscription.subscription_id)
                        .raises(StandardError.new('Test error'))

    Braintree::Gateway.any_instance.stubs(:subscription).returns(gateway_subscription)
    Services::Braintree::Subscription.any_instance.expects(logger: stub(:error))

    assert_not Services::Braintree::Subscription.new.cancel(subscription)
    subscription.reload
    assert_equal BraintreeSubscription::STATUS_PENDING, subscription.status
  end

  test 'cancel subscription' do
    subscription = create(
      :braintree_subscription,
      status: BraintreeSubscription::STATUS_ACTIVE
    )
    gateway_subscription = mock('subscription')
    gateway_subscription.expects(:cancel)
                        .with(subscription.subscription_id)
                        .returns(stub(success?: true))
    Braintree::Gateway.any_instance.stubs(:subscription).returns(gateway_subscription)
    Services::Braintree::Subscription.any_instance.expects(logger: stub(:error)).never

    assert Services::Braintree::Subscription.new.cancel(subscription)
    subscription.reload
    assert_equal BraintreeSubscription::STATUS_CANCELED, subscription.status
  end

  test 'mark_canceled subscription with cancel_date present' do
    subscription = create(
      :braintree_subscription,
      status: BraintreeSubscription::STATUS_PENDING,
      cancel_date: 1.year.from_now.to_date
    )
    Services::Braintree::Subscription.any_instance.expects(logger: stub(:error)).never
    Services::Braintree::Subscription.any_instance.expects(:cancel).never

    assert_not Services::Braintree::Subscription.new.mark_canceled(subscription)
    subscription.reload
    assert_equal BraintreeSubscription::STATUS_PENDING, subscription.status
  end

  test 'mark_canceled subscription with today cancel_date present' do
    subscription = create(
      :braintree_subscription,
      status: BraintreeSubscription::STATUS_PENDING,
      cancel_date: Date.current
    )
    Services::Braintree::Subscription.any_instance.expects(logger: stub(:error)).never
    Services::Braintree::Subscription.any_instance.expects(:cancel).with(subscription).returns(true)

    assert Services::Braintree::Subscription.new.mark_canceled(subscription)
    subscription.reload
    assert_equal BraintreeSubscription::STATUS_PENDING, subscription.status
  end

  test 'mark_canceled subscription' do
    subscription = create(
      :braintree_subscription,
      status: BraintreeSubscription::STATUS_PENDING,
      first_billing_date: Date.current
    )
    Services::Braintree::Subscription.any_instance.expects(logger: stub(:error)).never
    Services::Braintree::Subscription.any_instance.expects(:cancel).never

    assert Services::Braintree::Subscription.new.mark_canceled(subscription)
    subscription.reload
    assert_equal 1.year.from_now.to_date, subscription.cancel_date.to_date
  end

  test 'update subscription not found' do
    Braintree::Gateway.any_instance.expects(:subscription).never
    Services::Braintree::Subscription.any_instance.expects(logger: stub(:error))
    subscription = create(
      :braintree_subscription,
      status: BraintreeSubscription::STATUS_EXPIRED
    )

    result = Services::Braintree::Subscription.new.update(
      subscription: subscription, payment_nonce: 'test_nonce', payment_token: 'new_payment_token'
    )
    assert_equal I18n.t('membership.subscription.update_failed'), result[:error]
  end

  test 'update subscription fails' do
    user = create(:user_zin)
    create(:braintree_payment_method, user: user, payment_token: 'new_payment_token')
    subscription = create(
      :braintree_subscription,
      status: BraintreeSubscription::STATUS_PENDING,
      user: user,
      braintree_payment_method: create(:braintree_payment_method, user: user)
    )
    gateway_subscription = mock('subscription')
    gateway_subscription.expects(:update)
                        .with(subscription.subscription_id, payment_method_token: 'new_payment_token')
                        .returns(stub(success?: false, errors: [stub(message: 'error_message')]))

    Braintree::Gateway.any_instance.expects(:subscription).returns(gateway_subscription)
    Services::Braintree::Subscription.any_instance.expects(logger: stub(:error))

    result = Services::Braintree::Subscription.new.update(
      subscription: subscription, payment_nonce: 'test_nonce', payment_token: 'new_payment_token'
    )
    assert_equal I18n.t('membership.subscription.update_failed'), result[:error]
  end

  test 'update subscription without new payment method fails' do
    subscription = create(:braintree_subscription, status: BraintreeSubscription::STATUS_ACTIVE)
    Braintree::Gateway.any_instance.expects(:subscription).never
    Services::Braintree::Subscription.any_instance.expects(:logger).returns(stub(:error))

    result = Services::Braintree::Subscription.new.update(
      subscription: subscription, payment_nonce: 'test_nonce', payment_token: 'payment_token'
    )
    assert_equal I18n.t('membership.subscription.update_failed'), result[:error]
  end

  test 'update subscription without old payment methods' do
    user = create(:user_zin)
    new_payment_method = create(:braintree_payment_method, user: user, payment_token: 'new_payment_token')
    subscription = create(
      :braintree_subscription,
      status: BraintreeSubscription::STATUS_ACTIVE,
      user: user,
      braintree_payment_method: create(:braintree_payment_method, user: user)
    )
    gateway_subscription = mock('subscription')
    gateway_subscription.expects(:update)
                        .with(subscription.subscription_id, payment_method_token: 'new_payment_token')
                        .returns(stub(success?: true))

    Braintree::Gateway.any_instance.expects(:subscription).returns(gateway_subscription)
    Services::Braintree::Subscription.any_instance.expects(:logger).never

    assert Services::Braintree::Subscription.new.update(
      subscription: subscription, payment_nonce: 'test_nonce', payment_token: 'new_payment_token'
    )
    subscription.reload
    assert_equal new_payment_method.id, subscription.braintree_payment_method_id
    assert_equal 'new_payment_token', subscription.braintree_payment_method.payment_token
    assert_equal 2, user.braintree_payment_methods.count
  end

  test 'update subscription with old payment methods' do
    user = create(:user_zin)
    payment_method1 = create(:braintree_payment_method, user: user, payment_token: 'payment_token1')
    payment_method2 = create(:braintree_payment_method, user: user, payment_token: 'payment_token2')
    new_payment_method = create(:braintree_payment_method, user: user, payment_token: 'new_payment_token')
    subscription = create(
      :braintree_subscription,
      status: BraintreeSubscription::STATUS_PAST_DUE,
      user: user,
      braintree_payment_method: payment_method2
    )
    gateway_subscription = mock('subscription')
    gateway_subscription.expects(:update)
                        .with(subscription.subscription_id, payment_method_token: 'new_payment_token')
                        .returns(stub(success?: true))

    Braintree::Gateway.any_instance.expects(:subscription).returns(gateway_subscription)
    Services::Braintree::Subscription.any_instance.expects(:logger).never

    assert Services::Braintree::Subscription.new.update(
      subscription: subscription, payment_nonce: 'test_nonce', payment_token: 'new_payment_token'
    )
    subscription.reload
    payment_method1.reload
    payment_method2.reload
    assert_equal new_payment_method.id, subscription.braintree_payment_method_id
    assert payment_method1.deleted?
    assert payment_method2.deleted?
  end

  test 'create_params without nonce' do
    payment_method = create(:braintree_payment_method)
    create_params = Services::Braintree::Subscription.new.send(
      :create_params, payment_method: payment_method, plan_id: 'monthly_plan'
    )
    assert_not_nil create_params[:plan_id]
    assert_equal 'monthly_plan', create_params[:plan_id]
    assert_not_nil create_params[:payment_method_token]
    assert_equal payment_method.payment_token, create_params[:payment_method_token]
    assert_nil create_params[:payment_method_nonce]
    assert_nil create_params[:first_billing_date]
  end

  test 'create_params with nonce' do
    payment_method = create(:braintree_payment_method)
    create_params = Services::Braintree::Subscription.new.send(
      :create_params,
      payment_method: payment_method, payment_nonce: 'nonce', plan_id: 'monthly_plan'
    )
    assert_not_nil create_params[:plan_id]
    assert_equal 'monthly_plan', create_params[:plan_id]
    assert_not_nil create_params[:payment_method_nonce]
    assert_equal 'nonce', create_params[:payment_method_nonce]
    assert_nil create_params[:payment_method_token]
    assert_nil create_params[:first_billing_date]
  end

  test 'create_params with nonce with canceled_before_expired subscription' do
    payment_method = create(:braintree_payment_method)
    previous_subscription = create(
      :braintree_subscription,
      braintree_payment_method: payment_method,
      status: BraintreeSubscription::STATUS_CANCELED,
      next_billing_date: 20.days.from_now.to_date,
      user: payment_method.user
    )
    create_params = Services::Braintree::Subscription.new.send(
      :create_params,
      payment_method: payment_method, payment_nonce: 'nonce', plan_id: 'monthly_plan'
    )
    assert_not_nil create_params[:plan_id]
    assert_equal 'monthly_plan', create_params[:plan_id]
    assert_not_nil create_params[:payment_method_nonce]
    assert_equal 'nonce', create_params[:payment_method_nonce]
    assert_not_nil create_params[:first_billing_date]
    assert_equal previous_subscription.next_billing_date, create_params[:first_billing_date]
    assert_nil create_params[:payment_method_token]
  end

  test 'retry_charge' do
    subscription = create(
      :braintree_subscription,
      status: BraintreeSubscription::STATUS_PAST_DUE,
      date_past_due: 1.week.ago.to_date
    )
    gateway_subscription = mock('subscription')
    gateway_subscription.expects(:retry_charge)
                        .with(subscription.subscription_id, subscription.balance, true)
                        .returns(stub(success?: true))
    Braintree::Gateway.any_instance.expects(:subscription).returns(gateway_subscription)
    Services::Braintree::Subscription.any_instance.expects(:logger).never
    assert Services::Braintree::Subscription.new.retry_charge(subscription)

    subscription.reload
    assert_equal BraintreeSubscription::STATUS_ACTIVE, subscription.status
    assert_nil subscription.date_past_due
  end

  test 'retry_charge fails' do
    subscription = create(
      :braintree_subscription,
      status: BraintreeSubscription::STATUS_PAST_DUE,
      date_past_due: 1.week.ago.to_date
    )
    gateway_subscription = mock('subscription')
    gateway_subscription.expects(:retry_charge)
                        .with(subscription.subscription_id, subscription.balance, true)
                        .returns(stub(success?: false, errors: [stub(message: 'error_message')]))
    Braintree::Gateway.any_instance.expects(:subscription).returns(gateway_subscription)
    Services::Braintree::Subscription.any_instance.expects(:logger).returns(stub(:error))

    result = Services::Braintree::Subscription.new.retry_charge(subscription)
    assert_equal I18n.t('membership.subscription.retry_charge.failed'), result[:error]

    subscription.reload
    assert_equal BraintreeSubscription::STATUS_PAST_DUE, subscription.status
    assert_equal 1.week.ago.to_date, subscription.date_past_due
  end
end
