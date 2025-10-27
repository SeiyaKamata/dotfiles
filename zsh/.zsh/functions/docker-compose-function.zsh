

# イメージ選択して削除
drm_fzf() {
  image=$(docker images --format '{{.Repository}}:{{.Tag}}' | fzf)
  docker rmi $image
}