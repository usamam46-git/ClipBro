#!/bin/bash
# Source from build/test scripts. Override CLIPBRO_SDK to select another installed SDK.
if [[ -z "${CLIPBRO_SDK:-}" ]]; then
    CLIPBRO_SDK="$(xcrun --sdk macosx --show-sdk-path)"
    # The host's CLT macOS 27 SDK advertises SwiftUI macros without their plugin.
    if [[ "$CLIPBRO_SDK" == /Library/Developer/CommandLineTools/* ]] && [[ -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk ]]; then
        CLIPBRO_SDK=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
    fi
fi
