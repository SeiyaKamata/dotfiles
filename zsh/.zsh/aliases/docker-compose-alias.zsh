# Docker Compose Aliases
# prefix: dc

alias dc="docker compose"

alias dcu="docker compose up -d"

alias dcl="docker compose logs -f --tail=50"

alias dcs="docker compose stop"

alias dcd="docker compose down"
alias dcx="docker compose down -v --rmi all --remove-orphans"

alias dcb="docker compose build"
alias dcnc="docker compose build --no-cache"
