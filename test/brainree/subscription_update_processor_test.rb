require 'test_helper'

class SubscriptionUpdateProcessorTest < ActiveSupport::TestCase
  test 'subscription not found' do
    subscription = stub(id: 'id')
    BraintreeSubscription.any_instance.expects(:update).never
    UserRoleSubscriptionJob.expects(:perform_later).never
    assert_raises(StandardError) do
      Services::Braintree::SubscriptionUpdateProcessor.call(subscription)
    end
  end

  test 'call' do
    bt_subscription = create(:braintree_subscription)
    UserRoleSubscriptionJob.expects(:perform_later).with(
      user_id: bt_subscription.user_id,
      braintree_subscription_id: bt_subscription.id
    )
    Services::Braintree::SubscriptionUpdateProcessor.call(
      stub(
        id:                         bt_subscription.subscription_id,
        plan_id:                    'plan_id',
        balance:                    0.0,
        price:                      35.0,
        status:                     'active',
        billing_day_of_month:       10,
        billing_period_start_date:  Date.current,
        billing_period_end_date:    (1.month.from_now - 1.day).to_date,
        paid_through_date:          (1.month.from_now - 1.day).to_date,
        next_billing_date:          1.month.from_now.to_date,
        next_billing_period_amount: 35.0,
        days_past_due:              0,
        current_billing_cycle:      2
      )
    )
    bt_subscription.reload
    assert_equal 'plan_id', bt_subscription.plan_id
    assert_equal 0.0, bt_subscription.balance
    assert_equal 35.0, bt_subscription.price
    assert_equal 'active', bt_subscription.status
    assert_equal 10, bt_subscription.billing_day_of_month
    assert_equal Date.current, bt_subscription.billing_period_start_date
    assert_equal (1.month.from_now - 1.day).to_date, bt_subscription.billing_period_end_date
    assert_equal (1.month.from_now - 1.day).to_date, bt_subscription.paid_through_date
    assert_equal 1.month.from_now.to_date, bt_subscription.next_billing_date
    assert_equal 35.0, bt_subscription.next_billing_period_amount
    assert_equal 0, bt_subscription.days_past_due
    assert_equal 2, bt_subscription.current_billing_cycle
  end

  test 'call reminder status should not be reset' do
    bt_subscription = create(
      :braintree_subscription,
      status: BraintreeSubscription::STATUS_PAST_DUE,
      reminder_status: Services::Braintree::PastDueReminder.new(build(:braintree_subscription), 7)
                           .send(:build_status, 7)
    )
    UserRoleSubscriptionJob.expects(:perform_later)
    Services::Braintree::SubscriptionUpdateProcessor.call(
      stub(
        id:                         bt_subscription.subscription_id,
        plan_id:                    'plan_id',
        balance:                    0.0,
        price:                      35.0,
        status:                     'past_due',
        billing_day_of_month:       10,
        billing_period_start_date:  Date.current,
        billing_period_end_date:    (1.month.from_now - 1.day).to_date,
        paid_through_date:          (1.month.from_now - 1.day).to_date,
        next_billing_date:          1.month.from_now.to_date,
        next_billing_period_amount: 35.0,
        days_past_due:              0,
        current_billing_cycle:      2
      )
    )
    bt_subscription.reload
    assert_equal(
      Services::Braintree::PastDueReminder.new(build(:braintree_subscription), 7).send(:build_status, 7),
      bt_subscription.reminder_status.symbolize_keys
    )
    assert_equal BraintreeSubscription::STATUS_PAST_DUE, bt_subscription.status
  end

  test 'call reminder status should be reset' do
    bt_subscription = create(
      :braintree_subscription,
      status: BraintreeSubscription::STATUS_PAST_DUE,
      reminder_status: Services::Braintree::PastDueReminder.new(build(:braintree_subscription), 7)
                           .send(:build_status, 7)
    )
    UserRoleSubscriptionJob.expects(:perform_later)
    Services::Braintree::SubscriptionUpdateProcessor.call(
      stub(
        id:                         bt_subscription.subscription_id,
        plan_id:                    'plan_id',
        balance:                    0.0,
        price:                      35.0,
        status:                     'active',
        billing_day_of_month:       10,
        billing_period_start_date:  Date.current,
        billing_period_end_date:    (1.month.from_now - 1.day).to_date,
        paid_through_date:          (1.month.from_now - 1.day).to_date,
        next_billing_date:          1.month.from_now.to_date,
        next_billing_period_amount: 35.0,
        days_past_due:              0,
        current_billing_cycle:      2
      )
    )
    bt_subscription.reload
    assert_equal BraintreeSubscription::STATUS_ACTIVE, bt_subscription.status
    assert_equal({}, bt_subscription.reminder_status)
  end

  test 'call when status was not changed to past_due' do
    bt_subscription = create(:braintree_subscription, status: BraintreeSubscription::STATUS_PENDING)
    UserRoleSubscriptionJob.expects(:perform_later)
    Services::Braintree::SubscriptionUpdateProcessor.call(
      stub(
        id:                         bt_subscription.subscription_id,
        plan_id:                    'plan_id',
        balance:                    0.0,
        price:                      35.0,
        status:                     'active',
        billing_day_of_month:       10,
        billing_period_start_date:  Date.current,
        billing_period_end_date:    (1.month.from_now - 1.day).to_date,
        paid_through_date:          (1.month.from_now - 1.day).to_date,
        next_billing_date:          1.month.from_now.to_date,
        next_billing_period_amount: 35.0,
        days_past_due:              0,
        current_billing_cycle:      2
      )
    )
    bt_subscription.reload
    assert_equal BraintreeSubscription::STATUS_ACTIVE, bt_subscription.status
    assert_nil bt_subscription.date_past_due
  end

  test 'call date_past_due should be reset when changed status is not past_due' do
    bt_subscription = create(
      :braintree_subscription,
      status: BraintreeSubscription::STATUS_PAST_DUE,
      date_past_due: 17.days.ago
    )
    UserRoleSubscriptionJob.expects(:perform_later)
    Services::Braintree::SubscriptionUpdateProcessor.call(
      stub(
        id:                         bt_subscription.subscription_id,
        plan_id:                    'plan_id',
        balance:                    0.0,
        price:                      35.0,
        status:                     'active',
        billing_day_of_month:       10,
        billing_period_start_date:  Date.current,
        billing_period_end_date:    (1.month.from_now - 1.day).to_date,
        paid_through_date:          (1.month.from_now - 1.day).to_date,
        next_billing_date:          1.month.from_now.to_date,
        next_billing_period_amount: 35.0,
        days_past_due:              0,
        current_billing_cycle:      2
      )
    )
    bt_subscription.reload
    assert_equal BraintreeSubscription::STATUS_ACTIVE, bt_subscription.status
    assert_nil bt_subscription.date_past_due
  end

  test 'call date_past_due should be set when status not changed' do
    bt_subscription = create(:braintree_subscription, status: BraintreeSubscription::STATUS_PAST_DUE)
    UserRoleSubscriptionJob.expects(:perform_later)
    Services::Braintree::SubscriptionUpdateProcessor.call(
      stub(
        id:                         bt_subscription.subscription_id,
        plan_id:                    'plan_id',
        balance:                    0.0,
        price:                      35.0,
        status:                     'past_due',
        billing_day_of_month:       10,
        billing_period_start_date:  Date.current,
        billing_period_end_date:    (1.month.from_now - 1.day).to_date,
        paid_through_date:          (1.month.from_now - 1.day).to_date,
        next_billing_date:          1.month.from_now.to_date,
        next_billing_period_amount: 35.0,
        days_past_due:              0,
        current_billing_cycle:      2
      )
    )
    bt_subscription.reload
    assert_equal BraintreeSubscription::STATUS_PAST_DUE, bt_subscription.status
    assert_nil bt_subscription.date_past_due
  end

  test 'call date_past_due should be set' do
    bt_subscription = create(:braintree_subscription, status: BraintreeSubscription::STATUS_ACTIVE)
    UserRoleSubscriptionJob.expects(:perform_later)
    Services::Braintree::SubscriptionUpdateProcessor.call(
      stub(
        id:                         bt_subscription.subscription_id,
        plan_id:                    'plan_id',
        balance:                    0.0,
        price:                      35.0,
        status:                     'past_due',
        billing_day_of_month:       10,
        billing_period_start_date:  Date.current,
        billing_period_end_date:    (1.month.from_now - 1.day).to_date,
        paid_through_date:          (1.month.from_now - 1.day).to_date,
        next_billing_date:          1.month.from_now.to_date,
        next_billing_period_amount: 35.0,
        days_past_due:              0,
        current_billing_cycle:      2
      )
    )
    bt_subscription.reload
    assert_equal BraintreeSubscription::STATUS_PAST_DUE, bt_subscription.status
    assert_equal Date.current, bt_subscription.date_past_due
  end
end
