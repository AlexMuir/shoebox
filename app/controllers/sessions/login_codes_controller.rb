class Sessions::LoginCodesController < ApplicationController
  require_unauthenticated_access
  layout "login"

  def show
  end

  def create
    email = verified_pending_email or return redirect_to(new_session_path, alert: "Session expired. Please try again.")

    user = User.find_by(email: email)
    login_code = user&.login_codes&.where("expires_at > ?", Time.current)&.find_by(code: params.dig(:login_code, :code))

    if login_code
      family = user.families.first
      unless family
        redirect_to new_session_path, alert: "No family found for this account."
        return
      end
      start_new_session_for(user, family: family)
      login_code.destroy
      cookies.delete(:pending_authentication_token)
      redirect_to after_authentication_url
    else
      redirect_to session_login_code_path, alert: "Invalid or expired code. Please try again."
    end
  end

  private

  def verified_pending_email
    pending_authentication_token_verifier.verified(
      cookies[:pending_authentication_token],
      purpose: nil
    )
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end
end
