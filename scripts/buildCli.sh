#! /bin/bash

HEAD="# %OPM_SPLICE_HEAD_MARKER%"
FOOT="# %OPM_SPLICE_FOOT_MARKER%"

lib="$(awk "/${HEAD}/{flag=1; next} /${FOOT}/{flag=0} flag" ../libopm.sh)"
indent_lib=""

cat > ../opm << EOF
#! /bin/sh
# NOTE: This file is not designed for editing; it is generated! Instead, make
# adjustments to libopm.sh and scripts/buildCli.sh.

opm_cli() {
unset -f opm_cli

$lib

opm_cli "\$@"
}

alias opm="opm_cli"

# This is not _guaranteed_ to work on POSIX-only systems, but it's very close.
# Credit: https://stackoverflow.com/a/28776166/6759411
sourced=0
if [ -n "\$ZSH_EVAL_CONTEXT" ]; then 
    case \$ZSH_EVAL_CONTEXT in *:file) sourced=1;; esac
elif [ -n "\$KSH_VERSION" ]; then
    [ "\$(cd \$(dirname -- \$0) && pwd -P)/\$(basename -- \$0)" != "\$(cd \$(dirname -- \${.sh.file}) && pwd -P)/\$(basename -- \${.sh.file})" ] && sourced=1
elif [ -n "\$BASH_VERSION" ]; then
    (return 2>/dev/null) && sourced=1 
else # All other shells: examine \$0 for known shell binary filenames
    # Detects \`sh\` and \`dash\`; add additional shell filenames as needed.
    case \${0##*/} in sh|dash) sourced=1;; esac
fi

if [ "\$sourced" -eq 0 ]; then
    opm_cli "\$@"
fi
EOF

chmod +x ../opm
