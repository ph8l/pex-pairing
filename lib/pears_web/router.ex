defmodule PearsWeb.Router do
  use PearsWeb, :router

  import PearsWeb.TeamAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PearsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_team
  end

  pipeline :admins_only do
    plug :auth
  end

  defp auth(conn, _opts) do
    username = Application.get_env(:pears, :admin_user)
    password = Application.get_env(:pears, :admin_password)
    Plug.BasicAuth.basic_auth(conn, username: username, password: password)
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", PearsWeb do
    pipe_through :api

    post "/slack/interactions", SlackInteractionController, :create
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:pears, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PearsWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", PearsWeb do
    pipe_through [:browser, :redirect_if_team_is_authenticated]

    live_session :redirect_if_team_is_authenticated,
      on_mount: [{PearsWeb.TeamAuth, :redirect_if_team_is_authenticated}],
      layout: {PearsWeb.Layouts, :logged_out} do
      live "/teams/register", TeamRegistrationLive, :new
      live "/teams/log_in", TeamLoginLive, :new
      live "/teams/reset_password", TeamForgotPasswordLive, :new
      live "/teams/reset_password/:token", TeamResetPasswordLive, :edit
    end

    post "/teams/log_in", TeamSessionController, :create
  end

  scope "/", PearsWeb do
    pipe_through [:browser, :require_authenticated_team]

    get "/slack/oauth", SlackAuthController, :new

    live_session :require_authenticated_team,
      on_mount: [
        {PearsWeb.TeamAuth, :ensure_authenticated},
        {PearsWeb.CurrentPath, :get_current_path}
      ],
      layout: {PearsWeb.Layouts, :app} do
      live "/", PairingBoardLive, :show
      live "/teams", PairingBoardLive, :show
      live "/teams/add_pear", PairingBoardLive, :add_pear
      live "/teams/add_track", PairingBoardLive, :add_track
      live "/teams/settings", TeamSettingsLive, :edit
      live "/teams/settings/confirm_email/:token", TeamSettingsLive, :confirm_email
      live "/teams/slack", TeamSlackLive, :edit
      live "/teams/account", TeamAccountLive, :edit
    end
  end

  scope "/" do
    pipe_through [:browser, :require_authenticated_team, :admins_only]

    forward "/features", FunWithFlags.UI.Router, namespace: "features"
  end

  scope "/", PearsWeb do
    pipe_through [:browser]

    delete "/teams/log_out", TeamSessionController, :delete
    get "/slack/oauth", SlackAuthController, :new

    live_session :current_team,
      on_mount: [
        {PearsWeb.TeamAuth, :mount_current_team},
        {PearsWeb.CurrentPath, :get_current_path}
      ] do
      live "/teams/confirm/:token", TeamConfirmationLive, :edit
      live "/teams/confirm", TeamConfirmationInstructionsLive, :new
    end
  end
end
