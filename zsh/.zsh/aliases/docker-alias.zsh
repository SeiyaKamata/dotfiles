# Docker Aliases
# prefix: d

alias doe="docker exec"
alias dor="docker restart"

alias docl="docker container ls"
alias doclf="docker container ls --format 'table {{.Names}}\t{{.ID}}\t{{.Image}}\t{{.Status}}'"