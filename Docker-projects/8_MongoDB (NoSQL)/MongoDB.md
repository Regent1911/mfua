# MongoDB в Docker

## О проекте

**MongoDB** — ведущая NoSQL база данных с документо-ориентированной моделью. Хранит данные в гибком JSON-подобном формате BSON.

## Установка MongoDB

```bash
docker run -d \
  --name mongodb \
  -p 27017:27017 \
  -e MONGO_INITDB_ROOT_USERNAME=admin \
  -e MONGO_INITDB_ROOT_PASSWORD=secret \
  -e MONGO_INITDB_DATABASE=mydb \
  -v mongodb_data:/data/db \
  --restart unless-stopped \
  mongo:7
```

![alt text](image.png)

### Что означают аргументы

| Аргумент | Описание |
| `-p 27017:27017` | Стандартный порт MongoDB |
| `-e MONGO_INITDB_ROOT_USERNAME` | Имя администратора |
| `-e MONGO_INITDB_ROOT_PASSWORD` | Пароль администратора |
| `-e MONGO_INITDB_DATABASE` | База для создания при первом запуске |
| `-v mongodb_data:/data/db` | Том для данных |

## Подключение

```bash
# Через контейнер
docker exec -it mongodb mongosh -u admin -p secret
![alt text](image-1.png)
# С локального клиента
mongosh mongodb://admin:secret@localhost:27017
```

## Основные команды mongosh

```javascript
// Показать базы данных
show dbs

// Переключиться на БД
use mydb

// Показать коллекции
show collections

// Вставить документ
db.users.insertOne({ name: "John", age: 30 })

// Найти документы
db.users.find()

// Выйти
exit
```

![alt text](image-2.png)

## Полезные команды

```bash
# Резервное копирование
docker exec mongodb mongodump -u admin -p secret --out /tmp/backup
![alt text](image-3.png)
# Восстановление
docker exec mongodb mongorestore -u admin -p secret /tmp/backup
![alt text](image-4.png)
# Копирование бэкапа на хост
docker cp mongodb:/tmp/backup ./backup
```

![alt text](image-5.png)

## Для разработки (без аутентификации)

```bash
docker run -d --name mongodb-dev -p 27017:27017 mongo:7
```

## Mongo Express (веб-интерфейс)

```bash
docker run -d \
  --name mongo-express \
  -p 8081:8081 \
  -e ME_CONFIG_MONGODB_ADMINUSERNAME=admin \
  -e ME_CONFIG_MONGODB_ADMINPASSWORD=secret \
  -e ME_CONFIG_MONGODB_URL=mongodb://admin:secret@mongodb:27017 \
  --link mongodb \
  mongo-express
```

Доступ: <http://localhost:8081>
