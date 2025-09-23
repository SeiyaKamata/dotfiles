# Functions

# Git commit function
function gc
    git commit -m "$argv"
end

# Create directory and cd into it function
function cdb
    mkdir -p $argv[1]; and cd $argv[1]
end

# Add newline before prompt (fish handles this differently)
function fish_greeting
    # Custom greeting or empty to disable default greeting
end
