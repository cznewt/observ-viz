import pytest
import salt_tempo_relay


@pytest.fixture
def app():
    app = salt_tempo_relay.create_app()
    return app
