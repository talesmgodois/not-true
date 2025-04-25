# Manage database types and schemas

## We use dbml to design database and generate it first attemp

```shell

# If not installed, install dbml cli: 
npm install -g @dbml/cli

dbml2sql ./db_schemas/schema.dbml --postgres > ./db_schemas/schema.sql
```


## We use xo to generate crud operations
```shell
xo -s postgres://postgres:postgres@localhost:5432/api?sslmode=disable -o ./not-true-core/pkg/db/xo

```

## Sqlc for custom queries

```shell
cd db
sqlc -f . db/sqlc.yaml generate

```