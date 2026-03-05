Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "site#index"

  resource :session, only: [ :new, :create, :destroy ] do
    scope module: :sessions do
      resource :login_code, only: [ :show, :create ]
    end
  end

  resources :photos do
    resources :contributions, only: [ :create ]
    resources :photo_people, only: [ :create, :destroy ]
    resources :photo_faces, only: [ :create, :update, :destroy ]
  end

  resources :people do
    collection do
      get :search
    end
  end
  resources :events
  resources :locations do
    collection do
      get :search
      post :create_from_google
    end
  end
  resources :uploads, only: [ :index, :show, :new, :create, :edit, :update ]
  resources :storytelling_sessions, only: [ :new, :create, :show ] do
    resources :stories, only: [ :create ]
  end

  post "families/:id/switch", to: "families#switch", as: :switch_family

  authenticate = ->(request) { Session.find_signed(request.cookie_jar.signed[:session_token]) }
  constraints(authenticate) do
    mount MissionControl::Jobs::Engine, at: "/mission-control"
  end
end
