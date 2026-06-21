Development
===========

Repository
----------

The source code repository is located at https://gitlab.com/turtletraction-oss/salt-grafana

Bootstrapping a development environment
---------------------------------------

.. code-block:: shell

    python3.9 -m venv .venv
    source .venv/bin/activate
    hash -r
    pip install -r requirements/dev.txt
    pre-commit install

Running the test suite
----------------------

.. code-block:: shell

    nox -e tests-3
    nox -e vector

    # or faster:
    SKIP_REQUIREMENTS_INSTALL=1 nox -r -e tests-3
    nox -r --no-install -e vector

Building the docs
-----------------

.. code-block:: shell

    nox -e docs

    # or faster:
    SKIP_REQUIREMENTS_INSTALL=1 nox -r -e docs


To render the architectural diagram, download `PlantUML <https://plantuml.com/download>`_ and then run:

.. code-block:: shell

    java -jar .venv/bin/plantuml.jar docs/_static/architecture.puml

To render the vector config diagram, install Vector first (by running the tests ``nox -e vector``), install Graphviz, and then run:

.. code-block:: shell

   .nox/vector-vector-latest/tmp/vector graph --config vector-engine/etc/vector.toml | dot -Tpng > docs/_static/vector-graph.png

To render the database diagram, download `SchemaSpy <https://schemaspy.readthedocs.io/en/latest/installation.html>`_ and `pgJDBC <https://jdbc.postgresql.org/download/>`_, install Graphviz, and then run:

.. code-block:: shell

    java -jar schemaspy-6.1.0.jar -t pgsql -dp postgresql-42.5.1.jar -host DATABASE_HOST -db salt -u salt -p PASSWORD -o /tmp/schema
    cp /tmp/schema/diagrams/summary/relationships.implied.large.png docs/_static/


Dependency management
---------------------

This project uses `pip-compile-multi <https://pypi.org/project/pip-compile-multi/>`_ for hard-pinning dependencies versions.
Please see its documentation for usage instructions.
In short, ``requirements/*.in`` contains the list of direct requirements with occasional version constraints
and ``requirements/*.txt`` is automatically generated from it by adding recursive tree of dependencies with fixed versions.

To upgrade dependency versions, run ``pip-compile-multi``.

To add a new dependency without upgrade, add it to ``requirements/*.in`` and run ``pip-compile-multi --no-upgrade``.

For installation always use ``.txt`` files. For example, command ``pip install -Ue . -r requirements/dev.txt`` will install
this project in development mode, testing requirements and development tools.
Another useful command is ``pip-sync requirements/dev.txt``, it uninstalls packages from your virtualenv that aren't listed in the file.

Known issues
------------

1. Gitlab CI only tests against Python 3.9, although the Nox test matrix is more extensive
2. Some docs commands in ``noxfile.py`` are failing

.. code-block:: python

    # session.run("make", "linkcheck", "SPHINXOPTS=-Wn --keep-going", external=True)
    # session.run("make", "coverage", "SPHINXOPTS=-Wn --keep-going", external=True)

    # session.run("make", "html", "SPHINXOPTS=-Wn --keep-going", external=True)

3. The ``lint-tests`` hook in ``.pre-commit-config.yaml`` is failing
4. On the first run, pre-commit hooks dependency installation process might fail. Try it again a couple of times until it succeeds
