# pylint: disable=missing-module-docstring,import-error,protected-access,missing-function-docstring
import datetime
import json
import os
import pathlib
import sys
import tempfile
import time

import nox
from nox.virtualenv import VirtualEnv

# Nox options
#  Reuse existing virtualenvs
nox.options.reuse_existing_virtualenvs = True
#  Don't fail on missing interpreters
nox.options.error_on_missing_interpreters = False

# Python versions to test against
PYTHON_VERSIONS = ("3", "3.5", "3.6", "3.7", "3.8", "3.9", "3.10", "3.11")
# Be verbose when running under a CI context
CI_RUN = (
    os.environ.get("JENKINS_URL") or os.environ.get("CI") or os.environ.get("DRONE") is not None
)
PIP_INSTALL_SILENT = CI_RUN is False
SKIP_REQUIREMENTS_INSTALL = "SKIP_REQUIREMENTS_INSTALL" in os.environ
EXTRA_REQUIREMENTS_INSTALL = os.environ.get("EXTRA_REQUIREMENTS_INSTALL")

SALT_REQUIREMENT = os.environ.get("SALT_REQUIREMENT") or "salt>=3003"
if SALT_REQUIREMENT == "salt==master":
    SALT_REQUIREMENT = "git+https://github.com/saltstack/salt.git@master"

# Prevent Python from writing bytecode
os.environ["PYTHONDONTWRITEBYTECODE"] = "1"

# Global Path Definitions
REPO_ROOT = pathlib.Path(__file__).resolve().parent
# Change current directory to REPO_ROOT
os.chdir(str(REPO_ROOT))

ARTIFACTS_DIR = REPO_ROOT / "artifacts"
# Make sure the artifacts directory exists
ARTIFACTS_DIR.mkdir(parents=True, exist_ok=True)
RUNTESTS_LOGFILE = (
    ARTIFACTS_DIR
    / "runtests-{}.log".format(  # pylint: disable=consider-using-f-string
        datetime.datetime.now().strftime("%Y%m%d%H%M%S.%f")
    )
)
COVERAGE_REPORT_DB = REPO_ROOT / ".coverage"
COVERAGE_REPORT_PROJECT = ARTIFACTS_DIR.relative_to(REPO_ROOT) / "coverage-project.xml"
COVERAGE_REPORT_TESTS = ARTIFACTS_DIR.relative_to(REPO_ROOT) / "coverage-tests.xml"
JUNIT_REPORT = ARTIFACTS_DIR.relative_to(REPO_ROOT) / "junit-report.xml"


def _get_session_python_version_info(session):
    try:
        version_info = session._runner._real_python_version_info
    except AttributeError:
        session_py_version = session.run_always(
            "python",
            "-c",
            'import sys; sys.stdout.write("{}.{}.{}".format(*sys.version_info))',
            silent=True,
            log=False,
        )
        version_info = tuple(int(part) for part in session_py_version.split(".") if part.isdigit())
        session._runner._real_python_version_info = version_info
    return version_info


def _get_pydir(session):
    version_info = _get_session_python_version_info(session)
    if version_info < (3, 5):
        session.error("Only Python >= 3.5 is supported")
    return "py{}.{}".format(*version_info)  # pylint: disable=consider-using-f-string


def _install_requirements(
    session,
    *passed_requirements,
    install_source=False,
    install_salt=False,
):
    if SKIP_REQUIREMENTS_INSTALL is False:
        # Always have the wheel package installed
        session.install(
            *passed_requirements, "--progress-bar=off", "wheel", silent=PIP_INSTALL_SILENT
        )

        if install_salt:
            session.install("--progress-bar=off", SALT_REQUIREMENT, silent=PIP_INSTALL_SILENT)

        if EXTRA_REQUIREMENTS_INSTALL:
            session.log(
                "Installing the following extra requirements because the "
                "EXTRA_REQUIREMENTS_INSTALL environment variable was set: "
                "EXTRA_REQUIREMENTS_INSTALL='%s'",
                EXTRA_REQUIREMENTS_INSTALL,
            )
            install_command = ["--progress-bar=off"]
            install_command += [req.strip() for req in EXTRA_REQUIREMENTS_INSTALL.split()]
            session.install(*install_command, silent=PIP_INSTALL_SILENT)

        if install_source:
            session.install("-e", "vector-engine", silent=PIP_INSTALL_SILENT)
            session.install("-e", "tempo-relay", silent=PIP_INSTALL_SILENT)


@nox.session(python=PYTHON_VERSIONS)
@nox.parametrize("component", ["vector-engine", "tempo-relay"], ids=["vector", "tempo"])
def tests(session, component):
    requirements_file = REPO_ROOT / "requirements" / "tests.txt"
    _install_requirements(
        session,
        "-r",
        str(requirements_file.relative_to(REPO_ROOT)),
        install_source=True,
    )

    sitecustomize_dir = session.run("salt-factories", "--coverage", silent=True, log=False)
    python_path_env_var = os.environ.get("PYTHONPATH") or None
    if python_path_env_var is None:
        python_path_env_var = sitecustomize_dir
    else:
        python_path_entries = python_path_env_var.split(os.pathsep)
        if sitecustomize_dir in python_path_entries:
            python_path_entries.remove(sitecustomize_dir)
        python_path_entries.insert(0, sitecustomize_dir)
        python_path_env_var = os.pathsep.join(python_path_entries)

    env = {
        # The updated python path so that sitecustomize is importable
        "PYTHONPATH": python_path_env_var,
        # The full path to the .coverage data file. Makes sure we always write
        # them to the same directory
        "COVERAGE_FILE": str(COVERAGE_REPORT_DB),
        # Instruct sub processes to also run under coverage
        "COVERAGE_PROCESS_START": str(REPO_ROOT / ".coveragerc"),
    }

    session.run("coverage", "erase")
    args = [
        "--rootdir",
        str(REPO_ROOT),
        f"--log-file={RUNTESTS_LOGFILE.relative_to(REPO_ROOT)}",
        "--log-file-level=debug",
        "--show-capture=no",
        f"--junitxml={JUNIT_REPORT}",
        "--showlocals",
        "-ra",
        "-s",
        "--cov",
        f"{component}/src",
    ]
    if session._runner.global_config.forcecolor:
        args.append("--color=yes")
    if not session.posargs:
        args.append(f"{component}/tests/")
    else:
        for arg in session.posargs:
            if arg.startswith("--color") and args[0].startswith("--color"):
                args.pop(0)
            args.append(arg)
        for arg in session.posargs:
            if arg.startswith("-"):
                continue
            if arg.startswith(f"{component}/tests{os.sep}"):
                break
            try:
                pathlib.Path(arg).resolve().relative_to(REPO_ROOT / component / "tests")
                break
            except ValueError:
                continue
        else:
            args.append(f"{component}/tests/")

    session.run("pytest", *args, env=env)


class Tee:
    """
    Python class to mimic linux tee behaviour
    """

    def __init__(self, first, second):
        self._first = first
        self._second = second

    def write(self, buf):
        wrote = self._first.write(buf)
        self._first.flush()
        self._second.write(buf)
        self._second.flush()
        return wrote

    def fileno(self):
        return self._first.fileno()


def _lint(session, rcfile, flags, paths, tee_output=True):
    requirements_file_lint = REPO_ROOT / "requirements" / "lint.txt"
    requirements_file_test = REPO_ROOT / "requirements" / "tests.txt"
    requirements_file_tempo = REPO_ROOT / "requirements" / "tempo.txt"
    _install_requirements(
        session,
        "-r",
        str(requirements_file_lint.relative_to(REPO_ROOT)),
        "-r",
        str(requirements_file_test.relative_to(REPO_ROOT)),
        "-r",
        str(requirements_file_tempo.relative_to(REPO_ROOT)),
        install_salt=True,
    )

    if tee_output:
        session.run("pylint", "--version")
        pylint_report_path = os.environ.get("PYLINT_REPORT")

    cmd_args = ["pylint", f"--rcfile={rcfile}"] + list(flags) + list(paths)

    python_path_env_var = os.environ.get("PYTHONPATH") or None
    src_paths = [str(REPO_ROOT / "vector-engine/src"), str(REPO_ROOT / "tempo-relay/src")]
    if python_path_env_var is None:
        python_path_env_var = os.pathsep.join(src_paths)
    else:
        python_path_entries = python_path_env_var.split(os.pathsep)
        for src_path in src_paths:
            if src_path in python_path_entries:
                python_path_entries.remove(src_path)
            python_path_entries.insert(0, src_path)
            python_path_env_var = os.pathsep.join(python_path_entries)

    env = {
        # The updated python path so that the project is importable without installing it
        "PYTHONPATH": python_path_env_var,
        "PYTHONUNBUFFERED": "1",
    }

    cmd_kwargs = {"env": env}

    if tee_output:
        stdout = tempfile.TemporaryFile(mode="w+b")
        cmd_kwargs["stdout"] = Tee(stdout, sys.__stdout__)

    try:
        session.run(*cmd_args, **cmd_kwargs)
    finally:
        if tee_output:
            stdout.seek(0)
            contents = stdout.read()
            if contents:
                contents = contents.decode("utf-8")
                sys.stdout.write(contents)
                sys.stdout.flush()
                if pylint_report_path:
                    # Write report
                    with open(pylint_report_path, "w", encoding="utf-8") as wfh:
                        wfh.write(contents)
                    session.log("Report file written to %r", pylint_report_path)
            stdout.close()


def _lint_pre_commit(session, rcfile, flags, paths):
    if "VIRTUAL_ENV" not in os.environ:
        session.error(
            "This should be running from within a virtualenv and "
            "'VIRTUAL_ENV' was not found as an environment variable."
        )
    if "pre-commit" not in os.environ["VIRTUAL_ENV"]:
        session.error(
            "This should be running from within a pre-commit virtualenv and "  # pylint: disable=consider-using-f-string
            "'VIRTUAL_ENV'({}) does not appear to be a pre-commit virtualenv.".format(
                os.environ["VIRTUAL_ENV"]
            )
        )

    # Let's patch nox to make it run inside the pre-commit virtualenv
    session._runner.venv = VirtualEnv(
        os.environ["VIRTUAL_ENV"],
        interpreter=session._runner.func.python,
        reuse_existing=True,
        venv=True,
    )
    _lint(session, rcfile, flags, paths, tee_output=False)


@nox.session(python="3")
def lint(session):
    """
    Run PyLint against the code and the test suite. Set PYLINT_REPORT to a path to capture output.
    """
    session.notify(f"lint-code-{session.python}")
    session.notify(f"lint-tests-{session.python}")


@nox.session(python="3", name="lint-code")
def lint_code(session):
    """
    Run PyLint against the code. Set PYLINT_REPORT to a path to capture output.
    """
    flags = ["--disable=I"]
    if session.posargs:
        paths = session.posargs
    else:
        paths = ["noxfile.py", "vector-engine/src/", "tempo-relay/src/"]
    _lint(session, ".pylintrc", flags, paths)


@nox.session(python="3", name="lint-tests")
def lint_tests(session):
    """
    Run PyLint against the test suite. Set PYLINT_REPORT to a path to capture output.
    """
    flags = [
        "--disable=I,redefined-outer-name,missing-function-docstring,no-member,missing-module-docstring"
    ]
    if session.posargs:
        paths = session.posargs
    else:
        paths = ["vector-engine/tests/", "tempo-relay/tests/"]
    _lint(session, ".pylintrc", flags, paths)


@nox.session(python=False, name="lint-code-pre-commit")
def lint_code_pre_commit(session):
    """
    Run PyLint against the code. Set PYLINT_REPORT to a path to capture output.
    """
    flags = ["--disable=I"]
    if session.posargs:
        paths = session.posargs
    else:
        paths = ["noxfile.py", "vector-engine/src/", "tempo-relay/src/"]
    _lint_pre_commit(session, ".pylintrc", flags, paths)


@nox.session(python=False, name="lint-tests-pre-commit")
def lint_tests_pre_commit(session):
    """
    Run PyLint against the code and the test suite. Set PYLINT_REPORT to a path to capture output.
    """
    flags = [
        "--disable=I,redefined-outer-name,missing-function-docstring,no-member,missing-module-docstring",
    ]
    if session.posargs:
        paths = session.posargs
    else:
        paths = ["vector-engine/tests/", "tempo-relay/tests/"]
    _lint_pre_commit(session, ".pylintrc", flags, paths)


@nox.session(python="3")
def docs(session):
    """
    Build Docs
    """
    requirements_file = REPO_ROOT / "requirements" / "docs.txt"
    _install_requirements(
        session, "-r", str(requirements_file.relative_to(REPO_ROOT)), install_source=True
    )
    os.chdir("docs/")
    session.run("make", "clean", external=True)
    session.run("make", "linkcheck", external=True)
    session.run("make", "coverage", "SPHINXOPTS=-Wn --keep-going", external=True)
    # session.run("make", "linkcheck", "SPHINXOPTS=-Wn --keep-going", external=True)
    # session.run("make", "coverage", "SPHINXOPTS=-Wn --keep-going", external=True)
    docs_coverage_file = os.path.join("_build", "html", "python.txt")
    if os.path.exists(docs_coverage_file):
        with open(docs_coverage_file, encoding="utf-8") as rfh:
            contents = rfh.readlines()[2:]
            if contents:
                session.error("\n" + "".join(contents))
    # session.run("make", "html", "SPHINXOPTS=-Wn --keep-going", external=True)
    session.run("make", "html", external=True)
    os.chdir(str(REPO_ROOT))


@nox.session(name="docs-crosslink-info", python="3")
def docs_crosslink_info(session):
    """
    Report intersphinx cross links information
    """
    requirements_file = REPO_ROOT / "requirements" / "docs.txt"
    _install_requirements(
        session,
        "-r",
        str(requirements_file.relative_to(REPO_ROOT)),
        install_source=True,
    )
    os.chdir("docs/")
    intersphinx_mapping = json.loads(
        session.run(
            "python",
            "-c",
            "import json; import conf; print(json.dumps(conf.intersphinx_mapping))",
            silent=True,
            log=False,
        )
    )
    try:
        mapping_entry = intersphinx_mapping[session.posargs[0]]
    except IndexError:
        session.error(
            "You need to pass at least one argument whose value must be one of: {}".format(  # pylint: disable=consider-using-f-string
                ", ".join(list(intersphinx_mapping))
            )
        )
    except KeyError:
        session.error(
            "Only acceptable values for first argument are: {}".format(  # pylint: disable=consider-using-f-string
                ", ".join(list(intersphinx_mapping))
            )
        )
    session.run(
        "python", "-m", "sphinx.ext.intersphinx", mapping_entry[0].rstrip("/") + "/objects.inv"
    )
    os.chdir(str(REPO_ROOT))


@nox.session(name="review", python="3")
def review(session):
    """
    Useful for code reviews - builds the docs locally and runs the full test suite.
    """
    session.notify("docs")
    session.notify(f"tests-{session.python}")


def _install_vector(session, version):
    tmp = session.create_tmp()
    if sys.platform == "darwin":
        url = f"https://packages.timber.io/vector/{version}/vector-{version}-x86_64-apple-darwin.tar.gz"
        extra = ""
    else:
        url = f"https://packages.timber.io/vector/{version}/vector-{version}-x86_64-unknown-linux-musl.tar.gz"
        extra = "--wildcards"
    bin = f"{tmp}/vector"
    if not os.path.isfile(bin) or (time.time() - os.path.getmtime(bin)) > 3600:
        session.run_always(
            "sh",
            "-c",
            " ".join(
                [
                    "curl",
                    "-sSfL",
                    url,
                    "|",
                    "tar",
                    "xzmf",
                    "-",
                    "-C",
                    tmp,
                    "--strip-components=3",
                    extra,
                    "*/bin/vector",
                ]
            ),
        )
    return os.path.abspath(bin)


@nox.session(name="vector", python=False)
@nox.parametrize("vector", ["0.29.1", "latest"])
def vector(session, vector):
    """
    Run Vector tests
    """
    vector_bin = _install_vector(session, vector)
    session.run(
        vector_bin,
        "validate",
        "--no-environment",
        "vector-engine/etc/vector.toml",
    )
    session.run(
        vector_bin,
        "test",
        "vector-engine/etc/vector.toml",
        "vector-engine/tests/test_vector.toml",
        env={"TZ": "UTC"},  # To fix the timestamp test
    )


@nox.session(name="vector-graph", python=False)
def vector_graph(session):
    vector_bin = _install_vector(session, "latest")
    session.run(
        "sh",
        "-c",
        f"{vector_bin} graph --config vector-engine/etc/vector.toml | dot -Tpng > docs/_static/vector-graph.png",
    )
