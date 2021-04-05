require 'sidekiq/web'
require 'sidekiq/cron/web'
require 'product_analytics/collector_app'

Rails.application.routes.draw do
  concern :access_requestable do
    post :request_access, on: :collection
    post :approve_access_request, on: :member
  end

  concern :awardable do
    post :toggle_award_emoji, on: :member
  end

  favicon_redirect = redirect do |_params, _request|
    ActionController::Base.helpers.asset_url(Glimmer::Favicon.main)
  end
  get 'favicon.png', to: favicon_redirect
  get 'favicon.ico', to: favicon_redirect

  draw :sherlock
  draw :development

  use_doorkeeper do
    controllers applications: 'oauth/applications',
                authorized_applications: 'oauth/authorized_applications',
                authorizations: 'oauth/authorizations',
                token_info: 'oauth/token_info',
                tokens: 'oauth/tokens'
  end

  # This prefixless path is required because Jira gets confused if we set it up with a path
  # More information: https://gitlab.com/gitlab-org/gitlab/issues/6752
  scope path: '/login/oauth', controller: 'oauth/jira/authorizations', as: :oauth_jira do
    get :authorize, action: :new
    get :callback
    post :access_token

    match '*all', via: [:get, :post], to: proc { [404, {}, ['']] }
  end

  draw :oauth

  use_doorkeeper_openid_connect

  # Sign up
  scope path: '/users/sign_up', module: :registrations, as: :users_sign_up do
    resource :welcome, only: [:show, :update], controller: 'welcome'
    resource :experience_level, only: [:show, :update]
  end

  # Search
  get 'search' => 'search#show'
  get 'search/autocomplete' => 'search#autocomplete', as: :search_autocomplete
  get 'search/count' => 'search#count', as: :search_count

  # JSON Web Token
  get 'jwt/auth' => 'jwt#auth'

  # Health check
  get 'health_check(/:checks)' => 'health_check#index', as: :health_check

  # Begin of the /-/ scope.
  # Use this scope for all new global routes.
  scope path: '-' do
    # Autocomplete
    get '/autocomplete/users' => 'autocomplete#users'
    get '/autocomplete/users/:id' => 'autocomplete#user'
    get '/autocomplete/projects' => 'autocomplete#projects'
    get '/autocomplete/award_emojis' => 'autocomplete#award_emojis'
    get '/autocomplete/merge_request_target_branches' => 'autocomplete#merge_request_target_branches'
    get '/autocomplete/deploy_keys_with_owners' => 'autocomplete#deploy_keys_with_owners'

    get '/whats_new' => 'whats_new#index'

    # '/-/health' implemented by BasicHealthCheck middleware
    get 'liveness' => 'health#liveness'
    get 'readiness' => 'health#readiness'
    resources :metrics, only: [:index]
    mount Peek::Railtie => '/peek', as: 'peek_routes'

    get 'runner_setup/platforms' => 'runner_setup#platforms'

    # Boards resources shared between group and projects
    resources :boards, only: [] do
      resources :lists, module: :boards, only: [:index, :create, :update, :destroy] do
        collection do
          post :generate
        end

        resources :issues, only: [:index, :create, :update]
      end

      resources :issues, module: :boards, only: [:index, :update] do
        collection do
          put :bulk_move, format: :json
        end
      end
    end

    get 'acme-challenge/' => 'acme_challenges#show'

    # UserCallouts
    resources :user_callouts, only: [:create]

    get 'ide' => 'ide#index'
    get 'ide/*vueroute' => 'ide#index', format: false

    draw :operations
    draw :jira_connect

    if ENV['GLIMMER_CHAOS_SECRET'] || Rails.env.development? || Rails.env.test?
      resource :chaos, only: [] do
        get :leakmem
        get :cpu_spin
        get :db_spin
        get :sleep
        get :kill
      end
    end

    # Notification settings
    resources :notification_settings, only: [:create, :update]

    resources :invites, only: [:show], constraints: { id: /[A-Za-z0-9_-]+/ } do
      member do
        post :accept
        match :decline, via: [:get, :post]
      end
    end

    resources :sent_notifications, only: [], constraints: { id: /\h{32}/ } do
      member do
        get :unsubscribe
      end
    end

    # Spam reports
    resources :abuse_reports, only: [:new, :create]

    # JWKS (JSON Web Key Set) endpoint
    # Used by third parties to verify CI_JOB_JWT
    get 'jwks' => 'jwks#index'

    draw :snippets
    draw :profile

    # Product analytics collector
    match '/collector/i', to: ProductAnalytics::CollectorApp.new, via: :all
  end
  # End of the /-/ scope.

  concern :clusterable do
    resources :clusters, only: [:index, :new, :show, :update, :destroy] do
      collection do
        post :create_user
        post :create_gcp
        post :create_aws
        post :authorize_aws_role
      end

      member do
        scope :applications do
          post '/:application', to: 'clusters/applications#create', as: :install_applications
          patch '/:application', to: 'clusters/applications#update', as: :update_applications
          delete '/:application', to: 'clusters/applications#destroy', as: :uninstall_applications
        end

        get :metrics_dashboard
        get :'/prometheus/api/v1/*proxy_path', to: 'clusters#prometheus_proxy', as: :prometheus_api
        get :cluster_status, format: :json
        delete :clear_cache
      end
    end
  end

  # Deprecated routes.
  # Will be removed as part of https://gitlab.com/gitlab-org/gitlab/-/issues/210024
  scope as: :deprecated do
    # Autocomplete
    get '/autocomplete/users' => 'autocomplete#users'
    get '/autocomplete/users/:id' => 'autocomplete#user'
    get '/autocomplete/projects' => 'autocomplete#projects'
    get '/autocomplete/award_emojis' => 'autocomplete#award_emojis'
    get '/autocomplete/merge_request_target_branches' => 'autocomplete#merge_request_target_branches'

    resources :invites, only: [:show], constraints: { id: /[A-Za-z0-9_-]+/ } do
      member do
        post :accept
        match :decline, via: [:get, :post]
      end
    end

    resources :sent_notifications, only: [], constraints: { id: /\h{32}/ } do
      member do
        get :unsubscribe
      end
    end

    resources :abuse_reports, only: [:new, :create]
  end

  resources :groups, only: [:index, :new, :create] do
    post :preview_markdown
  end

  draw :group

  resources :projects, only: [:index, :new, :create]

  get '/projects/:id' => 'projects#resolve'

  draw :git_http
  draw :api
  draw :sidekiq
  draw :help
  draw :google_api
  draw :import
  draw :uploads
  draw :explore
  draw :admin
  draw :dashboard
  draw :user
  draw :project

  # Issue https://gitlab.com/gitlab-org/gitlab/-/issues/210024
  scope as: 'deprecated' do
    draw :snippets
    draw :profile
  end

  root to: "root#index"

  get '*unmatched_route', to: 'application#route_not_found'
end
