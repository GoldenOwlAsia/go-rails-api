module APIError
  class TooManyRequestsError < StandardError
    def initialize(message = nil)
      super(
        message: message || 'Too many requests, please try again later',
        status: 429
      )
    end
  end
end
