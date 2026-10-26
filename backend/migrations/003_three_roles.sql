-- SQLite reference migration for the three-actor role contract.
-- The application applies the equivalent guarded migration from app/migrations.py.
BEGIN;
UPDATE users SET roles=CASE
  WHEN EXISTS(SELECT 1 FROM json_each(users.roles) WHERE value IN ('owner','manager')) THEN '["manager"]'
  WHEN EXISTS(SELECT 1 FROM json_each(users.roles) WHERE value='finance') THEN '["finance"]'
  ELSE '["member"]' END;
UPDATE project_members SET project_role=CASE
  WHEN user_id IN (SELECT id FROM users WHERE json_extract(roles,'$[0]')='manager') THEN 'manager'
  WHEN user_id IN (SELECT id FROM users WHERE json_extract(roles,'$[0]')='member') AND project_role='lead' THEN 'lead'
  ELSE 'member' END;
WITH ranked AS (
  SELECT project_id,user_id,ROW_NUMBER() OVER(PARTITION BY project_id ORDER BY user_id) AS rank
  FROM project_members WHERE project_role='lead'
)
UPDATE project_members SET project_role='member'
WHERE (project_id,user_id) IN (SELECT project_id,user_id FROM ranked WHERE rank>1);
CREATE UNIQUE INDEX IF NOT EXISTS uq_project_single_lead ON project_members(project_id) WHERE project_role='lead';
CREATE TABLE IF NOT EXISTS schema_migrations(revision VARCHAR(80) PRIMARY KEY,applied_at TIMESTAMP NOT NULL);
INSERT OR IGNORE INTO schema_migrations(revision,applied_at) VALUES('three_roles_v1',CURRENT_TIMESTAMP);
COMMIT;

