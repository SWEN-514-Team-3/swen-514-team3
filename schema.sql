CREATE TABLE IF NOT EXISTS users (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cognito_sub TEXT UNIQUE,
    name        TEXT NOT NULL,
    email       TEXT NOT NULL UNIQUE,
    user_type   TEXT NOT NULL DEFAULT 'member'
                CHECK (user_type IN ('owner', 'member'))
);

CREATE TABLE IF NOT EXISTS meetings (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title         TEXT NOT NULL,
    meeting_date  TIMESTAMPTZ NOT NULL,
    owner_id      UUID NOT NULL REFERENCES users(id),
    agenda        TEXT,
    notes         TEXT,
    status        TEXT NOT NULL DEFAULT 'scheduled'
                  CHECK (status IN ('scheduled', 'in_progress', 'completed', 'cancelled')),
    search_vector TSVECTOR GENERATED ALWAYS AS (
        to_tsvector('english',
            coalesce(title, '') || ' ' || coalesce(agenda, '') || ' ' || coalesce(notes, ''))
    ) STORED
);

CREATE TABLE IF NOT EXISTS meeting_participants (
    meeting_id UUID NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
    user_id    UUID NOT NULL REFERENCES users(id)    ON DELETE CASCADE,
    PRIMARY KEY (meeting_id, user_id)
);

CREATE TABLE IF NOT EXISTS decisions (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    meeting_id    UUID NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
    description   TEXT NOT NULL,
    author_id     UUID NOT NULL REFERENCES users(id),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    search_vector TSVECTOR GENERATED ALWAYS AS (to_tsvector('english', description)) STORED
);

-- Overdue: not finished, and the due date has passed
-- Reminders: a job runs daily and finds unfinished items that are due tomorrow
CREATE TABLE IF NOT EXISTS action_items (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    meeting_id    UUID NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
    description   TEXT NOT NULL,
    owner_id      UUID NOT NULL REFERENCES users(id),
    due_date      DATE NOT NULL,
    status        TEXT NOT NULL DEFAULT 'open'
                  CHECK (status IN ('open', 'in_progress', 'completed')),
    completed_at  TIMESTAMPTZ,
    search_vector TSVECTOR GENERATED ALWAYS AS (to_tsvector('english', description)) STORED
);

-- Recordings are uploaded
CREATE TABLE IF NOT EXISTS uploaded_files (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    meeting_id UUID NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
    s3_key     TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS ai_results (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    meeting_id        UUID NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
    file_id           UUID REFERENCES uploaded_files(id) ON DELETE SET NULL,
    service           TEXT NOT NULL CHECK (service IN ('transcribe', 'bedrock')),
    result            JSONB,
    corrected_result  JSONB,
    confidence        NUMERIC(4,3),
    processing_status TEXT NOT NULL DEFAULT 'pending'
                      CHECK (processing_status IN ('pending', 'processing', 'succeeded', 'failed')),
    review_status     TEXT NOT NULL DEFAULT 'unreviewed'
                      CHECK (review_status IN ('unreviewed', 'accepted', 'corrected', 'rejected'))
);