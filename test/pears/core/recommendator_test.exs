defmodule Pears.Core.RecommendatorTest do
  use ExUnit.Case, async: true

  import TeamAssertions
  alias Pears.Core.Recommendator
  alias Pears.Core.Team

  describe "choose_anchors_and_suggest" do
    test "rotates the non-anchor pears" do
      TeamBuilders.team()
      |> Team.add_track("track1")
      |> Team.add_track("track2")
      |> Team.add_pear("pear1")
      |> Team.add_pear("pear2")
      |> Team.add_pear("pear3")
      |> Team.add_pear("pear4")
      |> Team.add_pear_to_track("pear1", "track1")
      |> Team.add_pear_to_track("pear2", "track1")
      |> Team.add_pear_to_track("pear3", "track2")
      |> Team.add_pear_to_track("pear4", "track2")
      |> Team.record_pears()
      |> Team.toggle_anchor("pear1", "track1")
      |> Team.toggle_anchor("pear3", "track2")
      |> Recommendator.choose_anchors_and_suggest()
      |> assert_pear_in_track("pear1", "track1")
      |> assert_pear_in_track("pear4", "track1")
      |> assert_pear_in_track("pear3", "track2")
      |> assert_pear_in_track("pear2", "track2")
    end

    test "chooses a pear to stay on the track if no anchor chosen" do
      team =
        TeamBuilders.team()
        |> Team.add_track("track1")
        |> Team.add_track("track2")
        |> Team.add_pear("pear1")
        |> Team.add_pear("pear2")
        |> Team.add_pear("pear3")
        |> Team.add_pear("pear4")
        |> Team.add_pear_to_track("pear1", "track1")
        |> Team.add_pear_to_track("pear2", "track1")
        |> Team.add_pear_to_track("pear3", "track2")
        |> Team.add_pear_to_track("pear4", "track2")
        |> Team.record_pears()
        |> Recommendator.choose_anchors_and_suggest()

      track1_pears =
        team
        |> Map.get(:tracks)
        |> Map.get("track1")
        |> Map.get(:pears)
        |> Map.values()
        |> Enum.map(&Map.get(&1, :name))

      track2_pears =
        team
        |> Map.get(:tracks)
        |> Map.get("track2")
        |> Map.get(:pears)
        |> Map.values()
        |> Enum.map(&Map.get(&1, :name))

      assert track1_pears == ["pear1", "pear3"] || track1_pears == ["pear1", "pear4"] ||
               track1_pears == ["pear2", "pear3"] || track1_pears == ["pear2", "pear4"]

      assert track2_pears == ["pear1", "pear3"] || track2_pears == ["pear1", "pear4"] ||
               track2_pears == ["pear2", "pear3"] || track2_pears == ["pear2", "pear4"]
    end

    test "leaves only the user set anchors" do
      anchors =
        TeamBuilders.team()
        |> Team.add_track("track1")
        |> Team.add_track("track2")
        |> Team.add_pear("pear1")
        |> Team.add_pear("pear2")
        |> Team.add_pear("pear3")
        |> Team.add_pear("pear4")
        |> Team.add_pear_to_track("pear1", "track1")
        |> Team.add_pear_to_track("pear2", "track1")
        |> Team.add_pear_to_track("pear3", "track2")
        |> Team.add_pear_to_track("pear4", "track2")
        |> Team.record_pears()
        |> Team.toggle_anchor("pear3", "track2")
        |> Recommendator.choose_anchors_and_suggest()
        |> assert_anchoring_track("pear3", "track2")
        |> Team.anchors()

      assert Enum.count(anchors) == 1
    end
  end

  describe "assign_pears" do
    test "does not modify team when there are no unassigned pears" do
      before_team =
        TeamBuilders.team()
        |> Team.add_track("two pear track")
        |> Team.add_pear("pear1")
        |> Team.add_pear("pear2")
        |> Team.add_pear_to_track("pear1", "two pear track")
        |> Team.add_pear_to_track("pear2", "two pear track")

      after_team = Recommendator.assign_pears(before_team)

      assert before_team == after_team
    end

    test "given one pear and one track, moves pear to track" do
      TeamBuilders.team()
      |> Team.add_track("feature track")
      |> Team.add_pear("pear1")
      |> Recommendator.assign_pears()
      |> assert_pear_in_track("pear1", "feature track")
    end

    test "given one empty track and two full tracks, moves pear to empty track" do
      TeamBuilders.team()
      |> Team.add_track("empty track")
      |> Team.add_track("two pear track")
      |> Team.add_track("three pear track")
      |> Team.add_pear("pear1")
      |> Team.add_pear("pear2")
      |> Team.add_pear("pear3")
      |> Team.add_pear("pear4")
      |> Team.add_pear("pear5")
      |> Team.add_pear("pear6")
      |> Team.add_pear_to_track("pear1", "two pear track")
      |> Team.add_pear_to_track("pear2", "two pear track")
      |> Team.add_pear_to_track("pear3", "three pear track")
      |> Team.add_pear_to_track("pear4", "three pear track")
      |> Team.add_pear_to_track("pear5", "three pear track")
      |> Recommendator.assign_pears()
      |> assert_pear_in_track("pear6", "empty track")
    end

    test "given one empty track, one full track, and one incomplete track, moves pear to incomplete track" do
      TeamBuilders.team()
      |> Team.add_track("empty track")
      |> Team.add_track("one pear track")
      |> Team.add_track("two pear track")
      |> Team.add_pear("pear1")
      |> Team.add_pear("pear2")
      |> Team.add_pear("pear3")
      |> Team.add_pear("pear4")
      |> Team.add_pear_to_track("pear1", "two pear track")
      |> Team.add_pear_to_track("pear2", "two pear track")
      |> Team.add_pear_to_track("pear3", "one pear track")
      |> Recommendator.assign_pears()
      |> assert_pear_in_track("pear4", "one pear track")
    end

    test "given two days of history and two empty tracks, pairs the two that haven't paired before" do
      TeamBuilders.team()
      |> Team.add_track("track one")
      |> Team.add_track("track two")
      |> Team.add_pear("pear1")
      |> Team.add_pear("pear2")
      |> Team.add_pear("pear3")
      |> Map.put(:history, [
        [{"track one", ["pear1", "pear2"]}],
        [{"track one", ["pear1", "pear3"]}]
      ])
      |> Recommendator.assign_pears()
      |> Team.record_pears()
      |> assert_history([
        [{"track one", ["pear2", "pear3"]}, {"track two", ["pear1"]}],
        [{"track one", ["pear1", "pear2"]}],
        [{"track one", ["pear1", "pear3"]}]
      ])
    end

    test "leaves good choices for other people when non-optimal pair is available" do
      TeamBuilders.team()
      |> Team.add_track("track one")
      |> Team.add_track("track two")
      |> Team.add_pear("pear1")
      |> Team.add_pear("pear2")
      |> Team.add_pear("pear3")
      |> Team.add_pear("pear4")
      |> Team.add_pear_to_track("pear3", "track one")
      |> Team.add_pear_to_track("pear4", "track two")
      |> Map.put(:history, [
        [{"track one", ["pear2", "pear3"]}],
        [{"track one", ["pear1", "pear3"]}],
        [{"track one", ["pear4", "pear1"]}],
        [{"track one", ["pear2", "pear4"]}]
      ])
      |> Recommendator.assign_pears()
      |> Team.record_pears()
      |> assert_history([
        [{"track one", ["pear1", "pear3"]}, {"track two", ["pear2", "pear4"]}],
        [{"track one", ["pear2", "pear3"]}],
        [{"track one", ["pear1", "pear3"]}],
        [{"track one", ["pear4", "pear1"]}],
        [{"track one", ["pear2", "pear4"]}]
      ])
    end

    test "pairs floating people when more floating people than available" do
      TeamBuilders.team()
      |> Team.add_track("track one")
      |> Team.add_track("track two")
      |> Team.add_pear("pear1")
      |> Team.add_pear("pear2")
      |> Team.add_pear("pear3")
      |> Team.add_pear_to_track("pear3", "track one")
      |> Map.put(:history, [
        [{"track one", ["pear1", "pear2"]}],
        [{"track two", ["pear1", "pear3"]}]
      ])
      |> Recommendator.assign_pears()
      |> Team.record_pears()
      |> assert_history([
        [{"track one", ["pear2", "pear3"]}, {"track two", ["pear1"]}],
        [{"track one", ["pear1", "pear2"]}],
        [{"track two", ["pear1", "pear3"]}]
      ])
    end

    test "won't pair people with the same pear as yesterday" do
      [
        {"pear1", "pear2", "track one"},
        {"pear3", "pear4", "track two"},
        {"pear5", "track three"}
      ]
      |> TeamBuilders.from_matches()
      |> Team.remove_pear_from_track("pear2", "track one")
      |> Team.remove_pear_from_track("pear4", "track two")
      |> Recommendator.assign_pears()
      |> Team.record_pears()
      |> refute_pear_in_track("pear2", "track one")
      |> refute_pear_in_track("pear4", "track two")
      |> assert_history([
        [
          {"track one", ["pear1", "pear4"]},
          {"track three", ["pear2", "pear5"]},
          {"track two", ["pear3"]}
        ],
        [
          {"track one", ["pear1", "pear2"]},
          {"track three", ["pear5"]},
          {"track two", ["pear3", "pear4"]}
        ]
      ])
    end

    test "won't pear people in locked tracks" do
      [
        {"pear1", "track one"},
        "pear2",
        {"pear3", "track two"},
        "pear4"
      ]
      |> TeamBuilders.from_matches()
      |> Team.lock_track("track two")
      |> Recommendator.assign_pears()
      |> Team.record_pears()
      |> refute_pear_in_track("pear4", "track two")
      |> assert_history([
        [
          {"track one", ["pear1", "pear2"]},
          {"track two", ["pear3"]}
        ],
        [
          {"track one", ["pear1"]},
          {"track two", ["pear3"]}
        ]
      ])

      TeamBuilders.team()
      |> Team.add_track("track one")
      |> Team.lock_track("track one")
      |> Team.add_pear("pear1")
      |> Team.add_pear("pear2")
      |> Recommendator.assign_pears()
      |> assert_pear_available("pear1")
      |> assert_pear_available("pear2")
    end
  end
end
