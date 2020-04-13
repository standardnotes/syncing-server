Rails.application.routes.draw do
  namespace "admin" do
    post "delete_account" => "admin#delete_account"
  end

  # extension settngs
  get "extension-settings/:id/mute" => "extension_settings#mute"

  # forward non-namespaced routes to api namespace
  get 'auth/params' => "api/auth#auth_params"
  post "auth/sign_in" => "api/auth#sign_in"
  post "auth/sign_out" => "api/auth#sign_out"
  post "auth" => "api/auth#register"
  post "auth/update" => "api/auth#update"
  post "auth/change_pw" => "api/auth#change_pw"

  post "items/sync" => "api/items#sync"
  post "items/backup" => "api/items#backup"

  delete "items" => "api/items#destroy"
  resources "items", :controller => "api/items"

  # sessions management
  post "session/refresh" => "api/sessions#refresh"
  get "sessions/active" => "api/sessions#active_sessions"
  delete "session" => "api/sessions#delete"
  delete "session/all" => "api/sessions#delete_all"

  # legacy support for clients which hardcoded the "api" path to the base url (iOS)
  namespace :api, defaults: {format: :json} do
    get 'auth/params' => "auth#auth_params"
    post "auth/sign_in" => "auth#sign_in"
    post "auth" => "auth#register"
    post "auth/change_pw" => "auth#change_pw"
    post "items/sync" => "items#sync"
  end

  root "application#home"
end
