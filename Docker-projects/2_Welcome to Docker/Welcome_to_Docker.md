
# Welcome to Docker

## Попробуем

Выполняем команду:

```bash
docker run -d -p 8088:80 --name welcome-to-docker docker/welcome-to-docker
```

![alt text](image.png)
Открываем в браузере:
<http://localhost:8088>
![alt text](image-1.png)

## Сборка

Сборка и запуск:

```bash
docker build -t welcome-to-docker .
docker run -d -p 8088:3000 --name welcome-to-docker welcome-to-docker
```

![alt text](image-2.png)
Откройте в браузере:
<http://localhost:8088>
