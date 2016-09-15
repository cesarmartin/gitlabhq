class JwtController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :verify_authenticity_token
  before_action :authenticate_project_or_user

  SERVICES = {
    Auth::ContainerRegistryAuthenticationService::AUDIENCE => Auth::ContainerRegistryAuthenticationService,
  }

  def auth
    service = SERVICES[params[:service]]
    return head :not_found unless service

    @authentication_result ||= Gitlab::Auth::Result.new

    result = service.new(@authentication_result.project, @authentication_result.actor, auth_params).
      execute(capabilities: @authentication_result.capabilities)

    render json: result, status: result[:http_status]
  end

  private

  def authenticate_project_or_user
    authenticate_with_http_basic do |login, password|
      @authentication_result = Gitlab::Auth.find_for_git_client(login, password, project: nil, ip: request.ip)

      render_403 unless @authentication_result.success? &&
        (@authentication_result.actor.nil? || @authentication_result.actor.is_a?(User))
    end
  rescue Gitlab::Auth::MissingPersonalTokenError
    render_missing_personal_token
  end

  def render_missing_personal_token
    render plain: "HTTP Basic: Access denied\n" \
                  "You have 2FA enabled, please use a personal access token for Git over HTTP.\n" \
                  "You can generate one at #{profile_personal_access_tokens_url}",
           status: 401
  end

  def auth_params
    params.permit(:service, :scope, :account, :client_id)
  end
end
