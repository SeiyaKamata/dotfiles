# Docker Aliases
# prefix: d

select_container() {
  docker ps --format "{{.Names}}" | fzf
}

dex() {
  local container
  container=$(select_container)
  [ -n "$container" ] && docker exec -it "$container" ${1:-bash}
}


alias d="docker"
alias dps="docker container ls --format 'table {{.Names}}\t{{.Status}}'"

# ====================================================

select_project_container() {
  docker compose ps --format "{{.Names}}" 2>/dev/null | fzf
}

dcex() {
  local container
  container=$(select_project_container)
  [ -n "$container" ] && docker exec -it "$container" ${1:-bash}
}

dcre() {
  local container
  container=$(select_project_container)
  [ -n "$container" ] && docker restart "$container"
}


alias dc="docker compose"

alias dcps="docker compose ps --format 'table {{.Names}}\t{{.Status}}' 2>/dev/null"
alias dclf="docker compose logs -f --tail=50"

alias dcu="docker compose up -d"
alias dcs="docker compose stop"
alias dcd="docker compose down"
alias dcx="docker compose down -v --rmi all --remove-orphans"

alias dcb="docker compose build"
alias dcbn="docker compose build --no-cache"
