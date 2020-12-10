defmodule RecognizerWeb.Router do
  use RecognizerWeb, :router

  import RecognizerWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", RecognizerWeb do
    pipe_through :browser

    get "/", HomepageController, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", RecognizerWeb do
  #   pipe_through :api
  # end

  scope "/", RecognizerWeb.Accounts do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/create-account", UserRegistrationController, :new
    post "/create-account", UserRegistrationController, :create
    get "/login", UserSessionController, :new
    post "/login", UserSessionController, :create
    get "/forgot-password", UserResetPasswordController, :new
    post "/forgot-password", UserResetPasswordController, :create
    get "/forgot-password/:token", UserResetPasswordController, :edit
    put "/forgot-password/:token", UserResetPasswordController, :update
  end

  scope "/", RecognizerWeb.Accounts do
    pipe_through [:browser, :require_authenticated_user]

    get "/settings", UserSettingsController, :edit
    put "/settings", UserSettingsController, :update
  end

  scope "/", RecognizerWeb.Accounts do
    pipe_through [:browser]

    delete "/logout", UserSessionController, :delete
  end
end
