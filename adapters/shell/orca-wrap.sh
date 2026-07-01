# Orca shell helpers — source this from your ~/.zshrc or ~/.bashrc:
#   source /path/to/ai-reminder/adapters/shell/orca-wrap.sh
#
# Then monitor any long-running command in Orca:
#   ab aider
#   ab -- npm run build

# `ab` wraps a command with `orca wrap`. Anything after `--` runs verbatim.
ab() {
    if [ "$1" = "--" ]; then
        shift
    fi
    orca wrap -- "$@"
}
