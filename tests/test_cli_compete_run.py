import json
from types import SimpleNamespace
from uuid import uuid4

from hackathon_competitor import cli
from hackathon_competitor.models import (
    MissionState,
    MissionStatus,
    MonitorOutcome,
    MonitorRunResult,
)


def test_compete_run_wires_metrics_and_the_monitored_runner(tmp_path, monkeypatch, capsys):
    mission_id = uuid4()
    mission = SimpleNamespace(
        id=mission_id,
        status=MissionStatus.ACTIVE,
        state=MissionState.BUILDING,
        workspace_path=str(tmp_path),
    )
    captured = {}

    class Database:
        def get_mission(self, requested_id):
            assert requested_id == mission_id
            return mission

        def get_project_target_for_mission(self, requested_id):
            raise KeyError(requested_id)

        def list_competition_cycles(self, requested_id):
            return []

    database = Database()
    app = SimpleNamespace(database=database, artifact_root=tmp_path)
    monkeypatch.setattr(cli, "runtime", lambda home: app)
    monkeypatch.setenv("AGENT_ID", "galahad-hackathon")
    monkeypatch.setattr(cli, "HermesOneShotReasoner", lambda *args, **kwargs: object())

    metrics = object()

    class MetricsReader:
        def __init__(self, agent_id):
            captured["agent_id"] = agent_id

    class MetricsIngestor:
        def __init__(self, intelligence, reader):
            captured["reader"] = reader
            self.value = metrics

    def observer_factory(database_arg, *, github=None, metrics=None):
        captured["observer_metrics"] = metrics
        return object()

    runner = object()

    class MonitoredRunner:
        def __init__(self, database_arg, iteration_runner):
            captured["iteration_runner"] = iteration_runner

        def run(self, requested_id, *, holder):
            captured["holder"] = holder
            return MonitorRunResult(
                outcome=MonitorOutcome.UNCHANGED,
                mission_id=requested_id,
                monitor_type="competition_state",
            )

    monkeypatch.setattr(cli, "PlowMetricsReader", MetricsReader)
    monkeypatch.setattr(cli, "PlowMetricsIngestor", MetricsIngestor)
    monkeypatch.setattr(cli, "CompetitionObserver", observer_factory)
    monkeypatch.setattr(cli, "HermesCompetitionPlanner", lambda *args, **kwargs: object())
    monkeypatch.setattr(cli, "CompetitionActionDispatcher", lambda *args, **kwargs: object())
    monkeypatch.setattr(cli, "CompetitionIterationRunner", lambda *args, **kwargs: runner)
    monkeypatch.setattr(cli, "MonitoredCompetitionRunner", MonitoredRunner)

    exit_code = cli.main(["mission", "compete-run", str(mission_id)])
    output = json.loads(capsys.readouterr().out)

    assert exit_code == 0
    assert captured["agent_id"] == "galahad-hackathon"
    assert captured["observer_metrics"].value is metrics
    assert captured["iteration_runner"] is runner
    assert captured["holder"].startswith("joust-cli:")
    assert output["monitor_outcome"] == "UNCHANGED"
