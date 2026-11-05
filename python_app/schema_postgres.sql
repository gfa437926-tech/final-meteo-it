CREATE TABLE IF NOT EXISTS assets(id text PRIMARY KEY,category text,brand text,model text,serial_number text,status text,office text,employee text,cpu text,ram text,storage text,received_at text,notes text,created_at timestamptz,updated_at timestamptz);
CREATE UNIQUE INDEX IF NOT EXISTS ux_assets_serial_number ON assets(upper(trim(serial_number))) WHERE serial_number IS NOT NULL AND trim(serial_number)<>'';
CREATE TABLE IF NOT EXISTS offices(id text PRIMARY KEY,name text,directorate text,department text,location text,notes text,created_at timestamptz,updated_at timestamptz);
CREATE TABLE IF NOT EXISTS custody(id text PRIMARY KEY,asset_id text,asset_serial text,employee text,office text,issued_at text,returned_at text,status text,notes text,created_at text);
CREATE TABLE IF NOT EXISTS maintenance(id text PRIMARY KEY,asset_id text,asset_serial text,problem text,action_taken text,technician text,opened_at text,closed_at text,cost text,status text,notes text);
CREATE TABLE IF NOT EXISTS purchases(id text PRIMARY KEY,purchase_number text,supplier text,invoice_number text,purchase_date text,total_cost text,warranty_until text,notes text);
CREATE TABLE IF NOT EXISTS spare_parts(id text PRIMARY KEY,name text,part_number text,quantity text,unit_cost text,location text,notes text,updated_at timestamptz);
CREATE TABLE IF NOT EXISTS audit_logs(log_id bigserial PRIMARY KEY,timestamp timestamptz NOT NULL DEFAULT now(),username text,action text,sheet text,record_id text,details text);
DO $
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_custody_asset') THEN
    ALTER TABLE custody ADD CONSTRAINT fk_custody_asset
      FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE RESTRICT NOT VALID;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_maintenance_asset') THEN
    ALTER TABLE maintenance ADD CONSTRAINT fk_maintenance_asset
      FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE RESTRICT NOT VALID;
  END IF;
END $;
CREATE INDEX IF NOT EXISTS ix_custody_asset_id ON custody(asset_id);
CREATE INDEX IF NOT EXISTS ix_maintenance_asset_id ON maintenance(asset_id);
CREATE INDEX IF NOT EXISTS ix_audit_logs_timestamp ON audit_logs(timestamp DESC);