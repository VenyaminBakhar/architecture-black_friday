#!/bin/bash
set -e

docker compose exec -T configSrv-1 mongosh --port 27017 --quiet <<EOF
rs.initiate(
  {
    _id : "config_server",
    configsvr: true,
    members: [
      { _id : 0, host : "configSrv-1:27017" },
      { _id : 1, host : "configSrv-2:27027" },
      { _id : 2, host : "configSrv-3:27037" }
    ]
  }
);
EOF

docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
rs.initiate(
  {
    _id : "shard1",
    members: [
      { _id : 0, host : "shard1-1:27018" },
      { _id : 1, host : "shard1-2:27019" },
      { _id : 2, host : "shard1-3:27020" }
    ]
  }
);
EOF

docker compose exec -T shard2-1 mongosh --port 27021 --quiet <<EOF
rs.initiate(
  {
    _id : "shard2",
    members: [
      { _id : 0, host : "shard2-1:27021" },
      { _id : 1, host : "shard2-2:27022" },
      { _id : 2, host : "shard2-3:27023" }
    ]
  }
);
EOF

echo "Ожидание готовности mongos_router-1..."
until docker compose exec -T mongos_router-1 mongosh --port 27030 --quiet --eval "db.adminCommand('ping')" > /dev/null 2>&1; do
  sleep 2
  echo "  mongos_router-1 ещё не готов, ждём..."
done
echo "mongos_router-1 готов!"

docker compose exec -T mongos_router-1 mongosh --port 27030 --quiet <<EOF
sh.addShard("shard1/shard1-1:27018,shard1-2:27019,shard1-3:27020");
sh.addShard("shard2/shard2-1:27021,shard2-2:27022,shard2-3:27023");

sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } )

use somedb

for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i})

db.helloDoc.countDocuments()
EOF