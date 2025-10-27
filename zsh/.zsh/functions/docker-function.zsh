
# 全コンテナ停止・削除
docker_clean() {
  docker stop $(docker ps -aq)
  docker rm $(docker ps -aq)
}

# 使わないイメージもまとめて削除
docker_clean_images() {
  docker rmi $(docker images -q)
}

docker_exec_fzf() {
  container=$(docker ps --format '{{.Names}}' | fzf)
  docker exec -it $container /bin/bash
}

docker_remove_image_fzf() {
  image=$(docker images --format '{{.Repository}}:{{.Tag}}' | fzf)
  docker rmi $image
}