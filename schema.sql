-- Represent customers that need to store goods in the warehouse
CREATE TABLE "customers" (
    "id" INTEGER,
    "name" TEXT NOT NULL UNIQUE,
    "contact_first_name" TEXT,
    "contact_last_name" TEXT,
    "contact_phone_number" TEXT NOT NULL CHECK(LENGTH("contact_phone_number") >= 10),
    "address" TEXT NOT NULL,
    "create_date" NUMERIC NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "active_flag" INTEGER NOT NULL CHECK("active_flag" IN (0, 1)),
    PRIMARY KEY("id")
);

-- Represent employees working in the warehouse
CREATE TABLE "employees" (
    "id" INTEGER,
    "first_name" TEXT NOT NULL,
    "last_name" TEXT NOT NULL,
    "job_title" TEXT NOT NULL,
    "create_date" NUMERIC NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "active_flag" INTEGER NOT NULL CHECK("active_flag" IN (0, 1)),
    PRIMARY KEY("id")
);

-- Represent goods being received from a customer to the warehouse
CREATE TABLE "goods_receipts" (
    "id" INTEGER,
    "customer_id" INTEGER NOT NULL,
    "inspector_id" INTEGER NOT NULL,
    "pallet_count" INTEGER NOT NULL,
    "receive_date" NUMERIC NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "comment" TEXT,
    PRIMARY KEY("id"),
    FOREIGN KEY("customer_id") REFERENCES "customers"("id"),
    FOREIGN KEY("inspector_id") REFERENCES "employees"("id")
);

-- Represent goods being shipped from the warehouse to a customer
CREATE TABLE "packing_lists" (
    "id" INTEGER,
    "customer_id" INTEGER NOT NULL,
    "pallet_count" INTEGER NOT NULL,
    "ship_date" NUMERIC NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "comment" TEXT,
    PRIMARY KEY("id"),
    FOREIGN KEY("customer_id") REFERENCES "customers"("id")
);

-- Represent goods that can be stored in the warehouse by customers
CREATE TABLE "goods" (
    "id" INTEGER,
    "customer_id" INTEGER NOT NULL,
    "name" TEXT NOT NULL UNIQUE,
    "description" TEXT,
    "total_quantity" NUMERIC NOT NULL CHECK("total_quantity" >= 0),
    "stock_um" TEXT NOT NULL DEFAULT 'PCS' CHECK("stock_um" IN ('PCS', 'KG', 'MTR', 'LTR', 'BOX')),
    "weight" NUMERIC NOT NULL CHECK("weight" > 0),
    "create_date" NUMERIC NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "modify_date" NUMERIC NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "active_flag" INTEGER NOT NULL CHECK("active_flag" IN (0, 1)),
    PRIMARY KEY("id"),
    FOREIGN KEY("customer_id") REFERENCES "customers"("id")
);

-- Represent locations in the warehouse where goods can be stored
CREATE TABLE "locations" (
    "id" INTEGER,
    "name" TEXT NOT NULL UNIQUE,
    "description" TEXT,
    "create_date" NUMERIC NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "active_flag" INTEGER NOT NULL CHECK("active_flag" IN (0, 1)),
    PRIMARY KEY("id")
);

-- Represent quantities of goods at each location in the warehouse
CREATE TABLE "goods_locations" (
    "location_id" INTEGER NOT NULL,
    "goods_id" INTEGER NOT NULL,
    "quantity" NUMERIC NOT NULL CHECK("quantity" >= 0),
    PRIMARY KEY("location_id", "goods_id"),
    FOREIGN KEY("location_id") REFERENCES "locations"("id"),
    FOREIGN KEY("goods_id") REFERENCES "goods"("id")
);

-- Represent inventory transactions that occur in the warehouse
CREATE TABLE "inventory_transactions" (
    "id" INTEGER,
    "type" TEXT NOT NULL CHECK("type" IN ('IN', 'OUT', 'MOVE')),
    "goods_receipt_id" INTEGER CHECK("type" IN ('OUT', 'MOVE') OR "goods_receipt_id" IS NOT NULL),
    "packing_list_id" INTEGER CHECK("type" IN  ('IN', 'MOVE') OR "packing_list_id" IS NOT NULL),
    "goods_id" INTEGER NOT NULL,
    "employee_id" INTEGER NOT NULL,
    "from_location_id" INTEGER CHECK("type" = 'IN' OR "from_location_id" IS NOT NULL),
    "to_location_id" INTEGER CHECK("type" = 'OUT' OR "to_location_id" IS NOT NULL),
    "quantity" NUMERIC NOT NULL CHECK("quantity" > 0),
    "comment" TEXT,
    "transaction_datetime" NUMERIC NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY("id"),
    FOREIGN KEY("goods_receipt_id") REFERENCES "goods_receipts"("id"),
    FOREIGN KEY("packing_list_id") REFERENCES "packing_lists"("id"),
    FOREIGN KEY("goods_id") REFERENCES "goods"("id"),
    FOREIGN KEY("employee_id") REFERENCES "employees"("id"),
    FOREIGN KEY("from_location_id") REFERENCES "locations"("id"),
    FOREIGN KEY("to_location_id") REFERENCES "locations"("id")
);

-- Indexes:
CREATE INDEX "employees_name_search" ON "employees" ("first_name", "last_name");
CREATE INDEX "customers_name_search" ON "customers" ("name");
CREATE INDEX "goods_name_search" ON "goods" ("name");
CREATE INDEX "location_name_search" ON "locations" ("name");

-- Soft deletion implementation:
---- Current customers view
CREATE VIEW "current_customers" AS
SELECT
    "id",
    "name",
    "contact_first_name",
    "contact_last_name",
    "contact_phone_number",
    "address",
    "create_date"
FROM
    "customers"
WHERE
    "active_flag" = 1;

---- Flag customer as inactive instead of deletion of customer record
CREATE TRIGGER "delete_customer"
INSTEAD OF DELETE ON "current_customers"
FOR EACH ROW
BEGIN
    UPDATE "customers" SET "active_flag" = 0
    WHERE "id" = OLD."id";
END;

---- Current employees view
CREATE VIEW "current_employees" AS
SELECT
    "id",
    "first_name",
    "last_name",
    "job_title",
    "create_date"
FROM
    "employees"
WHERE
    "active_flag" = 1;

---- Flag employee as inactive instead of deletion of employee record
CREATE TRIGGER "delete_employee"
INSTEAD OF DELETE ON "current_employees"
FOR EACH ROW
BEGIN
    UPDATE "employees" SET "active_flag" = 0
    WHERE "id" = OLD."id";
END;

---- Current warehouse locations view:
CREATE VIEW "current_locations" AS
SELECT
    "id",
    "name",
    "description",
    "create_date"
FROM
    "locations"
WHERE
    "active_flag" = 1;

---- Flag location as inactive instead of deletion of location record
CREATE TRIGGER "delete_location"
INSTEAD OF DELETE ON "current_locations"
FOR EACH ROW
BEGIN
    UPDATE "locations" SET "active_flag" = 0
    WHERE "id" = OLD."id";
END;

---- Current stock items (goods) view:
CREATE VIEW "current_goods" AS
SELECT
    "goods"."customer_id",
    "customers"."name",
    "goods"."id",
    "goods"."name",
    "goods"."description",
    "goods"."total_quantity",
    "goods"."stock_um",
    "goods"."weight",
    "goods"."create_date",
    "goods"."modify_date"
FROM
    "goods" INNER JOIN "customers"
    ON "goods"."customers_id" = "customers"."id"
WHERE
    "goods"."active_flag" = 1;

---- Flag goods as inactive instead of deletion of goods record
CREATE TRIGGER "delete_stock_item"
INSTEAD OF DELETE ON "current_goods"
FOR EACH ROW
BEGIN
    UPDATE "goods" SET "active_flag" = 0
    WHERE "id" = OLD."id";
END;
