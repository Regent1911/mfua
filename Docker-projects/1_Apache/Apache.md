
# Апач на докере

## Проверка Docker

```bash
docker version
```

![alt text](image.png)

## Проверка и удаление ранее установленных контейнеров

~~docker stop $(docker ps -q)~~

```bash
docker ps -a
docker stop $(docker ps -aq)
docker container prune
```

![alt text](image-1.png)

## Находим образ и запускаем

```bash
docker run -d --name my-apache -p 8081:80 httpd
```

![alt text](image-2.png)

## Проверяем

```bash
docker stats
```

![alt text](image-3.png)

## И снова проверяем

```bash
docker inspect my-apache
```

![alt text](image-4.png)

## В браузере работает

![alt text](image-5.png)

## Логи

```bash
docker logs my-apache
```

![alt text](image-6.png)
