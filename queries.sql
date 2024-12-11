-- Add some new customers to the database
INSERT INTO "customers" ("name", "contact_first_name", "contact_last_name", "contact_phone_number", "address", "active_flag")
VALUES
('Micro Design Ltd.', 'Ella', 'Clark', '078 1786 4606', '61 Whatlington Road, COUSLAND, EH22 2JQ', 1),
('Crown Auto Parts Ltd.', 'Imogen', 'Lawson', '079 1708 7985', '51 Souterhead Road, LOWER ASSENDON, RG9 3RT', 1),
('Buttrey Food & Drug', NULL, NULL, '077 2296 1599', '2 Sandyhill Rd, FULKING, BN5 5RT', 1);

-- Add some employees to the database
INSERT INTO "employees" ("first_name", "last_name", "job_title", "active_flag")
VALUES
('Zak', 'Francis', 'Operator', 1),
('Lucas', 'Archer', 'Manager', 1),
('Sam', 'Manning', 'Inspector', 1),
('Lewis', 'Burrows', 'Operator', 1);

-- Add initial warehouse locations to the database
INSERT INTO "locations" ("name", "description", "active_flag")
VALUES
('A1', NULL, 1),
('A2', 'should be used for metals', 1),
('B1', 'store items in boxes', 1),
('C1', 'large items', 1),
('C2', 'hazardous chemicals', 1);

-- Add some initial goods to the database
INSERT INTO "goods" ("customer_id", "name", "description", "total_quantity", "stock_um", "weight", "active_flag")
VALUES
(1, 'APX-128', 'sheet metal', 117, 'MTR', 15.70, 1),
(2, '3RT-481', 'engine', 15, 'PCS', 114.65, 1),
(3, 'QFG-784', NULL, 351, 'BOX', 4.50, 1);

-- Update a stock item in the goods table
UPDATE "goods"
SET
    "name" = 'APL-128',
    "modify_date" = CURRENT_TIMESTAMP
WHERE "name" = 'APX-128';

-- Associate existing stock with warehouse locations
INSERT INTO "goods_locations" ("location_id", "goods_id", "quantity")
VALUES
(2, 1, 117),
(1, 2, 6),
(4, 2, 9),
(3, 3, 351);

-- Verify the quanity in the goods table matches the total quantity in the goods_locations table
SELECT
    "goods"."name",
    "goods"."total_quantity",
    SUM("goods_locations"."quantity") AS "calculated_total"
FROM
    "goods" LEFT JOIN "goods_locations"
    ON "goods"."id" = "goods_locations"."goods_id"
GROUP BY
    "goods"."name",
    "goods"."total_quantity";

-- Utilise soft deletion by flagging a customer as 'inactive'
DELETE FROM "current_customers"
WHERE "name" = 'Micro Design Ltd.';

-- Verify the customer has been flagged as 'inactive'
SELECT * FROM "customers"
WHERE "name" = 'Micro Design Ltd.';

-- Utilise UPSERT clause in SQLite3 (https://www.sqlite.org/lang_upsert.html) to insert a new customer or update an existing customer, if they already exist and flag them as 'active' again.
-- Similar statements could also be used for other tables in the database with the 'active_flag' column.
INSERT INTO "customers" ("name", "contact_first_name", "contact_last_name", "contact_phone_number", "address", "active_flag")
VALUES ('Micro Design Ltd.', 'Joan', 'Ashton', '077 6604 2826', '61 Whatlington Road, COUSLAND, EH22 2JQ', 1)
    ON CONFLICT("name") DO UPDATE SET
        "contact_first_name" = EXCLUDED."contact_first_name",
        "contact_last_name" = EXCLUDED."contact_last_name",
        "contact_phone_number" = EXCLUDED."contact_phone_number",
        "address" = EXCLUDED."address",
        "active_flag" = EXCLUDED."active_flag";
-- The statement above updates the record for 'Micro Design Ltd.' because a customer was already present in the 'customers' table.
-- If there was a DEFAULT clause in the schema.sql, 'active_flag' could be omitted from the INSERT statement, and the UPDATE statment could set the 'active_flag' to 1 instead.

------------------------------------------------------
-- IN - Transaction for receiving goods into the warehouse

-- Add a record into the 'goods_receipts' table
INSERT INTO "goods_receipts" ("customer_id", "inspector_id", "pallet_count", "comment")
VALUES (1, 3, 5, 'shipment of sheet metal - good condition')

-- Before running a 'receive into stock' transaction, the item must exist in the 'goods' table and the location must exist in the locations 'table'.
-- If the item does not exist in goods table, it must be added otherwise the transaction fails because of the foreign key constraint. The same applies to the location referenced.
BEGIN TRANSACTION;
INSERT INTO "inventory_transactions" ("type", "goods_receipt_id", "goods_id", "employee_id", "to_location_id", "quantity")
VALUES ('IN', 1, 1, 4, 2, 25);

-- Increase the quantity of the goods at the warehouse location and the goods tables
-- Create the combination of goods and location, otherwise the UPDATE fails. IGNORE clause ensures the record is only inserted when it is not present
INSERT OR IGNORE INTO "goods_locations" ("location_id", "goods_id", "quantity") VALUES (2, 1, 0);
UPDATE "goods_locations" SET "quantity" = "quantity" + 25 WHERE "location_id" = 2 AND "goods_id" = 1;
UPDATE "goods" SET "total_quantity" = "total_quantity" + 25 WHERE "id" = 1;

-- Determine within the application if an error occurred. If no error occurred, execute:
COMMIT;
-- If an error did occur during the execution of the transaction, execute ROLLBACK instead.
------------------------------------------------------

-- Where is currently stored all 'APL-128' (sheet metal)?
SELECT
    "goods"."name",
    "goods"."description",
    "locations"."name",
    "goods_locations"."quantity"
FROM
    "locations" INNER JOIN "goods_locations"
    ON "locations"."id" = "goods_locations"."location_id" INNER JOIN "goods"
    ON "goods"."id" = "goods_locations"."goods_id"
WHERE
    "goods"."name" = 'APL-128';

------------------------------------------------------
-- MOVE - Transaction for moving goods from one warehouse location to another

-- Similarly to the previous transaction, all inventory locations referenced in the transaction must be created before the execution of the transaction
BEGIN TRANSACTION;
INSERT INTO "inventory_transactions" ("type", "goods_id", "employee_id", "from_location_id", "to_location_id", "quantity")
VALUES ('MOVE', 1, 2, 2, 1, 47);

-- Decrease the quantity at the 'from location'
UPDATE "goods_locations" SET "quantity" = "quantity" - 47 WHERE "location_id" = 2 AND "goods_id" = 1;

-- Increase the quanity at the 'to location'
INSERT OR IGNORE INTO "goods_locations" ("location_id", "goods_id", "quantity") VALUES (1, 1, 0);
UPDATE "goods_locations" SET "quantity" = "quantity" + 47 WHERE "location_id" = 1 AND "goods_id" = 1;

-- Determine within the application if an error occurred. If no error occurred, execute:
COMMIT;
-- If an error did occur during the execution of the transaction, execute ROLLBACK instead.
------------------------------------------------------

-- Where is currently stored all 'APL-128' (sheet metal)?
SELECT
    "goods"."name",
    "goods"."description",
    "locations"."name",
    "goods_locations"."quantity"
FROM
    "locations" INNER JOIN "goods_locations"
    ON "locations"."id" = "goods_locations"."location_id" INNER JOIN "goods"
    ON "goods"."id" = "goods_locations"."goods_id"
WHERE
    "goods"."name" = 'APL-128';
-- A1 should contain 47 and A2 should contain 95 of 'APL-128'.

------------------------------------------------------
-- OUT - Transaction for shipping goods out of the warehouse

-- Add a record into the 'packing_lists' table
INSERT INTO "packing_lists" ("customer_id", "pallet_count")
VALUES (1, 3)

-- Before running a this transaction, the item must exist in the 'goods' table and the location must exist in the locations 'table'.
-- If the item does not exist in goods table, it must be added otherwise the transaction fails because of the foreign key constraint. The same applies to the location referenced.
BEGIN TRANSACTION;
INSERT INTO "inventory_transactions" ("type", "packing_list_id", "goods_id", "employee_id", "from_location_id", "quantity")
VALUES ('OUT', 1, 1, 1, 2, 58);

-- Decrease the quantity of the goods at the warehouse location and the goods tables
UPDATE "goods_locations" SET "quantity" = "quantity" - 58 WHERE "location_id" = 2 AND "goods_id" = 1;
UPDATE "goods" SET "total_quantity" = "total_quantity" - 58 WHERE "id" = 1;

-- Determine within the application if an error occurred. If no error occurred, execute:
COMMIT;
-- If an error did occur during the execution of the transaction, execute ROLLBACK instead.
------------------------------------------------------

-- Find the number of transactions that were performed by 'Lewis Burrows'
SELECT
    "first_name",
    "last_name",
    COUNT("inventory_transactions"."id") as "transactions_count"
FROM
    "employees" INNER JOIN "inventory_transactions"
    ON "employees"."id" = "inventory_transactions"."employee_id"
WHERE
    "first_name" = 'Lewis'
    AND "last_name" = 'Burrows'
GROUP BY
    "first_name",
    "last_name";

-- Find the goods and their quantities at the warehouse location 'A1' and 'A2'
SELECT
    "locations"."name",
    "goods"."name",
    "goods"."description",
    "goods_locations"."quantity"
FROM
    "locations" INNER JOIN "goods_locations"
    ON "locations"."id" = "goods_locations"."location_id" INNER JOIN "goods"
    ON "goods"."id" = "goods_locations"."goods_id"
WHERE
    "locations"."name" IN ('A1', 'A2');

-- Find the contact details for the company 'Micro Design Ltd.'
SELECT
    "name",
    "contact_first_name",
    "contact_last_name",
    "contact_phone_number"
FROM
    "customers"
WHERE
    "name" = 'Micro Design Ltd.';

-- Find all goods and their quantities that belong to 'Micro Design Ltd.'
SELECT
    "customers"."name",
    "goods"."name",
    "total_quantity"
FROM
    "customers" INNER JOIN "goods"
    ON "customers"."id" = "goods"."customer_id"
WHERE
    "customers"."name" = 'Micro Design Ltd.';
