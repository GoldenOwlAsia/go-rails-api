class ApplicationController < ActionController::API
  include Pundit::Authorization
  include Pagy::Method
  include JSONAPIRender
  include ExceptionFilter
end
