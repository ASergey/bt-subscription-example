class Services::Braintree::Payment
  include Services::Concerns::Service
  include Services::Concerns::Braintree

  def client_token(customer_id: nil)
    return gateway.client_token.generate(customer_id: customer_id) if customer_id.present?
    gateway.client_token.generate
  rescue StandardError => e
    logger.error "#{self.class}. Reason: #{e.message}; Backtrace: #{e.backtrace}"
    nil
  end

  def payment_method_nonce(payment_method_token)
    result = gateway.payment_method_nonce.create(payment_method_token)
    return result.payment_method_nonce.nonce if result.success?
    logger.error "#{self.class}. Reason: #{result.errors.first.message}"
    nil
  end

  def sale(amount:, nonce:)
    pay = gateway.transaction.sale(
      amount: amount,
      payment_method_nonce: nonce,
      options: { submit_for_settlement: true }
    )
    return pay.transaction if pay.success?
    nil
  end
end
