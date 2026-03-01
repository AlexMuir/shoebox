module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
      before_action :resume_session, **options
    end

    def require_unauthenticated_access(**options)
      allow_unauthenticated_access **options
      before_action :redirect_authenticated_user, **options
    end
  end

  private

  def authenticated?
    Current.user.present?
  end

  def require_authentication
    resume_session || request_authentication
  end

  def resume_session
    if session = Session.find_signed(cookies.signed[:session_token])
      set_current_session session
    end
  end

  def terminate_session
    Current.session.destroy
    cookies.delete(:session_token)
  end

  def request_authentication
    session[:return_to_after_authenticating] = request.url
    redirect_to new_session_url
  end

  def start_new_session_for(user, family:)
    user.sessions.create!(
      family: family,
      user_agent: request.user_agent,
      ip_address: request.remote_ip
    ).tap do |session|
      set_current_session session
    end
  end

  def set_current_session(session)
    Current.session = session
    cookies.signed.permanent[:session_token] = {
      value: session.signed_id,
      httponly: true,
      same_site: :lax
    }
  end

  def after_authentication_url
    session.delete(:return_to_after_authenticating) || root_url
  end

  def redirect_authenticated_user
    redirect_to root_url if authenticated?
  end

  # Login code verification helpers
  def pending_authentication_token_verifier
    Rails.application.message_verifier("pending_authentication_token")
  end
end
