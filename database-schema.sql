-- ============================================================
-- RealEstate-CRM: Full Database Schema
-- Designed for a detail-oriented, structured solo agent
-- ============================================================

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- 1. CONTACTS (Master table — everyone lives here)
-- ============================================================
CREATE TABLE contacts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  phone_secondary TEXT,
  address_street TEXT,
  address_city TEXT,
  address_state TEXT,
  address_zip TEXT,
  contact_type TEXT NOT NULL DEFAULT 'lead' CHECK (contact_type IN ('lead', 'client', 'past_client', 'vendor', 'referral_partner', 'sphere')),
  source TEXT CHECK (source IN ('website', 'referral', 'zillow', 'realtor_com', 'social_media', 'open_house', 'cold_call', 'sign_call', 'repeat', 'other')),
  source_detail TEXT,
  avatar_url TEXT,
  company TEXT,
  title TEXT,
  birthday DATE,
  anniversary DATE,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 2. PIPELINE STAGES (Customizable lead pipeline)
-- ============================================================
CREATE TABLE pipeline_stages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  display_order INT NOT NULL,
  color TEXT DEFAULT '#6366f1',
  is_default BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed default pipeline stages
INSERT INTO pipeline_stages (name, display_order, color, is_default) VALUES
  ('New Lead', 1, '#8b5cf6', true),
  ('Contacted', 2, '#6366f1', false),
  ('Qualified', 3, '#3b82f6', false),
  ('Showing', 4, '#0ea5e9', false),
  ('Under Contract', 5, '#14b8a6', false),
  ('Closed Won', 6, '#22c55e', false),
  ('Closed Lost', 7, '#ef4444', false),
  ('Nurture', 8, '#f59e0b', false);

-- ============================================================
-- 3. LEADS (Lead-specific tracking linked to contacts)
-- ============================================================
CREATE TABLE leads (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  contact_id UUID NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  stage_id UUID REFERENCES pipeline_stages(id),
  lead_type TEXT CHECK (lead_type IN ('buyer', 'seller', 'both', 'investor', 'renter')),
  temperature TEXT DEFAULT 'warm' CHECK (temperature IN ('hot', 'warm', 'cold')),
  score INT DEFAULT 0 CHECK (score >= 0 AND score <= 100),
  budget_min NUMERIC(12,2),
  budget_max NUMERIC(12,2),
  desired_area TEXT,
  desired_beds INT,
  desired_baths NUMERIC(3,1),
  property_type TEXT CHECK (property_type IN ('single_family', 'condo', 'townhouse', 'multi_family', 'land', 'commercial', 'other')),
  timeframe TEXT CHECK (timeframe IN ('immediate', '1_3_months', '3_6_months', '6_12_months', '12_plus_months', 'unknown')),
  pre_approved BOOLEAN DEFAULT false,
  lender_name TEXT,
  lender_contact TEXT,
  assigned_at TIMESTAMPTZ DEFAULT NOW(),
  last_contacted_at TIMESTAMPTZ,
  next_follow_up DATE,
  lost_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 4. PROPERTIES (Listings and properties of interest)
-- ============================================================
CREATE TABLE properties (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  mls_number TEXT,
  address_street TEXT NOT NULL,
  address_city TEXT,
  address_state TEXT,
  address_zip TEXT,
  property_type TEXT CHECK (property_type IN ('single_family', 'condo', 'townhouse', 'multi_family', 'land', 'commercial', 'other')),
  beds INT,
  baths NUMERIC(3,1),
  sqft INT,
  lot_size TEXT,
  year_built INT,
  list_price NUMERIC(12,2),
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'pending', 'sold', 'withdrawn', 'expired', 'off_market')),
  description TEXT,
  photos JSONB DEFAULT '[]'::jsonb,
  features JSONB DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 5. TRANSACTIONS (Active and closed deals)
-- ============================================================
CREATE TABLE transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  contact_id UUID NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  property_id UUID REFERENCES properties(id),
  transaction_type TEXT NOT NULL CHECK (transaction_type IN ('listing', 'buyer', 'dual', 'referral', 'lease')),
  status TEXT DEFAULT 'active' CHECK (status IN ('pre_listing', 'active', 'under_contract', 'pending', 'closed', 'cancelled', 'expired')),
  contract_price NUMERIC(12,2),
  list_price NUMERIC(12,2),
  commission_rate NUMERIC(5,4),
  commission_amount NUMERIC(12,2),
  contract_date DATE,
  closing_date DATE,
  inspection_date DATE,
  appraisal_date DATE,
  financing_contingency_date DATE,
  earnest_money NUMERIC(12,2),
  earnest_money_received BOOLEAN DEFAULT false,
  title_company TEXT,
  title_contact TEXT,
  escrow_number TEXT,
  lender_name TEXT,
  lender_contact TEXT,
  co_agent_name TEXT,
  co_agent_brokerage TEXT,
  co_agent_phone TEXT,
  co_agent_email TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 6. TRANSACTION TASKS (Checklist items per transaction)
-- ============================================================
CREATE TABLE transaction_tasks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  transaction_id UUID NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  due_date DATE,
  is_completed BOOLEAN DEFAULT false,
  completed_at TIMESTAMPTZ,
  display_order INT DEFAULT 0,
  category TEXT CHECK (category IN ('pre_listing', 'active', 'under_contract', 'closing', 'post_closing', 'general')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 7. TRANSACTION DOCUMENTS (Document tracking)
-- ============================================================
CREATE TABLE transaction_documents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  transaction_id UUID NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  document_type TEXT CHECK (document_type IN ('contract', 'addendum', 'disclosure', 'inspection', 'appraisal', 'title', 'insurance', 'lender', 'other')),
  file_url TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'received', 'reviewed', 'signed', 'sent')),
  due_date DATE,
  received_at TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 8. COMMUNICATIONS (Unified log — email, SMS, calls)
-- ============================================================
CREATE TABLE communications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  contact_id UUID NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  transaction_id UUID REFERENCES transactions(id) ON DELETE SET NULL,
  channel TEXT NOT NULL CHECK (channel IN ('email', 'sms', 'call', 'in_person', 'other')),
  direction TEXT NOT NULL CHECK (direction IN ('inbound', 'outbound')),
  subject TEXT,
  body TEXT,
  call_duration_seconds INT,
  call_outcome TEXT CHECK (call_outcome IN ('connected', 'voicemail', 'no_answer', 'busy', 'wrong_number')),
  email_status TEXT CHECK (email_status IN ('draft', 'sent', 'delivered', 'opened', 'bounced', 'failed')),
  sms_status TEXT CHECK (sms_status IN ('sent', 'delivered', 'failed')),
  scheduled_at TIMESTAMPTZ,
  sent_at TIMESTAMPTZ DEFAULT NOW(),
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 9. TASKS (Follow-ups, reminders, to-dos)
-- ============================================================
CREATE TABLE tasks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  contact_id UUID REFERENCES contacts(id) ON DELETE CASCADE,
  transaction_id UUID REFERENCES transactions(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  description TEXT,
  task_type TEXT DEFAULT 'follow_up' CHECK (task_type IN ('follow_up', 'call', 'email', 'showing', 'meeting', 'deadline', 'reminder', 'other')),
  priority TEXT DEFAULT 'medium' CHECK (priority IN ('urgent', 'high', 'medium', 'low')),
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed', 'cancelled', 'deferred')),
  due_date DATE,
  due_time TIME,
  completed_at TIMESTAMPTZ,
  is_recurring BOOLEAN DEFAULT false,
  recurrence_rule TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 10. NOTES (Freeform notes on any entity)
-- ============================================================
CREATE TABLE notes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  contact_id UUID REFERENCES contacts(id) ON DELETE CASCADE,
  transaction_id UUID REFERENCES transactions(id) ON DELETE CASCADE,
  lead_id UUID REFERENCES leads(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  is_pinned BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 11. TAGS (Flexible tagging system)
-- ============================================================
CREATE TABLE tags (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  color TEXT DEFAULT '#6366f1',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE contact_tags (
  contact_id UUID NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  tag_id UUID NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  PRIMARY KEY (contact_id, tag_id)
);

-- ============================================================
-- 12. IMPORTANT DATES (Birthday/anniversary tracking)
-- ============================================================
CREATE TABLE important_dates (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  contact_id UUID NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  date_type TEXT NOT NULL CHECK (date_type IN ('birthday', 'anniversary', 'close_date', 'move_in', 'listing_expiry', 'custom')),
  date_value DATE NOT NULL,
  label TEXT,
  send_reminder BOOLEAN DEFAULT true,
  reminder_days_before INT DEFAULT 7,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 13. ACTIVITY LOG (Automatic audit trail)
-- ============================================================
CREATE TABLE activity_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  entity_type TEXT NOT NULL CHECK (entity_type IN ('contact', 'lead', 'transaction', 'task', 'communication', 'property')),
  entity_id UUID NOT NULL,
  action TEXT NOT NULL CHECK (action IN ('created', 'updated', 'deleted', 'status_changed', 'stage_changed', 'note_added', 'email_sent', 'sms_sent', 'call_logged')),
  description TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- INDEXES for performance
-- ============================================================
CREATE INDEX idx_contacts_type ON contacts(contact_type);
CREATE INDEX idx_contacts_name ON contacts(last_name, first_name);
CREATE INDEX idx_contacts_email ON contacts(email);
CREATE INDEX idx_leads_contact ON leads(contact_id);
CREATE INDEX idx_leads_stage ON leads(stage_id);
CREATE INDEX idx_leads_temperature ON leads(temperature);
CREATE INDEX idx_leads_next_follow_up ON leads(next_follow_up);
CREATE INDEX idx_transactions_contact ON transactions(contact_id);
CREATE INDEX idx_transactions_status ON transactions(status);
CREATE INDEX idx_transactions_closing ON transactions(closing_date);
CREATE INDEX idx_communications_contact ON communications(contact_id);
CREATE INDEX idx_communications_channel ON communications(channel);
CREATE INDEX idx_communications_sent ON communications(sent_at);
CREATE INDEX idx_tasks_contact ON tasks(contact_id);
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_due ON tasks(due_date);
CREATE INDEX idx_tasks_priority ON tasks(priority);
CREATE INDEX idx_notes_contact ON notes(contact_id);
CREATE INDEX idx_notes_transaction ON notes(transaction_id);
CREATE INDEX idx_activity_entity ON activity_log(entity_type, entity_id);
CREATE INDEX idx_activity_created ON activity_log(created_at);
CREATE INDEX idx_important_dates_contact ON important_dates(contact_id);
CREATE INDEX idx_important_dates_date ON important_dates(date_value);

-- ============================================================
-- UPDATED_AT TRIGGER (auto-update timestamps)
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_contacts_updated_at BEFORE UPDATE ON contacts FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER set_leads_updated_at BEFORE UPDATE ON leads FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER set_transactions_updated_at BEFORE UPDATE ON transactions FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER set_tasks_updated_at BEFORE UPDATE ON tasks FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER set_notes_updated_at BEFORE UPDATE ON notes FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER set_properties_updated_at BEFORE UPDATE ON properties FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- ROW LEVEL SECURITY (basic setup for future auth)
-- ============================================================
ALTER TABLE contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE communications ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE properties ENABLE ROW LEVEL SECURITY;
ALTER TABLE transaction_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE transaction_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE important_dates ENABLE ROW LEVEL SECURITY;
ALTER TABLE tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE contact_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE pipeline_stages ENABLE ROW LEVEL SECURITY;

-- Permissive policies for authenticated users (solo agent)
CREATE POLICY "Allow all for authenticated" ON contacts FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON leads FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON transactions FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON communications FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON tasks FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON notes FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON properties FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON transaction_tasks FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON transaction_documents FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON activity_log FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON important_dates FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON tags FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON contact_tags FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for authenticated" ON pipeline_stages FOR ALL USING (true) WITH CHECK (true);
