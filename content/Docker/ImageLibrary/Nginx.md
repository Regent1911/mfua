## Веб-сервер Nginx

Скачать и запустить Nginx
```shell
docker run -d --name my-nginx -p 80:80 nginx:alpine
```

Проверить работоспособность контейнера командой:
```shell
curl http://localhost
```

[Или запустить в браузере: http://localhost](http://localhost)

Чтобы создать и запустить ещё один контейнер, надо указать другое имя и порт, например:
```shell
docker run -d --name nginx-copy -p 81:80 nginx:alpine
```

[Или запустить в браузере: http://localhost:81](http://localhost:81)

### Полезные команды для работы

#### Посмотреть запущенные контейнеры
```shell
docker ps
```

#### Остановить контейнер
```shell
docker stop my-nginx
```

#### Запустить остановленный
```shell
docker start my-nginx
```

#### Перезапустить контейнер
```shell
docker restart my-nginx
```

#### Посмотреть логи
```shell
docker logs my-nginx
```
```shell
docker logs -f my-nginx  # в реальном времени
```

> Чтобы выйти из режима просмотра логов, нужно выполнить `Ctrl+C`

#### Войти в контейнер
```shell
docker exec -it my-nginx /bin/sh
```

#### Получить ин-фу по ОС контейнера
```shell
cat /etc/os-release
```

```shell
top
```

> Чтобы выйти из top, нужно выполнить `Q`

> т.е. это скорей всео какой-то Linux, то можно попробовать повыполнять разные команды из Linux

Установить fastfetch (например)
```shell
apt install fastfetch
```
после установки выполнить команду:
```shell
fastfetch
```

> Таким образом вы получаете в контейнере маленькую копию Linux, с которым можно работать.

Чтобы выйти из контейнера, следует выполнить:
```shell
exit
```

#### Скопировать файл из контейнера
```shell
docker cp my-nginx:/etc/nginx/nginx.conf ./nginx.conf
```

#### Мониторинг контейнеров
```shell
docker stats
```

> Вывод ин-фы мониторинга обновляется каждые 2 сек.!

Выйти из мониторинга по `Ctrl+C`

#### Мониторинг без постоянного обновления (однократный вывод)
```shell
docker stats --no-stream
```
```shell
docker stats $(docker ps -q)
```

#### Удалить контейнер
```shell
docker rm my-nginx
```

#### Удалить контейнер и его volume (если есть)
```shell
docker rm -v my-nginx
```