autoload -Uz vcs_info
autoload -Uz add-zsh-hook
setopt prompt_subst

zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git*' formats ' %b'

PROMPT_SYMBOL='▷'

# indicate a job (for example, vim) has been backgrounded
# If there is a job in the background, display a ✱
suspended_jobs() {
    local sj
    sj=$(jobs 2>/dev/null | tail -n 1)
    if [[ $sj == "" ]]; then
        echo ""
    else
        echo "%{%F{208}%}✱%f"
    fi
}

node_prompt() {
    [[ -f package.json || -d node_modules ]] || return

    local version=''
    local node_icon='\ue718'

    if dotfiles::exists node; then
        version=$(node -v 2>/dev/null)
    fi

    [[ -n version ]] || return

    dotfiles::print '029' "$node_icon $version"
}

git_status_done() {
    # $3 is the stdout of the git_status command
    RPROMPT="$3 $(suspended_jobs)"
    zle reset-prompt
}

git_status() {
    cd -q "$1"
    dotfiles::is_git || return

    vcs_info

    local git_branch="$vcs_info_msg_0_"
    # ${parameter#word} 前方一致除去
    # git_branchから'heads/'に一致する部分を除去して、
    # その後ろを残す。
    git_branch="${git_branch#heads/}"
    # ${parameter/pattern/string} 文字列置換
    # git_branchから'...'を取り除く
    git_branch="${git_branch/.../}"

    [[ -z "$git_branch" ]] && return

    local INDEX git_status=""

    GIT_SYMBOL="\ue725"
    GIT_STATUS_ADDED=$(dotfiles::print '002' '+')
    GIT_STATUS_MODIFIED=$(dotfiles::print '003' '!')
    GIT_STATUS_UNTRACKED=$(dotfiles::print '009' '?')
    GIT_STATUS_RENAMED=$(dotfiles::print '208' '»')
    GIT_STATUS_TYPECHG=$(dotfiles::print '208' '»')
    GIT_STATUS_DELETED=$(dotfiles::print '161' '✘')
    GIT_STATUS_STASHED=$(dotfiles::print '003' '$')
    GIT_STATUS_UNMERGED=$(dotfiles::print '016' '=')
    GIT_STATUS_AHEAD=$(dotfiles::print '012' '⇡')
    GIT_STATUS_BEHIND=$(dotfiles::print '011' '⇣')
    GIT_STATUS_DIVERGED=$(dotfiles::print '012' '⇕')
    GIT_STATUS_CLEAN=$(dotfiles::print '002' '✔')

#    INDEX=$(command git status --porcelain -b 2>/dev/null)
    INDEX=$(command git status --porcelain --ignore-submodules=dirty -b 2>/dev/null)

    # Check for untracked files
    # gitのstatus (XY)はXがindexのstatus、Yがworktreeのstatus
    # M: modified
    # A: added
    # D: deleted
    # R: renamed
    # C: copied
    # U: unmerged
    # T: typechange <- adhock introduction
    #
    # grepの正規表現
    # [] 括弧内の任意の一文字
    # ^/$ 行の先頭/末尾
    if $(echo "$INDEX" | command grep -E '^\?\? ' &> /dev/null); then
        git_status="$GIT_STATUS_UNTRACKED$git_status"
    fi

    # Check for staged files
    if $(echo "$INDEX" | command grep '^A[ MDAU] ' &> /dev/null); then
        git_status="$GIT_STATUS_ADDED$git_status"
    elif $(echo "$INDEX" | command grep '^M[ MD] ' &> /dev/null); then
        git_status="$GIT_STATUS_ADDED$git_status"
    elif $(echo "$INDEX" | command grep '^UA' &> /dev/null); then
        git_status="$GIT_STATUS_ADDED$git_status"
    fi

    # Check for modified files
    if $(echo "$INDEX" | command grep '^[ MARC ]M ' &> /dev/null); then
        git_status="$GIT_STATUS_MODIFIED$git_status"
    fi

    # Check for renamed files
    if $(echo "$INDEX" | command grep '^R[ MD] ' &> /dev/null); then
        git_status="$GIT_STATUS_RENAMED$git_status"
    fi

    # Check for typechanged files
    if $(echo "$INDEX" | command grep '^T  ' &> /dev/null); then
        git_status="$GIT_STATUS_TYPECHG$git_status"
    elif $(echo "$INDEX" | command grep ' T ' &> /dev/null); then
        git_status="$GIT_STATUS_TYPECHG$git_status"
    fi

    # Check for deleted files
    if $(echo "$INDEX" | command grep '^[MARCDU ]D ' &> /dev/null); then
        git_status="$GIT_STATUS_DELETED$git_status"
    elif $(echo "$INDEX" | command grep '^D[ UM] ' &> /dev/null); then
        git_status="$GIT_STATUS_DELETED$git_status"
    fi

    # Check for stashes
    if $(command git rev-parse --verify refs/stash >/dev/null 2>&1); then
        git_status="$GIT_STATUS_STASHED$git_status"
    fi

    # Check for unmerged files
    if $(echo "$INDEX" | command grep '^U[UDA] ' &> /dev/null); then
        git_status="$GIT_STATUS_UNMERGED$git_status"
    elif $(echo "$INDEX" | command grep '^AA ' &> /dev/null); then
        git_status="$GIT_STATUS_UNMERGED$git_status"
    elif $(echo "$INDEX" | command grep '^DD ' &> /dev/null); then
        git_status="$GIT_STATUS_UNMERGED$git_status"
    elif $(echo "$INDEX" | command grep '^[DA]U ' &> /dev/null); then
        git_status="$GIT_STATUS_UNMERGED$git_status"
    fi

    # Check whether branch is ahead
    local is_ahead=false
    if $(echo "$INDEX" | command grep '^## [^ ]\+ .*ahead' &> /dev/null); then
        is_ahead=true
    fi

    # Check whether branch is behind
    local is_behind=false
    if $(echo "$INDEX" | command grep '^## [^ ]\+ .*behind' &> /dev/null); then
        is_behind=true
    fi

    # Check wheather branch has diverged
    if [[ "$is_ahead" == true && "$is_behind" == true ]]; then
        git_status="$GIT_STATUS_DIVERGED$git_status"
    else
        [[ "$is_ahead" == true ]] && git_status="$GIT_STATUS_AHEAD$git_status"
        [[ "$is_behind" == true ]] && git_status="$GIT_STATUS_BEHIND$git_status"
    fi

    [[ -n "$git_status" ]] || git_status="$GIT_STATUS_CLEAN"

    dotfiles::bold "$git_status"
    dotfiles::print '241' "$git_branch"
}

async_init
# Start a new worker
async_start_worker vcs_info
# Register a callback for completed jobs.
async_register_callback vcs_info git_status_done

add-zsh-hook precmd () {
    print -P "\n\e[1m%F{075}%~\e[0m $(node_prompt)"
    async_job vcs_info git_status "$PWD"
}


export PROMPT='%(?.%F{006}.%F{009})$PROMPT_SYMBOL%f '
#https://qiita.com/gorohash/items/e622459b330cbaef5fe5
#OSによっては、RPROMPTの右側に意味のないスペースが入ってしまい。
#左側のプロンプトがカーソルと干渉する。エスケープシーケンスも
#文字数とカウントして右側にスペースを取ってしまうのが原因らしい。
#完全に治らないので、元に戻す。
export RPROMPT="$(suspended_jobs)"
