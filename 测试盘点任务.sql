set foreign_key_checks = 0;

TRUNCATE TABLE ers_inventory_bilwfw;
TRUNCATE TABLE ers_inventory;
TRUNCATE TABLE ers_inventory_task;

-- 新增盘点任务主表
INSERT INTO ers_inventory_task(lastModifiedId) SELECT 19;

-- 新增盘点单(商品1，仓位2)
INSERT INTO ers_inventory(ers_inventory_task_id, goodsId, ers_shelfattr_id, lastModifiedId) SELECT 1, 1, 2, 19;
-- 新增盘点单(商品1，仓位3)
INSERT INTO ers_inventory(ers_inventory_task_id, goodsId, ers_shelfattr_id, lastModifiedId) SELECT 1, 1, 3, 19; 
-- 新增盘点单(商品2，仓位2)
INSERT INTO ers_inventory(ers_inventory_task_id, goodsId, ers_shelfattr_id, lastModifiedId) SELECT 1, 2, 2, 19;
-- 新增盘点单(商品2，仓位3)
INSERT INTO ers_inventory(ers_inventory_task_id, goodsId, ers_shelfattr_id, lastModifiedId) SELECT 1, 2, 3, 19;
-- 新增盘点单(商品3，仓位2)
INSERT INTO ers_inventory(ers_inventory_task_id, goodsId, ers_shelfattr_id, lastModifiedId) SELECT 1, 3, 2, 19;
-- 新增盘点单(商品4，仓位3)
INSERT INTO ers_inventory(ers_inventory_task_id, goodsId, ers_shelfattr_id, lastModifiedId) SELECT 1, 4, 3, 19;

-- -- 删除盘点任务主表
-- DELETE FROM ers_inventory_task WHERE id = 1;
-- -- 删除盘点单1
-- DELETE FROM ers_inventory WHERE id = 1;
-- -- 审核通过盘点单
-- UPDATE ers_inventory i SET i.isCheck = 1, i.checkUserId = 12, i.lastModifiedId = 12 WHERE id = 1;
-- -- 提交盘点任务表
-- UPDATE ers_inventory_task it SET it.isCheck = 0, it.lastModifiedId = 19 WHERE it.id = 1;
-- -- 审核通过盘点任务表
-- UPDATE ers_inventory_task it SET it.isCheck = 1, it.checkUserId = 12, lastModifiedId = 12 WHERE it.id = 1;
-- -- 审核盘点单审核通过
-- UPDATE ers_inventory i SET i.isCheck = 1, i.checkUserId = 12, i.lastModifiedId = 12 WHERE id = 1;
-- -- 填写盘点单盘点数量
-- UPDATE ers_inventory i SET i.inventoryQty = 1, i.inventoryRecordUserId = 19, i.lastModifiedId = 19, i.inventoryEmpName = '盘点人员' WHERE i.id = 1;
-- -- 提交盘点任务表
-- UPDATE ers_inventory_task it SET it.isCheck = 0, it.lastModifiedId = 19 WHERE it.id = 1;
-- -- 审核通过盘点单
-- UPDATE ers_inventory i SET i.isCheck = 1, i.checkUserId = 12, i.lastModifiedId = 12 WHERE id = 1;
-- -- 退回盘点任务表
-- UPDATE ers_inventory_task it SET it.isCheck = -1, it.lastModifiedId = 12, it.checkReason = '部分盘点数量没有记录' WHERE it.id = 1;
-- 填写盘点单盘点数量
-- UPDATE ers_inventory i SET i.inventoryQty = 2, i.inventoryRecordUserId = 19, i.lastModifiedId = 19, i.inventoryEmpName = '盘点人员' WHERE i.id = 2;
-- -- 填写盘点单盘点数量
-- UPDATE ers_inventory i SET i.inventoryQty = 2, i.inventoryRecordUserId = 19, i.lastModifiedId = 19, i.inventoryEmpName = '盘点人员' WHERE i.id = 3;
-- -- 填写盘点单盘点数量
-- UPDATE ers_inventory i SET i.inventoryQty = 4, i.inventoryRecordUserId = 19, i.lastModifiedId = 19, i.inventoryEmpName = '盘点人员' WHERE i.id = 4;
-- -- 填写盘点单盘点数量
-- UPDATE ers_inventory i SET i.inventoryQty = 5, i.inventoryRecordUserId = 19, i.lastModifiedId = 19, i.inventoryEmpName = '盘点人员' WHERE i.id = 5;
-- -- 填写盘点单盘点数量
-- UPDATE ers_inventory i SET i.inventoryQty = 6, i.inventoryRecordUserId = 19, i.lastModifiedId = 19, i.inventoryEmpName = '盘点人员' WHERE i.id = 6;
-- -- 提交盘点任务表
-- UPDATE ers_inventory_task it SET it.isCheck = 0, it.lastModifiedId = 19 WHERE it.id = 1;
-- -- 审核通过盘点单
-- UPDATE ers_inventory i SET i.isCheck = 1, i.checkUserId = 12, i.lastModifiedId = 12 WHERE id = 2;
-- -- 审核通过盘点单
-- UPDATE ers_inventory i SET i.isCheck = 1, i.checkUserId = 12, i.lastModifiedId = 12 WHERE id = 3;
-- -- 审核通过盘点单
-- UPDATE ers_inventory i SET i.isCheck = 1, i.checkUserId = 12, i.lastModifiedId = 12 WHERE id = 4;
-- -- 审核通过盘点单
-- UPDATE ers_inventory i SET i.isCheck = 1, i.checkUserId = 12, i.lastModifiedId = 12 WHERE id = 5;
-- -- 删除盘点单
-- DELETE FROM ers_inventory WHERE id = 6;
-- -- 审核通过盘点单
-- UPDATE ers_inventory i SET i.isCheck = 1, i.checkUserId = 12, i.lastModifiedId = 12 WHERE id = 6;
-- -- 审核通过盘点任务表
-- UPDATE ers_inventory_task it SET it.isCheck = 1, it.checkUserId = 12, lastModifiedId = 12 WHERE it.id = 1;