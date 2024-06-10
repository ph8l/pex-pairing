defmodule Pears.Persistence do
  @moduledoc """
  The Persistence context.
  """
  use OpenTelemetryDecorator

  import Ecto.Query, warn: false

  alias Pears.Repo
  alias Pears.Persistence.{PearRecord, SnapshotRecord, TeamRecord, TrackRecord}

  @decorate trace("persistence.create_team", include: [:team_name])
  def create_team(team_name) do
    %TeamRecord{}
    |> TeamRecord.changeset(%{name: team_name})
    |> Repo.insert()
  end

  @decorate trace("persistence.delete_team", include: [:team_name])
  def delete_team(team_name) do
    case get_team_by_name(team_name) do
      {:error, :not_found} -> nil
      {:ok, team_record} -> Repo.delete(team_record)
    end
  end

  @decorate trace("persistence.set_slack_token", include: [:team_name])
  def set_slack_token(team_name, slack_token) do
    with {:ok, team} <- get_team_by_name(team_name),
         {:ok, updated_team} <- do_set_slack_token(team, slack_token) do
      {:ok, updated_team}
    else
      error -> error
    end
  end

  defp do_set_slack_token(team_record, slack_token) do
    case team_record
         |> TeamRecord.slack_token_changeset(%{slack_token: slack_token})
         |> Repo.update() do
      {:ok, team} -> {:ok, team}
      error -> error
    end
  end

  @decorate trace("persistence.set_slack_channel", include: [:team_name, :slack_channel])
  def set_slack_channel(team_name, slack_channel) do
    with {:ok, team_record} <- get_team_by_name(team_name),
         {:ok, updated_team} <- do_set_slack_channel(team_record, slack_channel) do
      {:ok, updated_team}
    else
      error -> error
    end
  end

  defp do_set_slack_channel(team_record, slack_channel) do
    case team_record
         |> TeamRecord.slack_channel_changeset(%{
           slack_channel_id: slack_channel.id,
           slack_channel_name: slack_channel.name
         })
         |> Repo.update() do
      {:ok, team} -> {:ok, team}
      error -> error
    end
  end

  @decorate trace("persistence.get_team_by_name", include: [:team_name])
  def get_team_by_name(team_name) do
    result =
      TeamRecord
      |> Repo.get_by(name: team_name)
      |> Repo.preload([
        {:pears, :track},
        {:tracks, :pears},
        {:tracks, :anchor},
        {:snapshots, :matches},
        snapshots: from(s in SnapshotRecord, order_by: [desc: s.inserted_at])
      ])

    case result do
      nil -> {:error, :not_found}
      team_record -> {:ok, team_record}
    end
  end

  @decorate trace("persistence.find_track_by_name", include: [:team, :track_name])
  def find_track_by_name(team, track_name) do
    case Enum.find(team.tracks, fn track -> track.name == track_name end) do
      nil -> {:error, :track_not_found}
      track_record -> {:ok, track_record}
    end
  end

  @decorate trace("persistence.find_pear_by_name", include: [:team, :pear_name, :pear])
  def find_pear_by_name(team, pear_name) do
    case Enum.find(team.pears, fn pear -> pear.name == pear_name end) do
      nil -> {:error, :pear_not_found}
      pear -> {:ok, pear}
    end
  end

  @decorate trace("persistence.add_pear_to_team", include: [:team_name, :pear_name, :error])
  def add_pear_to_team(team_name, pear_name) do
    with {:ok, team} <- get_team_by_name(team_name),
         {:ok, pear} <- add_pear(team, pear_name) do
      {:ok, pear}
    else
      error -> error
    end
  end

  @decorate trace("persistence.add_pear", include: [:team, :pear_name, :error])
  defp add_pear(team, pear_name) do
    case %PearRecord{}
         |> PearRecord.changeset(%{team_id: team.id, name: pear_name})
         |> Repo.insert() do
      {:ok, pear} -> {:ok, Repo.preload(pear, [:track])}
      error -> error
    end
  end

  @decorate trace(
              "persistence.add_pear_slack_details",
              include: [:team_name, :pear_name, :attrs, :error]
            )
  def add_pear_slack_details(team_name, pear_name, attrs) do
    with {:ok, team} <- get_team_by_name(team_name),
         {:ok, pear} <- find_pear_by_name(team, pear_name),
         {:ok, updated_pear} <- do_add_pear_slack_details(pear, attrs) do
      {:ok, updated_pear}
    else
      error -> error
    end
  end

  defp do_add_pear_slack_details(pear, attrs) do
    pear
    |> PearRecord.slack_details_changeset(attrs)
    |> Repo.update()
  end

  @decorate trace(
              "persistence.add_pear_to_track",
              include: [:team_name, :pear_name, :track_name, :error]
            )
  def add_pear_to_track(team_name, pear_name, track_name) do
    with {:ok, team} <- get_team_by_name(team_name),
         {:ok, track} <- find_track_by_name(team, track_name),
         {:ok, pear} <- find_pear_by_name(team, pear_name),
         {:ok, _} <- do_add_pear_to_track(pear, track) do
      {:ok, pear}
    else
      error -> error
    end
  end

  @decorate trace("persistence.do_add_pear_to_track", include: [:pear, :track])
  def do_add_pear_to_track(pear, track) do
    pear
    |> Repo.preload(:track)
    |> PearRecord.changeset(%{track_id: track.id})
    |> Repo.update()
  end

  @decorate trace("persistence.add_track_to_team", include: [:team_name, :track_name, :error])
  def add_track_to_team(team_name, track_name) do
    with {:ok, team} <- get_team_by_name(team_name),
         {:ok, track} <- add_track(team, track_name) do
      {:ok, track}
    else
      error -> error
    end
  end

  @decorate trace("persistence.add_track", include: [:team, :track_name, :error])
  defp add_track(team, track_name) do
    case %TrackRecord{}
         |> TrackRecord.changeset(%{team_id: team.id, name: track_name, locked: false})
         |> Repo.insert() do
      {:ok, track} -> {:ok, Repo.preload(track, [:pears, :anchor])}
      error -> error
    end
  end

  @decorate trace("persistence.lock_track", include: [:team_name, :track_name])
  def lock_track(team_name, track_name), do: toggle_track_locked(team_name, track_name, true)

  @decorate trace("persistence.unlock_track", include: [:team_name, :track_name])
  def unlock_track(team_name, track_name), do: toggle_track_locked(team_name, track_name, false)

  defp toggle_track_locked(team_name, track_name, locked?) do
    with {:ok, team} <- get_team_by_name(team_name),
         {:ok, track} <- find_track_by_name(team, track_name),
         {:ok, track} <- do_toggle_track_locked(track, locked?) do
      {:ok, track}
    else
      error -> error
    end
  end

  @decorate trace("persistence.toggle_anchor", include: [:team_name, :track_name, :pear_name])
  def toggle_anchor(team_name, pear_name, track_name) do
    with {:ok, team} <- get_team_by_name(team_name),
         {:ok, pear} <- find_pear_by_name(team, pear_name),
         {:ok, track} <- find_track_by_name(team, track_name),
         {:ok, pear} <- do_toggle_anchor(pear, track) do
      {:ok, pear}
    end
  end

  @decorate trace("persistence.add_anchor", include: [[:pear, :name], [:track, :name]])
  defp do_toggle_anchor(pear, %{anchor: nil} = track) do
    pear
    |> Repo.preload([:anchoring, :track])
    |> PearRecord.anchor_track_changeset(%{anchoring_id: track.id})
    |> Repo.update()
  end

  @decorate trace("persistence.remove_anchor", include: [[:pear, :name], :_track_name])
  defp do_toggle_anchor(%{id: anchor_id} = pear, %{anchor: %{id: anchor_id}, name: _track_name}) do
    pear
    |> Repo.preload([:anchoring, :track])
    |> PearRecord.anchor_track_changeset(%{anchoring_id: nil})
    |> Repo.update()
  end

  @decorate trace("persistence.add_anchor", include: [[:pear, :name], [:track, :name]])
  defp do_toggle_anchor(new_anchor, %{anchor: prev_anchor} = track) do
    Repo.transaction(fn ->
      prev_anchor
      |> Repo.preload([:anchoring, :track])
      |> PearRecord.anchor_track_changeset(%{anchoring_id: nil})
      |> Repo.update()

      new_anchor
      |> Repo.preload([:anchoring, :track])
      |> PearRecord.anchor_track_changeset(%{anchoring_id: track.id})
      |> Repo.update()
    end)
  end

  @decorate trace(
              "persistence.rename_track",
              include: [:team_name, :track_name, :new_track_name, :error]
            )
  def rename_track(team_name, track_name, new_track_name) do
    with {:ok, team} <- get_team_by_name(team_name),
         {:ok, track} <- find_track_by_name(team, track_name),
         {:ok, updated_track} <- do_rename_track(track, new_track_name) do
      {:ok, updated_track}
    else
      error -> error
    end
  end

  defp do_rename_track(track, new_track_name) do
    track
    |> TrackRecord.changeset(%{name: new_track_name})
    |> Repo.update()
  end

  defp do_toggle_track_locked(track, locked?) do
    track
    |> TrackRecord.changeset(%{locked: locked?})
    |> Repo.update()
  end

  @decorate trace("persistence.remove_track_from_team",
              include: [:team_name, :track_name, :error]
            )
  def remove_track_from_team(team_name, track_name) do
    case get_team_by_name(team_name) do
      {:ok, team} ->
        track = Repo.get_by(TrackRecord, team_id: team.id, name: track_name)
        Repo.delete(track)

      error ->
        error
    end
  end

  @decorate trace("persistence.remove_pear_from_team", include: [:team_name, :pear_name, :error])
  def remove_pear_from_team(team_name, pear_name) do
    case get_team_by_name(team_name) do
      {:ok, team} ->
        pear = Repo.get_by(PearRecord, team_id: team.id, name: pear_name)
        Repo.delete(pear)

      error ->
        error
    end
  end

  @decorate trace("persistence.add_snapshot_to_team", include: [:team_name, :snapshot, :error])
  def add_snapshot_to_team(team_name, snapshot) do
    with {:ok, team} <- get_team_by_name(team_name),
         {:ok, snapshot_record} <- save_snapshot(team, snapshot) do
      {:ok, snapshot_record}
    else
      error -> error
    end
  end

  defp save_snapshot(team, snapshot) do
    %SnapshotRecord{}
    |> SnapshotRecord.changeset(%{
      team_id: team.id,
      matches: build_matches(snapshot)
    })
    |> Repo.insert()
  end

  defp build_matches(snapshot) do
    Enum.map(snapshot, &build_match/1)
  end

  defp build_match({track_name, pear_names}) do
    %{track_name: track_name, pear_names: pear_names}
  end
end
