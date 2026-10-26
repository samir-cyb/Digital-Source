-- Initial relational schema. Review and apply with migration owner.
-- NOT a production-ready RLS migration. Do not run application as schema owner.

CREATE TABLE users (
	id VARCHAR(36) NOT NULL, 
	employee_id VARCHAR(24) NOT NULL, 
	name VARCHAR(120) NOT NULL, 
	email VARCHAR(254) NOT NULL, 
	password_hash TEXT NOT NULL, 
	roles JSON NOT NULL, 
	title VARCHAR(100) NOT NULL, 
	department VARCHAR(80) NOT NULL, 
	avatar VARCHAR(200), 
	phone VARCHAR(40), 
	active BOOLEAN NOT NULL, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	UNIQUE (employee_id), 
	UNIQUE (email)
);

CREATE TABLE suppliers (
	id VARCHAR(36) NOT NULL, 
	name VARCHAR(160) NOT NULL, 
	contact VARCHAR(160), 
	category VARCHAR(80) NOT NULL, 
	PRIMARY KEY (id)
);

CREATE TABLE sessions (
	id VARCHAR(36) NOT NULL, 
	token_hash VARCHAR(64) NOT NULL, 
	user_id VARCHAR(36) NOT NULL, 
	expires_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	revoked_at TIMESTAMP WITHOUT TIME ZONE, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	UNIQUE (token_hash), 
	FOREIGN KEY(user_id) REFERENCES users (id)
);

CREATE INDEX ix_sessions_user_id ON sessions (user_id);

CREATE INDEX ix_sessions_expires_at ON sessions (expires_at);

CREATE TABLE projects (
	id VARCHAR(36) NOT NULL, 
	name VARCHAR(160) NOT NULL, 
	client VARCHAR(120) NOT NULL, 
	site VARCHAR(200) NOT NULL, 
	phase VARCHAR(30) NOT NULL, 
	due_date DATE NOT NULL, 
	created_by VARCHAR(36) NOT NULL, 
	image VARCHAR(200), 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(created_by) REFERENCES users (id)
);

CREATE TABLE reports (
	id VARCHAR(36) NOT NULL, 
	author_id VARCHAR(36) NOT NULL, 
	report_date DATE NOT NULL, 
	completed TEXT NOT NULL, 
	remaining TEXT NOT NULL, 
	help_needed TEXT NOT NULL, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	UNIQUE (author_id, report_date), 
	FOREIGN KEY(author_id) REFERENCES users (id)
);

CREATE INDEX ix_reports_report_date ON reports (report_date);

CREATE TABLE notifications (
	id VARCHAR(36) NOT NULL, 
	user_id VARCHAR(36) NOT NULL, 
	title VARCHAR(160) NOT NULL, 
	body TEXT NOT NULL, 
	route VARCHAR(200) NOT NULL, 
	read_at TIMESTAMP WITHOUT TIME ZONE, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	dedupe_key VARCHAR(160) NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id), 
	UNIQUE (dedupe_key)
);

CREATE INDEX ix_notifications_user_id ON notifications (user_id);

CREATE TABLE audit_events (
	id VARCHAR(36) NOT NULL, 
	actor_id VARCHAR(36), 
	action VARCHAR(80) NOT NULL, 
	entity_type VARCHAR(40) NOT NULL, 
	entity_id VARCHAR(36), 
	details JSON NOT NULL, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(actor_id) REFERENCES users (id)
);

CREATE TABLE project_members (
	project_id VARCHAR(36) NOT NULL, 
	user_id VARCHAR(36) NOT NULL, 
	project_role VARCHAR(20) NOT NULL, 
	PRIMARY KEY (project_id, user_id), 
	FOREIGN KEY(project_id) REFERENCES projects (id), 
	FOREIGN KEY(user_id) REFERENCES users (id)
);

CREATE INDEX ix_project_members_user_id ON project_members (user_id);

CREATE TABLE tasks (
	id VARCHAR(36) NOT NULL, 
	project_id VARCHAR(36) NOT NULL, 
	title VARCHAR(200) NOT NULL, 
	assignee_id VARCHAR(36) NOT NULL, 
	status VARCHAR(20) NOT NULL, 
	due_date DATE NOT NULL, 
	priority VARCHAR(12) NOT NULL, 
	blocker TEXT, 
	review_note TEXT, 
	version INTEGER NOT NULL, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	CHECK (status IN ('todo','in_progress','blocked','review','done','cancelled')), 
	FOREIGN KEY(project_id) REFERENCES projects (id), 
	FOREIGN KEY(assignee_id) REFERENCES users (id)
);

CREATE INDEX ix_tasks_assignee_due ON tasks (assignee_id, due_date);

CREATE INDEX ix_tasks_project_status ON tasks (project_id, status);

CREATE TABLE material_requests (
	id VARCHAR(36) NOT NULL, 
	project_id VARCHAR(36) NOT NULL, 
	supplier_id VARCHAR(36), 
	owner_id VARCHAR(36) NOT NULL, 
	item VARCHAR(200) NOT NULL, 
	unit VARCHAR(20) NOT NULL, 
	quantity NUMERIC(12, 3) NOT NULL, 
	received NUMERIC(12, 3) NOT NULL, 
	due_date DATE NOT NULL, 
	status VARCHAR(20) NOT NULL, 
	PRIMARY KEY (id), 
	CHECK (quantity > 0 AND received >= 0 AND received <= quantity), 
	FOREIGN KEY(project_id) REFERENCES projects (id), 
	FOREIGN KEY(supplier_id) REFERENCES suppliers (id), 
	FOREIGN KEY(owner_id) REFERENCES users (id)
);

CREATE INDEX ix_material_requests_due_date ON material_requests (due_date);

CREATE INDEX ix_material_requests_project_id ON material_requests (project_id);

CREATE INDEX ix_material_requests_supplier_id ON material_requests (supplier_id);

CREATE TABLE money_entries (
	id VARCHAR(36) NOT NULL, 
	project_id VARCHAR(36) NOT NULL, 
	created_by VARCHAR(36) NOT NULL, 
	kind VARCHAR(20) NOT NULL, 
	amount NUMERIC(14, 2) NOT NULL, 
	payer VARCHAR(160) NOT NULL, 
	payee VARCHAR(160) NOT NULL, 
	purpose TEXT NOT NULL, 
	entry_date DATE NOT NULL, 
	method VARCHAR(20) NOT NULL, 
	status VARCHAR(20) NOT NULL, 
	approved_by VARCHAR(36), 
	reversal_of VARCHAR(36), 
	idempotency_key VARCHAR(80) NOT NULL, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	CHECK (amount > 0), 
	FOREIGN KEY(project_id) REFERENCES projects (id), 
	FOREIGN KEY(created_by) REFERENCES users (id), 
	FOREIGN KEY(approved_by) REFERENCES users (id), 
	UNIQUE (reversal_of), 
	FOREIGN KEY(reversal_of) REFERENCES money_entries (id), 
	UNIQUE (idempotency_key)
);

CREATE INDEX ix_money_entries_created_by ON money_entries (created_by);

CREATE INDEX ix_money_project_date ON money_entries (project_id, entry_date);

CREATE TABLE daily_plans (
	id VARCHAR(36) NOT NULL, 
	project_id VARCHAR(36) NOT NULL, 
	plan_date DATE NOT NULL, 
	revision INTEGER NOT NULL, 
	status VARCHAR(20) NOT NULL, 
	published_by VARCHAR(36) NOT NULL, 
	published_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	UNIQUE (project_id, plan_date, revision), 
	FOREIGN KEY(project_id) REFERENCES projects (id), 
	FOREIGN KEY(published_by) REFERENCES users (id)
);

CREATE INDEX ix_daily_plans_plan_date ON daily_plans (plan_date);

CREATE INDEX ix_daily_plans_project_id ON daily_plans (project_id);

CREATE TABLE task_dependencies (
	task_id VARCHAR(36) NOT NULL, 
	prerequisite_id VARCHAR(36) NOT NULL, 
	PRIMARY KEY (task_id, prerequisite_id), 
	FOREIGN KEY(task_id) REFERENCES tasks (id), 
	FOREIGN KEY(prerequisite_id) REFERENCES tasks (id)
);

CREATE INDEX ix_task_dependencies_prerequisite_id ON task_dependencies (prerequisite_id);

CREATE TABLE deliveries (
	id VARCHAR(36) NOT NULL, 
	request_id VARCHAR(36) NOT NULL, 
	quantity NUMERIC(12, 3) NOT NULL, 
	created_by VARCHAR(36) NOT NULL, 
	note TEXT, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(request_id) REFERENCES material_requests (id), 
	FOREIGN KEY(created_by) REFERENCES users (id)
);

CREATE INDEX ix_deliveries_request_id ON deliveries (request_id);

CREATE TABLE plan_tasks (
	plan_id VARCHAR(36) NOT NULL, 
	task_id VARCHAR(36) NOT NULL, 
	PRIMARY KEY (plan_id, task_id), 
	FOREIGN KEY(plan_id) REFERENCES daily_plans (id), 
	FOREIGN KEY(task_id) REFERENCES tasks (id)
);

CREATE TABLE plan_acknowledgments (
	plan_id VARCHAR(36) NOT NULL, 
	user_id VARCHAR(36) NOT NULL, 
	acknowledged_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (plan_id, user_id), 
	FOREIGN KEY(plan_id) REFERENCES daily_plans (id), 
	FOREIGN KEY(user_id) REFERENCES users (id)
);