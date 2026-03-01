class LoginCodeMailer < ApplicationMailer
  def sign_in_instructions(login_code)
    @login_code = login_code
    @user = login_code.user
    mail(to: @user.email, subject: "Your Photos sign-in code")
  end
end
