-- 1.改字段名
-- ALTER TABLE `ers$stock_goodsbook`
-- CHANGE COLUMN `wsQty` `staticQty`  decimal(20,4) NOT NULL COMMENT '静态存量' AFTER `goodsId`,
-- CHANGE COLUMN `wdQty` `dynamicQty`  decimal(20,4) NOT NULL COMMENT '动态存量' AFTER `staticQty`;

-- 2.改字段名
-- ALTER TABLE `ers$stock_incomingbook`
-- CHANGE COLUMN `ivQty` `actualQty`  decimal(20,4) NOT NULL COMMENT '货品实际数量' AFTER `verlock`,
-- CHANGE COLUMN `pvQty` `packageQty`  bigint(20) NULL DEFAULT NULL COMMENT '包裹数量' AFTER `actualQty`,
-- CHANGE COLUMN `ivUnit` `actualUnit`  varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '货量单位' AFTER `packageQty`,
-- CHANGE COLUMN `pvUnit` `packageUnit`  varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '包裹单位' AFTER `actualUnit`;

-- 3.改字段名
-- ALTER TABLE `ers$stock_outgoingbook`
-- CHANGE COLUMN `ivQty` `actualQty`  decimal(20,4) NOT NULL COMMENT '货品实际数量' AFTER `verlock`,
-- CHANGE COLUMN `pvQty` `packageQty`  bigint(20) NULL DEFAULT NULL COMMENT '包裹数量' AFTER `actualQty`,
-- CHANGE COLUMN `ivUnit` `actualUnit`  varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '货量单位' AFTER `packageQty`,
-- CHANGE COLUMN `pvUnit` `packageUnit`  varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '包裹单位' AFTER `actualUnit`;

-- 4.改字段名
-- ALTER TABLE `ers$stock_outgoingpast`
-- CHANGE COLUMN `psQty` `staticQty`  decimal(20,4) NOT NULL COMMENT '静态存量' AFTER `inId`,
-- CHANGE COLUMN `pdQty` `dynamicQty`  decimal(20,4) NOT NULL COMMENT '动态存量' AFTER `staticQty`;

-- 5.改字段名
-- ALTER TABLE `ers$stock_packageattr`
-- CHANGE COLUMN `ivQty` `actualQty`  decimal(20,4) NOT NULL COMMENT '实际容纳数量' AFTER `goodsId`,
-- CHANGE COLUMN `pvUnit` `packageUnit`  varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL COMMENT '包裹单位' AFTER `childCount`;

-- 6.改字段名
-- ALTER TABLE `ers$stock_packagebook`
-- CHANGE COLUMN `psQty` `staticQty`  decimal(20,4) NOT NULL COMMENT '静态存量' AFTER `inId`,
-- CHANGE COLUMN `pdQty` `dynamicQty`  decimal(20,4) NOT NULL COMMENT '动态存量' AFTER `staticQty`;

-- 7.改字段名
-- ALTER TABLE `ers$stock_roombook`
-- CHANGE COLUMN `rsQty` `staticQty`  decimal(20,4) NOT NULL COMMENT '静态存量' AFTER `roomId`,
-- CHANGE COLUMN `rdQty` `dynamicQty`  decimal(20,4) NOT NULL COMMENT '动态存量' AFTER `staticQty`;

-- 8.改字段名
-- ALTER TABLE `ers$stock_shelfbook`
-- CHANGE COLUMN `ssQty` `staticQty`  decimal(20,4) NOT NULL COMMENT '静态存量' AFTER `shelfId`,
-- CHANGE COLUMN `sdQty` `dynamicQty`  decimal(20,4) NOT NULL COMMENT '动态存量' AFTER `staticQty`;

-- 9.改字段类型
-- ALTER TABLE `ers$stock_shelfattr`
-- MODIFY COLUMN `snCode`  varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL DEFAULT NULL COMMENT '货架编号' AFTER `title`;

-- 10.删除字段
-- ALTER TABLE `ers$stock_packageattr`
-- DROP COLUMN `snCode`;

-- 11.销售明细表
-- ALTER TABLE `erp$vendi_detail`
-- CHANGE COLUMN `itemId` `goodsId`  bigint(20) NOT NULL COMMENT '配件' AFTER `nameAs`;
-- DROP INDEX `itemId_idx` ,
-- ADD INDEX `goodsId_idx` (`goodsId`) USING BTREE ;

-- ALTER TABLE `erp$vendi_detail` ADD CONSTRAINT `fk_goodsId_erp$goods_id` FOREIGN KEY (`goodsId`) REFERENCES `erp$goods` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- ALTER TABLE `erp$vendi_detail` ADD CONSTRAINT `fk_goodsId_erc$supplier_id` FOREIGN KEY (`supplierId`) REFERENCES `autopart01_crm`.`erc$supplier` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;
