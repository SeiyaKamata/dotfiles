# Docker Aliases
# prefix: d

alias de="docker exec"
alias dei="docker exec -it"

alias dr="docker restart"

alias dcl="docker container ls --format 'table {{.Names}}\t{{.ID}}\t{{.Image}}\t{{.Status}}'"

alias dl="docker logs --tails=1000"