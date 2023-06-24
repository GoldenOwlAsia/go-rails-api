module API
  module V1
    module Users
      class SessionsController < BaseController
        skip_before_action :authenticate_user!, only: :create

        def create
          strategy = {
            email: Auth::Local.new
          }[user_params[:provider]&.to_sym]

          unless strategy
            render_api_error(APIError::BadRequestError.new('Provider is invalid'))
            return
          end

          user = Auth::LoginUserService.call(user_params, strategy)
          render_resource(user, view: :auth)
        end

        private

        def user_params
          params.require(:user).permit(:provider, :email, :password)
        end
      end
    end
  end
end
