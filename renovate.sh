#!/bin/bash
set -euo pipefail

# this executes renovate against the local repository.
# NB this uses a temporary gitea instance because running renovate against a
#    local directory not (yet?) supported.
#    see https://github.com/renovatebot/renovate/issues/3609

export RENOVATE_USERNAME='renovate'
export RENOVATE_NAME='Renovate Bot'
export RENOVATE_PASSWORD='password'
export RENOVATE_ENDPOINT="http://localhost:3000"
export GIT_PUSH_REPOSITORY="http://$RENOVATE_USERNAME:$RENOVATE_PASSWORD@localhost:3000/$RENOVATE_USERNAME/test.git"
gitea_container_name="$(basename "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")-renovate-gitea"

# see https://hub.docker.com/r/gitea/gitea/tags
# renovate: datasource=docker depName=gitea/gitea
gitea_version='1.19.1'

# see https://hub.docker.com/r/renovate/renovate/tags
# renovate: datasource=docker depName=renovate/renovate extractVersion=(?<version>.+)-slim$
renovate_version='35.58.2'

# clean.
echo 'Deleting existing Gitea...'
docker rm --force "$gitea_container_name" >/dev/null 2>&1
echo 'Deleting existing temporary files...'
rm -f tmp/renovate-*

# start gitea in background.
# see https://docs.gitea.io/en-us/config-cheat-sheet/
# see https://github.com/go-gitea/gitea/releases
# see https://github.com/go-gitea/gitea/blob/v1.19.1/docker/root/etc/s6/gitea/setup
echo 'Starting Gitea...'
docker run \
    --detach \
    --name "$gitea_container_name" \
    -v /etc/timezone:/etc/timezone:ro \
    -v /etc/localtime:/etc/localtime:ro \
    -e SECRET_KEY=abracadabra \
    -p 3000:3000 \
    "gitea/gitea:$gitea_version" \
    >/dev/null
# wait for gitea to be ready.
bash -euc 'while [ -z "$(wget -qO- http://localhost:3000/api/v1/version | jq -r ".version | select(.!=null)")" ]; do sleep 5; done'

# create user in gitea.
echo "Creating Gitea $RENOVATE_USERNAME user..."
docker exec --user git "$gitea_container_name" gitea admin user create \
    --admin \
    --email "$RENOVATE_USERNAME@example.com" \
    --username "$RENOVATE_USERNAME" \
    --password "$RENOVATE_PASSWORD"
curl \
    -s \
    -u "$RENOVATE_USERNAME:$RENOVATE_PASSWORD" \
    -X 'PATCH' \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -d "{\"full_name\":\"$RENOVATE_NAME\"}" \
    "http://localhost:3000/api/v1/user/settings" \
    | jq \
    > /dev/null

# create the user personal access token.
# see https://docs.gitea.io/en-us/api-usage/
# see https://docs.gitea.io/en-us/oauth2-provider/#scopes
# see https://try.gitea.io/api/swagger#/user/userCreateToken
echo "Creating Gitea $RENOVATE_USERNAME user personal access token..."
install -d tmp
curl \
    -s \
    -u "$RENOVATE_USERNAME:$RENOVATE_PASSWORD" \
    -X POST \
    -H "Content-Type: application/json" \
    -d '{"name": "renovate", "scopes": ["repo"]}' \
    "http://localhost:3000/api/v1/users/$RENOVATE_USERNAME/tokens" \
    | jq -r .sha1 \
    >tmp/renovate-gitea-token.txt

# try the token.
export RENOVATE_TOKEN="$(cat tmp/renovate-gitea-token.txt)"
curl \
    -s \
    -H "Authorization: token $RENOVATE_TOKEN" \
    -H 'Accept: application/json' \
    "http://localhost:3000/api/v1/user" \
    | jq \
    > /dev/null

# create remote repository in gitea.
echo "Creating Gitea $RENOVATE_USERNAME test repository..."
curl \
    -s \
    -u "$RENOVATE_USERNAME:$RENOVATE_PASSWORD" \
    -X POST \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -d '{"name": "test"}' \
    http://localhost:3000/api/v1/user/repos \
    | jq \
    > /dev/null

# push the code to local gitea repository.
# NB running renovate locally is not yet supported.
#    see https://github.com/renovatebot/renovate/issues/3609
echo "Pushing local repository to Gitea $RENOVATE_USERNAME test repository..."
git push --force "$GIT_PUSH_REPOSITORY"

# see https://docs.renovatebot.com/modules/platform/gitea/
# see https://docs.renovatebot.com/self-hosted-configuration/#dryrun
# see https://github.com/renovatebot/renovate/blob/main/docs/usage/examples/self-hosting.md
# see https://github.com/renovatebot/renovate/tree/main/lib/modules/datasource
# see https://github.com/renovatebot/renovate/tree/main/lib/modules/versioning
export RENOVATE_TOKEN="$(cat tmp/renovate-gitea-token.txt)"
# NB these can also be passed as raw positional arguments to docker run.
export RENOVATE_REPOSITORIES="$RENOVATE_USERNAME/test"
# see https://docs.github.com/en/rest/rate-limit#get-rate-limit-status-for-the-authenticated-user
# see https://github.com/settings/tokens
# NB this is only used for authentication. the token should not have any scope enabled.
#export GITHUB_COM_TOKEN='TODO-YOUR-TOKEN'
# let renovate create all the required pull requests.
# see https://docs.renovatebot.com/configuration-options/#prhourlylimit
# see https://docs.renovatebot.com/configuration-options/#prconcurrentlimit
export RENOVATE_PR_HOURLY_LIMIT='0'
export RENOVATE_PR_CONCURRENT_LIMIT='0'
echo 'Running renovate...'
install -d tmp
# NB use --dry-run=lookup for not modifying the repository (e.g. for not
#    creating pull requests).
docker run \
  --rm \
  --tty \
  --interactive \
  --net host \
  --env GITHUB_COM_TOKEN \
  --env RENOVATE_ENDPOINT \
  --env RENOVATE_TOKEN \
  --env RENOVATE_REPOSITORIES \
  --env RENOVATE_PR_HOURLY_LIMIT \
  --env RENOVATE_PR_CONCURRENT_LIMIT \
  --env LOG_LEVEL=debug \
  --env LOG_FORMAT=json \
  "renovate/renovate:$renovate_version-slim" \
  --platform=gitea \
  --git-url=endpoint \
  >tmp/renovate-log.json

echo 'Getting results...'
# extract the errors.
jq 'select(.err)' tmp/renovate-log.json >tmp/renovate-errors.json
# extract the result from the renovate log.
jq 'select(.msg == "packageFiles with updates") | .config' tmp/renovate-log.json >tmp/renovate-result.json
# extract all the dependencies.
jq 'to_entries[].value[] | {packageFile,dep:.deps[]}' tmp/renovate-result.json >tmp/renovate-dependencies.json
# extract the dependencies that have updates.
jq 'select((.dep.updates | length) > 0)' tmp/renovate-dependencies.json >tmp/renovate-dependencies-updates.json

# helpers.
function show-title {
    echo
    echo '#'
    echo "# $1"
    echo '#'
    echo
}

# show dependencies.
function show-dependencies {
    show-title "$1"
    (
        printf 'packageFile\tdatasource\tdepName\tcurrentValue\tnewVersions\tskipReason\twarnings\n'
        jq \
            -r \
            '[
                .packageFile,
                .dep.datasource,
                .dep.depName,
                .dep.currentValue,
                (.dep | select(.updates) | .updates | map(.newVersion) | join(" | ")),
                .dep.skipReason,
                (.dep | select(.warnings) | .warnings | map(.message) | join(" | "))
            ] | @tsv' \
            "$2" \
            | sort
    ) | column -t -s "$(printf \\t)"
}
show-dependencies 'Dependencies' tmp/renovate-dependencies.json
show-dependencies 'Dependencies Updates' tmp/renovate-dependencies-updates.json

# show errors.
if [ "$(jq --slurp length tmp/renovate-errors.json)" -ne '0' ]; then
    show-title errors
    jq . tmp/renovate-errors.json
fi

# show the gitea project.
show-title "See PRs at http://localhost:3000/$RENOVATE_USERNAME/test/pulls (you can login as $RENOVATE_USERNAME:$RENOVATE_PASSWORD)"
