class SessionsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :create, with: :rate_limit_exceeded
  require_unauthenticated_access except: :destroy
  layout "login"

  def new
  end

  def create
    email = params.dig(:session, :email)
    if user = User.find_by(email: email)
      sign_in user
    else
      redirect_to_fake_session_login_code email
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_url
  end

  private

  def rate_limit_exceeded
    redirect_to new_session_path, alert: "Try again later."
  end

  def sign_in(user)
    redirect_to_session_login_code user.send_login_code
  end

  def redirect_to_fake_session_login_code(email, **)
    fake_login_code = LoginCode.new(
      user: User.new(email: email),
      code: LoginCode.generate_code,
      expires_at: LoginCode::EXPIRATION_TIME.from_now
    )
    redirect_to_session_login_code(fake_login_code, **)
  end

  def redirect_to_session_login_code(login_code, return_to: nil)
    serve_development_login_code(login_code)
    set_pending_authentication_token(login_code)
    session[:return_to_after_authenticating] = return_to if return_to
    redirect_to session_login_code_url
  end

  def serve_development_login_code(login_code)
    if Rails.env.development? && login_code.present?
      flash[:login_code] = login_code.code
      response.set_header("X-Login-Code", login_code.code)
    end
  end

  def set_pending_authentication_token(login_code)
    cookies[:pending_authentication_token] = {
      value: pending_authentication_token_verifier.generate(login_code.user.email, expires_at: login_code.expires_at),
      httponly: true,
      same_site: :lax,
      expires: login_code.expires_at
    }
  end
end
