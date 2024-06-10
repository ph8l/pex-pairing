defmodule PearsWeb.AddTrackForm do
  use PearsWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok, assign(socket, track_name: "")}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def handle_event("add_track", %{"track-name" => track_name}, socket) do
    case Pears.add_track(socket.assigns.team.name, track_name) do
      {:ok, _} ->
        {:noreply, push_redirect(socket, to: ~p"/")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Sorry, a track with the name '#{track_name}' already exists")
         |> push_redirect(to: ~p"/")}
    end
  end
end
