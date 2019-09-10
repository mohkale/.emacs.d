#!/usr/bin/bash
# cleans the user ~/.emacs.d/ directory by removing any and all
# non essential files and moving them to the recycle bin. does so
# by first checking that any file which may be removed is not
# included in my home git repo, then checks a file against some
# predefined rules and finally passes the argv values for this
# script to find to filter out any remaining files which should
# be kept.
#
# WARN windows sucks!!! clearing out all files to the trashcan slows windows
#      to a crawl when visiting the trash can in windows explorer. Worse...
#      stay in the trash can for long enough and your computer will crash,
#      even if your in a completely different program. Whats even worse, if
#      MAXPROCS is too high, windows will also crash (tried it with 10...
#      crashed)... so keep it low, delete when you can and set windows on
#      fire when you get a chance :P

linux_trash_command() { #(filepath)
    printf "trash not yet implemented for Linux: %s\n" "$*" >&2
}
export -f linux_trash_command

windows_trash_command() { #(filepath)
    for file in "$@"; do
        echo "removing: ${file}"
    done

    recycle "$@"
}
export -f windows_trash_command

macos_trash_command() { #(filepath)
    printf "trash not yet implemented for MacOS Darwin: %s\n" "$*" >&2
}
export -f macos_trash_command

get_tracked_exclusion_filters() {
    git --git-dir="${DOTFILES_REPO_PATH}" --work-tree=${HOME} ls-files ~/.emacs.d |
        sed -E -e "s/( |')"'/\\\1/g' -e 's/^(.*)$/-not -wholename .\/\1/' |
        tr '\n' ' '
}

MAXPROCS=3

pushd ~/.emacs.d/ 2>/dev/null 1>&2

case "${OSTYPE}" in
    *cygwin|*msys|*win32)
        TRASH_COMMAND=windows_trash_command
        ;;
    *linux-gnu|*freebsd)
        TRASH_COMMAND=linux_trash_command
        ;;
    *darwin)
        TRASH_COMMAND=macos_trash_Command
        ;;
    *)
        printf "unable to determine trash command for os: %s\n" "${OSTYPE}" >&2
        exit 1
        ;;
esac

find ./ -depth -type f $(get_tracked_exclusion_filters) \
    -not -wholename './etc/*.org'                       \
    "$@"                                                \
    -print0 | xargs --no-run-if-empty -0 -P${MAXPROCS} bash -c ${TRASH_COMMAND}' "$@"' '{}'

find ./ -type d -empty -delete

# erase installed packages from customise
CUSTOMISE_FILE=~/.emacs.d/etc/custom.el

if [ -r ${CUSTOMISE_FILE} ]; then
    PACKAGES_EXIST_PATTERN='(package-selected-packages\n\s*\(quote\n\s*\()([A-Za-z0-9\-\: ]+)(\)\)\))'

    PACKAGES=$(pcregrep -M -o2 "${PACKAGES_EXIST_PATTERN}" "${CUSTOMISE_FILE}" 2>/dev/null)
    if [ $? -eq 0 ]; then READING_INPUT=0; fi # only input when there's something to erase

    while [ ! -z "${READING_INPUT}" ] && [ "${READING_INPUT}" -eq 0 ]; do
        read -r -p "would you like to erase installed packages from: ${CUSTOMISE_FILE} (Y/n) " -n 1 prompt
        echo

        case "${prompt}" in
            [yY])
                ERASE=True
                READING_INPUT=1
                ;;
            [nN])
                # ERASE=FALSE
                READING_INPUT=1
                ;;
        esac
    done

    if [ "${ERASE}" == "True" ]; then
        counter=1
        echo "${PACKAGES}" | tr " " "\n" | while read package; do
            printf "removing package %03d: %s\n" "${counter}" "${package}"
            ((counter++))
        done

        sed -e 's/'"${PACKAGES}"'//' -i "${CUSTOMISE_FILE}"
    fi
fi
