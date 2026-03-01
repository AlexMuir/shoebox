Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "site#index"

  resource :session, only: [:new, :create, :destroy] do
    scope module: :sessions do
      resource :login_code, only: [:show, :create]
    end
  end

  resources :photos do
    resources :contributions, only: [:create]
    resources :photo_people, only: [:create, :destroy]
  end

  resources :people do
    collection do
      get :search
    end
  end
  resources :events
  resources :locations
  resources :uploads, only: [:index, :show, :new, :create, :edit, :update]

  post "families/:id/switch", to: "families#switch", as: :switch_family

  mount MissionControl::Jobs::Engine, at: "/jobs"
end
