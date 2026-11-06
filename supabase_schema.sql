-- ====================================================================
-- FIELDOPS - DATABASE SCHEMA & SUPABASE MIGRATION
-- Warehouse Work Coordination Agent
-- ====================================================================

-- 1. Workers Table
CREATE TABLE IF NOT EXISTS public.workers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    worker_id VARCHAR(50) UNIQUE NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(50),
    warehouse_location VARCHAR(255) NOT NULL DEFAULT 'Packing Warehouse',
    department VARCHAR(100) NOT NULL DEFAULT 'Operations',
    role VARCHAR(100) NOT NULL DEFAULT 'Worker',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Incidents Table (Preserving existing schema + adding isolated worker identity fields)
CREATE TABLE IF NOT EXISTS public.incidents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    incident_type VARCHAR(100) NOT NULL, -- Damaged Pallet, Short Shipment, Temperature Breach, Machine Down
    location VARCHAR(255) NOT NULL,
    impact TEXT NOT NULL,
    urgency VARCHAR(50) DEFAULT 'Medium', -- Low, Medium, High, Critical
    priority VARCHAR(50) DEFAULT 'Medium', -- Low, Medium, High
    responsible_team VARCHAR(100), -- Warehouse Handling Team, Inventory / Dispatch Team, Cold Chain Team, Maintenance Team
    status VARCHAR(50) DEFAULT 'Submitted', -- Submitted, Processing, Awaiting Supervisor Approval, Approved, Supervisor Rejected, Assigned, In Progress, Resolved, Closed
    report_mode VARCHAR(20) DEFAULT 'text', -- text, voice
    approval_required BOOLEAN DEFAULT FALSE,
    approval_status VARCHAR(50) DEFAULT 'Not Required', -- Not Required, Pending, Approved, Rejected
    work_order_id VARCHAR(100),
    resolved_at TIMESTAMPTZ,

    -- Worker Identity (Isolated extensions)
    worker_id VARCHAR(50) REFERENCES public.workers(worker_id) ON UPDATE CASCADE ON DELETE SET NULL,
    worker_name VARCHAR(255)
);

-- Ensure index on worker_id & status for fast dashboard queries
CREATE INDEX IF NOT EXISTS idx_incidents_worker_id ON public.incidents(worker_id);
CREATE INDEX IF NOT EXISTS idx_incidents_status ON public.incidents(status);
CREATE INDEX IF NOT EXISTS idx_incidents_created_at ON public.incidents(created_at DESC);

-- 3. Incident Updates Table (For post-assignment operational progression)
CREATE TABLE IF NOT EXISTS public.incident_updates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    incident_id UUID REFERENCES public.incidents(id) ON DELETE CASCADE,
    worker_id VARCHAR(50),
    message TEXT NOT NULL,
    status VARCHAR(50) NOT NULL, -- Team Assigned, Team Acknowledged, Team On The Way, Work Started, Work Completed, Incident Resolved
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_incident_updates_incident_id ON public.incident_updates(incident_id);

-- 4. Notifications Table
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    worker_id VARCHAR(50) NOT NULL,
    incident_id UUID REFERENCES public.incidents(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_worker_id ON public.notifications(worker_id);

-- 5. Seed Initial Default Workers
INSERT INTO public.workers (worker_id, full_name, email, phone, warehouse_location, department, role)
VALUES 
    ('WKR-001', 'Arun Kumar', 'arun.kumar@fieldops.internal', '+91 98765 43210', 'Packing Warehouse (Sector 4)', 'Operations & Packing', 'Worker'),
    ('WKR-002', 'Sarah Jenkins', 'sarah.j@fieldops.internal', '+1 555-019-2834', 'Cold Chain Distribution Hub', 'Cold Chain Storage', 'Senior Worker'),
    ('WKR-003', 'Rajesh Patel', 'rajesh.p@fieldops.internal', '+91 91234 56789', 'Inbound Dock 7', 'Logistics & Receiving', 'Forklift Lead')
ON CONFLICT (worker_id) DO NOTHING;

-- 6. Enable Realtime Replication
ALTER PUBLICATION supabase_realtime ADD TABLE public.incidents;
ALTER PUBLICATION supabase_realtime ADD TABLE public.incident_updates;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
