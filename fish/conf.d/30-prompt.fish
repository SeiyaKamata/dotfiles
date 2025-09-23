# Prompt configuration

function fish_prompt
    # User@host (only show if not default)
    set -l user_host ""
    if test "$USER@"(hostname) != "kmt2000200@SeiyaKamatanoMacBook-Pro.local"
        set user_host (set_color green)"$USER@"(hostname)(set_color normal)":"
    end
    
    # Current directory
    set -l cwd (set_color cyan)(prompt_pwd)(set_color normal)
    
    # Git branch
    set -l git_branch ""
    if git rev-parse --git-dir >/dev/null 2>&1
        set -l branch (git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/')
        if test -n "$branch"
            set git_branch " "(set_color red)"($branch)"(set_color normal)
        end
    end
    
    # Build prompt
    echo -n "$user_host$cwd$git_branch"
    echo
    echo -n "$ "
end

# Right prompt (optional)
function fish_right_prompt
    # Empty by default
end
