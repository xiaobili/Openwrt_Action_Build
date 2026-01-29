#!/bin/sh
# update.sh - replace two lines in netwrok_init with ucidef_set_interfaces_lan_wan "eth1 eth2 eth3" "eth0"

set -eu

TARGET="package/base-files/files/etc/board.d/99-default_network"
REPL='ucidef_set_interfaces_lan_wan "eth1 eth2 eth3" "eth0"'

[ -f "$TARGET" ] || { echo "target not found: $TARGET" >&2; exit 1; }

# no-op if already present
grep -q '^[[:space:]]*ucidef_set_interfaces_lan_wan' "$TARGET" && exit 0


awk -v repl="$REPL" '
    BEGIN { done = 0 }
    {
        if (!done && $0 ~ /^[[:space:]]*ucidef_set_interface_lan[[:space:]]/) {
            # skip this line; peek next
            if (getline nxt) {
                if (nxt ~ /^[[:space:]]*\[ -d[[:space:]]+\/sys\/class\/net\/eth1/ && nxt ~ /ucidef_set_interface_wan/) {
                    # skip nxt too
                } else {
                    print nxt
                }
            }
            print repl
            done = 1
        } else {
            print
        }
    }
    END {
        if (!done) print repl
    }
' "$TARGET" > "$TARGET.tmp" && mv "$TARGET.tmp" "$TARGET"