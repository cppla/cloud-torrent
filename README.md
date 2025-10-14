# 如何运行
docker run --restart=always -d --name=downloads -p 3000:3000 -v /data/downloads:/downloads cppla/cloud-torrent --auth user:password

# 如何跨平台编译
docker buildx build --platform linux/arm,linux/amd64,linux/arm64 -t cppla/cloud-torrent . --push

