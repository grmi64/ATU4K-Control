#!/bin/sh
set -eu
cd "$(dirname "$0")"
node tests/controller.cjs
node tests/replies.cjs
node tests/status-ui.cjs
work=$(mktemp -d "${TMPDIR:-/tmp}/atu4k-tests.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work/cache"
run() {
    test_name=$1
    shift
    swiftc -module-cache-path "$work/cache" "$@" "tests/$test_name.swift" -o "$work/$test_name"
    "$work/$test_name"
}
run MotorGateTests src/MotorGate.swift
run MemoryGateTests src/MemoryGate.swift src/MotorGate.swift
run SettingsBackupTests src/SettingsBackup.swift
run USBDiscoveryTests src/USBDiscovery.swift src/USBStatus.swift src/MotorGate.swift src/MemoryGate.swift -framework IOKit
for test_name in USBStatusTests MotorUSBTests MemoryUSBTests USBOpenCancellationTests; do
    run "$test_name" src/USBStatus.swift src/MotorGate.swift src/MemoryGate.swift
 done
run DXCBridgeTests src/DXCBridge.swift -framework Network
