function resign-ipa -d "Re-sign an IPA with a provisioning profile and developer identity"
    # Prerequisites (one-time Xcode setup):
    # 1. Pair your device (e.g., Apple TV) with Xcode:
    #    - Apple TV: Settings → Remotes and Devices → Remote App and Devices
    #    - Xcode: Window → Devices and Simulators — verify device appears
    # 2. Create a dummy Xcode project (e.g., tvOS app) with the desired bundle ID
    #    (e.g., com.inkatze.stremio). Free accounts can't use existing App Store bundle IDs.
    # 3. Set your team in Signing & Capabilities (click project → target → Signing & Capabilities)
    # 4. Select the device as destination and build (Cmd+R) to generate a provisioning profile
    # 5. After that, this function can re-sign IPAs using the generated profile.
    #    Free developer accounts expire after 7 days, so re-run this when the app stops launching.

    argparse 'h/help' 'b/bundle-id=' 'p/profile=' 'i/identity=' 'o/output=' -- $argv
    or return 1

    if set -q _flag_help; or test (count $argv) -eq 0
        echo "Usage: resign-ipa [options] <path-to-ipa>"
        echo ""
        echo "Prerequisites (one-time Xcode setup):"
        echo "  1. Pair device with Xcode (Window → Devices and Simulators)"
        echo "  2. Create a dummy Xcode project with the desired bundle ID"
        echo "  3. Set your team in Signing & Capabilities"
        echo "  4. Build to the device (Cmd+R) to generate a provisioning profile"
        echo ""
        echo "Options:"
        echo "  -b, --bundle-id  Bundle ID to use (default: com.inkatze.stremio)"
        echo "  -p, --profile    Path to .mobileprovision file (default: auto-detect)"
        echo "  -i, --identity   Signing identity (default: auto-detect)"
        echo "  -o, --output     Output IPA path (default: <name>_signed.ipa)"
        echo "  -h, --help       Show this help"
        return 0
    end

    set -l ipa_path $argv[1]
    set -l bundle_id (set -q _flag_bundle_id; and echo $_flag_bundle_id; or echo "com.inkatze.stremio")

    if not test -f "$ipa_path"
        echo "Error: IPA file not found: $ipa_path"
        return 1
    end

    # Auto-detect signing identity
    set -l identity
    if set -q _flag_identity
        set identity $_flag_identity
    else
        set identity (security find-identity -v -p codesigning | grep "Apple Development" | head -1 | sed 's/.*"\(.*\)".*/\1/')
        if test -z "$identity"
            echo "Error: No Apple Development signing identity found"
            return 1
        end
    end

    # Auto-detect provisioning profile matching bundle ID
    set -l profile
    if set -q _flag_profile
        set profile $_flag_profile
    else
        set -l profiles_dir ~/Library/Developer/Xcode/UserData/Provisioning\ Profiles
        for p in $profiles_dir/*.mobileprovision
            set -l app_id (security cms -D -i "$p" 2>/dev/null | plutil -extract Entitlements.application-identifier raw -o - -)
            if string match -q "*.$bundle_id" "$app_id"
                set profile $p
                break
            end
        end
        if test -z "$profile"
            echo "Error: No provisioning profile found for bundle ID: $bundle_id"
            echo "Build a dummy Xcode project with this bundle ID to your device first."
            return 1
        end
    end

    # Output path
    set -l output
    if set -q _flag_output
        set output $_flag_output
    else
        set output (string replace -r '\.ipa$' '_signed.ipa' "$ipa_path")
    end

    set -l workdir (mktemp -d)

    echo "Resigning IPA..."
    echo "  IPA:       $ipa_path"
    echo "  Bundle ID: $bundle_id"
    echo "  Identity:  $identity"
    echo "  Profile:   $profile"
    echo "  Output:    $output"
    echo ""

    # Extract
    echo "Extracting..."
    unzip -o "$ipa_path" -d "$workdir" >/dev/null 2>&1
    or begin
        echo "Error: Failed to extract IPA"
        rm -rf "$workdir"
        return 1
    end

    set -l app_path (find "$workdir/Payload" -name "*.app" -maxdepth 1 | head -1)
    if test -z "$app_path"
        echo "Error: No .app bundle found in IPA"
        rm -rf "$workdir"
        return 1
    end

    # Update bundle ID
    echo "Updating bundle ID..."
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $bundle_id" "$app_path/Info.plist"

    # Embed provisioning profile
    echo "Embedding provisioning profile..."
    cp "$profile" "$app_path/embedded.mobileprovision"

    # Extract entitlements
    set -l entitlements (mktemp).plist
    security cms -D -i "$profile" 2>/dev/null | plutil -extract Entitlements xml1 -o "$entitlements" -
    or begin
        echo "Error: Failed to extract entitlements"
        rm -rf "$workdir"
        return 1
    end

    # Sign frameworks
    if test -d "$app_path/Frameworks"
        echo "Signing frameworks..."
        for framework in $app_path/Frameworks/*
            codesign --force --sign "$identity" --timestamp=none "$framework" 2>&1
        end
    end

    # Sign app
    echo "Signing app..."
    codesign --force --sign "$identity" --entitlements "$entitlements" --timestamp=none "$app_path" 2>&1
    or begin
        echo "Error: Code signing failed"
        rm -rf "$workdir" "$entitlements"
        return 1
    end

    # Repackage
    echo "Repackaging..."
    cd "$workdir"
    zip -r "$output" Payload/ >/dev/null 2>&1
    cd -

    # Cleanup
    rm -rf "$workdir" "$entitlements"

    echo ""
    echo "Done! Signed IPA: $output"
    echo "Install via: Xcode → Window → Devices and Simulators → + → select the IPA"
end
