-- Local SQLite migration; additive, preserves existing users and projects.
CREATE TABLE IF NOT EXISTS workspace_registration (
    claim_key VARCHAR(40) NOT NULL PRIMARY KEY,
    owner_user_id VARCHAR(36) NOT NULL REFERENCES users(id),
    created_at TIMESTAMP NOT NULL
);
