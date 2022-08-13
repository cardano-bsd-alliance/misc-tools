#!/usr/bin/env bash

# Parts of this script were borrowed from input-output-hk/cardano-db-sync repo.

# Unoffiical bash strict mode.
# See: http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -u
set -o pipefail

# Modify based on your environment

service_name="cardano_db_sync"
network_name="mainnet"
minio_upload_path="s3/psb-dbsync/files/13-aarch64/"
pz_thr="4"

# Do not modify past this line

export PGPASSFILE="/var/db/${service_name}/${network_name}-configs/.pgpass"

function check_pgpass_file {
  if test -z ${PGPASSFILE+x} ; then
        echo "Error: The PGPASSFILE env var should be set to the location of the pgpass file."
        echo
        exit 1
        fi

  if test ! -f "${PGPASSFILE}" ; then
    echo "Error: PostgreSQL password file ${PGPASSFILE} does not exist."
    exit 1
    fi

        export PGHOST=$(cut -d ":" -f 1 "${PGPASSFILE}")
        export PGPORT=$(cut -d ":" -f 2 "${PGPASSFILE}")
        export PGDATABASE=$(cut -d ":" -f 3 "${PGPASSFILE}")
        user=$(cut -d ":" -f 4 "${PGPASSFILE}")
        if [ "$user" != "*" ]; then
                export PGUSER=$user
        fi;
}

function check_db_exists {
        set +e
        count=$(psql -l "${PGDATABASE}" | grep -c "${PGDATABASE} ")
        if test "${count}" -lt 1 ; then
                echo
                echo "Error : No '${PGDATABASE}' database."
                exit 1
                fi
        count=$(psql -l "${PGDATABASE}" | grep "${PGDATABASE} " | cut -d \| -f 3 | grep -c UTF8)
        if test "${count}" -ne 1 ; then
                echo
                echo "Error : '${PGDATABASE}' database exists, but is not UTF8."
                echo
                exit 1
                fi
        set -e
}

check_pgpass_file
check_db_exists

service ${service_name} stop

SNAP_OUT=$( (yes phrase ||:) | cardano-db-tool prepare-snapshot \
        --state-dir /var/db/${service_name}/${network_name}-state | tail -n 1)
SNAP_NAME="$(echo $SNAP_OUT | cut -d " " -f3)"
SNAP_LSTATE="$(echo $SNAP_OUT | cut -d " " -f4)"

tgz_file=$SNAP_NAME.tgz
dbfile=$SNAP_NAME.sql
ledger_file=$SNAP_LSTATE
tmp_dir=$(mktemp -d -t data/db-sync-snapshot)
echo $"Working directory: ${tmp_dir}"
pg_dump --no-owner --schema=public "${PGDATABASE}" > "${tmp_dir}/$SNAP_NAME.sql"
cp "$ledger_file" "$tmp_dir/$(basename "${ledger_file}")"

service ${service_name} start

tar cv --directory "${tmp_dir}" "${dbfile}" "$(basename "${ledger_file}")" | pigz -p${pz_thr} | tee "${tgz_file}.tmp" \
       | sha256sum | head -c 64 | sed -e "s/$/  ${tgz_file}\n/" > "${tgz_file}.sha256sum"

mv "${tgz_file}.tmp" "${tgz_file}"
rm -rf "${tmp_dir}"

if test "$(gzip --test "${tgz_file}")" ; then
         echo "Gzip reports the snapshot file as being corrupt."
         echo "It is not safe to drop the database and restore using this file."
         exit 1
         fi

echo "Created ${tgz_file} - Uploading..."
minio-client cp -a --md5 "${tgz_file}" "${tgz_file}.sha256sum" "${minio_upload_path}"
