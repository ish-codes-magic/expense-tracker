-- One row per AI read: what it cost and how long it took. Never the
-- receipt's contents.
CREATE TABLE reads (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  at                TEXT    NOT NULL,   -- ISO time, UTC
  device            TEXT    NOT NULL,   -- the install's random id
  status            INTEGER NOT NULL,   -- HTTP status from OpenRouter
  model             TEXT,
  ms                INTEGER,
  prompt_tokens     INTEGER,
  completion_tokens INTEGER,
  cost_usd          REAL
);
CREATE INDEX reads_by_time ON reads (at);
CREATE INDEX reads_by_device ON reads (device, at);
