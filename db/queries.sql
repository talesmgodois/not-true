-- name: GetArticlesById :one
SELECT * FROM articles
WHERE id = $1 LIMIT 1;