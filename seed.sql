-- Seed data for Meeting Momentum

-- Users: 1 owner, 3 members
INSERT INTO users (id, name, email, user_type) VALUES
  ('00000000-0000-0000-0000-000000000001', 'Olivia Owner',  'olivia.owner@example.com',  'owner'),
  ('00000000-0000-0000-0000-000000000002', 'Marcus Member', 'marcus.member@example.com', 'member'),
  ('00000000-0000-0000-0000-000000000003', 'Priya Member',  'priya.member@example.com',  'member'),
  ('00000000-0000-0000-0000-000000000004', 'Diego Member',  'diego.member@example.com',  'member')
ON CONFLICT (id) DO NOTHING;

-- Meetings: 2 completed (with notes), 1 upcoming
INSERT INTO meetings (id, title, meeting_date, owner_id, agenda, notes, status) VALUES
  ('10000000-0000-0000-0000-000000000001',
   'Sprint Planning',
   now() - interval '7 days',
   '00000000-0000-0000-0000-000000000001',
   'Review backlog. Pick sprint goals. Assign owners.',
   'We reviewed the backlog and agreed the login page is the top priority. Marcus will build the login page by Friday. Priya will set up the database schema. We decided to use Amazon RDS because our data has clear relationships. Diego will write the deployment pipeline next week.',
   'completed'),
  ('10000000-0000-0000-0000-000000000002',
   'Design Review',
   now() - interval '3 days',
   '00000000-0000-0000-0000-000000000001',
   'Review meeting list and action item screens.',
   'The team reviewed the mockups for the meeting list and action item screens. We decided to show overdue items in red at the top of the list. Priya will fix the spacing issues on the action item page.',
   'completed'),
  ('10000000-0000-0000-0000-000000000003',
   'Cloud Architecture Sync',
   now() + interval '2 days',
   '00000000-0000-0000-0000-000000000001',
   'Walk through the API Gateway and Lambda layout. Confirm reminder schedule.',
   NULL,
   'scheduled')
ON CONFLICT (id) DO NOTHING;

-- Participants: everyone attends every meeting
INSERT INTO meeting_participants (meeting_id, user_id)
SELECT m.id, u.id
FROM meetings m
CROSS JOIN users u
WHERE m.id IN ('10000000-0000-0000-0000-000000000001',
               '10000000-0000-0000-0000-000000000002',
               '10000000-0000-0000-0000-000000000003')
ON CONFLICT DO NOTHING;

-- Decisions: 4
INSERT INTO decisions (id, meeting_id, description, author_id) VALUES
  ('20000000-0000-0000-0000-000000000001',
   '10000000-0000-0000-0000-000000000001',
   'The login page is the top priority for this sprint.',
   '00000000-0000-0000-0000-000000000001'),
  ('20000000-0000-0000-0000-000000000002',
   '10000000-0000-0000-0000-000000000001',
   'Use Amazon RDS for the database because the data is relational.',
   '00000000-0000-0000-0000-000000000001'),
  ('20000000-0000-0000-0000-000000000003',
   '10000000-0000-0000-0000-000000000002',
   'Show overdue action items in red at the top of the list.',
   '00000000-0000-0000-0000-000000000001'),
  ('20000000-0000-0000-0000-000000000004',
   '10000000-0000-0000-0000-000000000002',
   'Send reminders one day before an action item is due.',
   '00000000-0000-0000-0000-000000000001')
ON CONFLICT (id) DO NOTHING;

-- Action items: 6, covering every status
--   completed      : build login page
--   in_progress    : database schema
--   open, overdue  : deployment pipeline (due 3 days ago)
--   open, due soon : fix spacing (due tomorrow, gets a reminder)
--   open, later    : write API docs
--   open, later    : prepare architecture diagram
INSERT INTO action_items (id, meeting_id, description, owner_id, due_date, status, completed_at) VALUES
  ('30000000-0000-0000-0000-000000000001',
   '10000000-0000-0000-0000-000000000001',
   'Build the login page',
   '00000000-0000-0000-0000-000000000002',
   current_date - 4, 'completed', now() - interval '5 days'),
  ('30000000-0000-0000-0000-000000000002',
   '10000000-0000-0000-0000-000000000001',
   'Set up the database schema',
   '00000000-0000-0000-0000-000000000003',
   current_date + 3, 'in_progress', NULL),
  ('30000000-0000-0000-0000-000000000003',
   '10000000-0000-0000-0000-000000000001',
   'Write the deployment pipeline',
   '00000000-0000-0000-0000-000000000004',
   current_date - 3, 'open', NULL),
  ('30000000-0000-0000-0000-000000000004',
   '10000000-0000-0000-0000-000000000002',
   'Fix spacing issues on the action item page',
   '00000000-0000-0000-0000-000000000003',
   current_date + 1, 'open', NULL),
  ('30000000-0000-0000-0000-000000000005',
   '10000000-0000-0000-0000-000000000002',
   'Write API documentation for the action item endpoints',
   '00000000-0000-0000-0000-000000000002',
   current_date + 7, 'open', NULL),
  ('30000000-0000-0000-0000-000000000006',
   '10000000-0000-0000-0000-000000000003',
   'Prepare the architecture diagram for the sync',
   '00000000-0000-0000-0000-000000000004',
   current_date + 2, 'open', NULL)
ON CONFLICT (id) DO NOTHING;

-- Uploaded file: synthetic recording for Transcribe.
-- Upload the matching audio file to S3 at this key in the Setup workflow:
--   seed/sprint-planning.mp3
INSERT INTO uploaded_files (id, meeting_id, s3_key) VALUES
  ('40000000-0000-0000-0000-000000000001',
   '10000000-0000-0000-0000-000000000001',
   'seed/sprint-planning.mp3')
ON CONFLICT (id) DO NOTHING;

-- AI results
-- 1) Transcribe: finished and accepted. Its text is the notes of Sprint Planning.
-- 2) Bedrock: draft summary and proposed action items, still unreviewed.
--    The owner confirms each item before it becomes a real action item.
INSERT INTO ai_results
  (id, meeting_id, file_id, service, result, corrected_result, confidence, processing_status, review_status)
VALUES
  ('50000000-0000-0000-0000-000000000001',
   '10000000-0000-0000-0000-000000000001',
   '40000000-0000-0000-0000-000000000001',
   'transcribe',
   '{"transcript": "We reviewed the backlog and agreed the login page is the top priority. Marcus will build the login page by Friday. Priya will set up the database schema. We decided to use Amazon RDS because our data has clear relationships. Diego will write the deployment pipeline next week.",
     "segments": [
       {"start_time": "0.0",  "end_time": "7.4",  "text": "We reviewed the backlog and agreed the login page is the top priority."},
       {"start_time": "7.4",  "end_time": "12.1", "text": "Marcus will build the login page by Friday."},
       {"start_time": "12.1", "end_time": "15.8", "text": "Priya will set up the database schema."},
       {"start_time": "15.8", "end_time": "22.0", "text": "We decided to use Amazon RDS because our data has clear relationships."},
       {"start_time": "22.0", "end_time": "26.5", "text": "Diego will write the deployment pipeline next week."}
     ]}'::jsonb,
   NULL,
   0.940,
   'succeeded',
   'accepted'),
  ('50000000-0000-0000-0000-000000000002',
   '10000000-0000-0000-0000-000000000002',
   NULL,
   'bedrock',
   '{"summary": "The team reviewed mockups for the meeting list and action item screens. They decided to show overdue items in red at the top of the list.",
     "proposed_action_items": [
       {"description": "Fix spacing issues on the action item page", "suggested_owner_email": "priya.member@example.com", "suggested_due_days": 1}
     ]}'::jsonb,
   NULL,
   NULL,
   'succeeded',
   'unreviewed')
ON CONFLICT (id) DO NOTHING;