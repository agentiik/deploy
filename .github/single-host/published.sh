# shellcheck shell=bash
# Sourced by the jobs of the single-host workflow, which install the release a compose.yaml names by default where it is published, and the images of main otherwise.

# default_version prints the version a compose.yaml runs where nothing sets AGENTIIK_VERSION: the highest its images name, since an image new in a release names that release before the others are moved to it.
default_version() {
  sed -n 's/.*AGENTIIK_VERSION:-\([^}]*\)}.*/\1/p' "$1" | sort -uV | tail -n 1
}

# published succeeds where a version is released: its image of the API and the controller on ghcr.io, and its tag on the engine, which agk is installed from. Until both exist, the test runs the images of main, tagged dev, and agk from main.
published() {
  docker manifest inspect "ghcr.io/agentiik/agentiik:$1" >/dev/null 2>&1 &&
    git ls-remote --exit-code --tags https://github.com/agentiik/agentiik.git "refs/tags/$1" >/dev/null
}
