for config_file in $HOME/.zsh/aliases/*.zsh; do
  source $config_file
done

# cx
alias rspec="docker exec -it sec_web bundle exec rspec"
alias rubocop="docker exec -it sec_web bundle exec rubocop"

# ev2
alias ev2_api="docker exec -it ev2_api"
